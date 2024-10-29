// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoan, IFixedTermLoanManager, ILoanLike } from "../../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract CloseLoanTests is TestBaseWithAssertions {

    address borrower;
    address loan;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0.01e6), uint256(0), uint256(0)],
            loanManager: poolManager.strategyList(0)
        });
    }

    function test_closeLoan_failWithInsufficientApproval() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan).getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to borrower
        fundsAsset.mint(borrower, fullPayment);

        // Approve only 1 wei less than the full payment
        vm.prank(borrower);
        fundsAsset.approve(loan, fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:TRANSFER_FROM_FAILED");
        IFixedTermLoan(loan).closeLoan(fullPayment);
    }

    function test_closeLoan_failIfLoanIsLate() external {
        vm.warp(start + IFixedTermLoan(loan).nextPaymentDueDate() + 1);

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan).getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to loan
        fundsAsset.mint(loan, fullPayment);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:PAYMENT_IS_LATE");
        IFixedTermLoan(loan).closeLoan(0);
    }

    function test_closeLoan_failIfNotEnoughFundsSent() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan).getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        fundsAsset.mint(loan, fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert(arithmeticError);
        IFixedTermLoan(loan).closeLoan(0);
    }

    function test_closeLoan_failIfNotLoan() external {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(poolManager.strategyList(0));

        vm.expectRevert("LM:DCF:NOT_LOAN");
        loanManager.claim(0, 10, start, start + 1_000_000);
    }

    function test_closeLoan_success() external {
        vm.warp(start + 1_000_000 seconds / 4);

        ( uint256 principal, uint256 interest, uint256 fees ) = IFixedTermLoan(loan).getClosingPaymentBreakdown();

        assertEq(principal, 1_000_000e6);
        assertEq(interest,  10_000e6);                // 1% of principal.
        assertEq(fees,      3 * (300e6 + 10_000e6));  // Three payments of delegate and platform service fees.

        // Get rid of existing asset balances.
        fundsAsset.burn(address(borrower),     fundsAsset.balanceOf(address(borrower)));
        fundsAsset.burn(address(pool),         fundsAsset.balanceOf(address(pool)));
        fundsAsset.burn(address(poolDelegate), fundsAsset.balanceOf(address(poolDelegate)));
        fundsAsset.burn(address(treasury),     fundsAsset.balanceOf(address(treasury)));

        assertEq(fundsAsset.balanceOf(address(pool)),         0);
        assertEq(fundsAsset.balanceOf(address(borrower)),     0);
        assertEq(fundsAsset.balanceOf(loan),                  0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 0);
        assertEq(fundsAsset.balanceOf(address(treasury)),     0);

        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), start + 1_000_000 seconds);
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  3);
        assertEq(IFixedTermLoan(loan).principal(),          1_000_000e6);

        IFixedTermLoanManager loanManager = IFixedTermLoanManager(ILoanLike(loan).lender());

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6 / 4,  // A quarter of incoming interest.
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      90_000e6 * 1e30 / 1_000_000 seconds,
            domainStart:       start,
            domainEnd:         start + 1_000_000 seconds,
            unrealizedLosses:  0
        });

        (
            ,
            ,
            uint256 startDate,
            uint256 paymentDueDate,
            uint256 incomingNetInterest,
            uint256 refinanceInterest,
            uint256 issuanceRate
        ) = loanManager.payments(loanManager.paymentIdOf(loan));

        assertEq(incomingNetInterest, 100_000e6 - 10_000e6);  // Interest minus the management fees.
        assertEq(refinanceInterest,   0);
        assertEq(startDate,           start);
        assertEq(paymentDueDate,      start + 1_000_000 seconds);
        assertEq(issuanceRate,        90_000e6 * 1e30 / 1_000_000 seconds);

        // Close the loan.
        close(loan);

        assertEq(fundsAsset.balanceOf(address(pool)),         1_000_000e6 + 9_000e6);  // Principal plus closing fees.
        assertEq(fundsAsset.balanceOf(address(borrower)),     0);
        assertEq(fundsAsset.balanceOf(loan),                  0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 3 * 300e6    + 200e6);  // Three service fees plus a portion of the interest.
        assertEq(fundsAsset.balanceOf(address(treasury)),     3 * 10_000e6 + 800e6);  // Three service fees plus a portion of the interest.

        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), 0);
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  0);
        assertEq(IFixedTermLoan(loan).principal(),          0);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        (
            ,
            ,
            startDate,
            paymentDueDate,
            incomingNetInterest,
            refinanceInterest,
            issuanceRate
        ) = loanManager.payments(loanManager.paymentIdOf(loan));

        assertEq(incomingNetInterest, 0);
        assertEq(refinanceInterest,   0);
        assertEq(startDate,           0);
        assertEq(paymentDueDate,      0);
        assertEq(issuanceRate,        0);
    }

}
