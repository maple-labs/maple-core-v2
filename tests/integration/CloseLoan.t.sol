// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan-v401/contracts/MapleLoan.sol";

contract CloseLoanTests is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), uint256(0.01e18), uint256(0), uint256(0)]
        });
    }

    function test_closeLoan_failWithInsufficientApproval() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to borrower
        fundsAsset.mint(borrower, fullPayment);

        // Approve only 1 wei less than the full payment
        vm.prank(borrower);
        fundsAsset.approve(address(loan), fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:TRANSFER_FROM_FAILED");
        loan.closeLoan(fullPayment);
    }

    function test_closeLoan_failIfLoanIsLate() external {
        vm.warp(start + loan.nextPaymentDueDate() + 1);

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to loan
        fundsAsset.mint(address(loan), fullPayment);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:PAYMENT_IS_LATE");
        loan.closeLoan(0);
    }

    function test_closeLoan_failIfNotEnoughFundsSent() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        fundsAsset.mint(address(loan), fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.closeLoan(0);
    }

    function test_closeLoan_failIfNotLoan() external {
        vm.expectRevert("LM:C:NOT_LOAN");
        loanManager.claim(0, 10, start, start + 1_000_000);
    }

    function test_closeLoan_success() external {
        vm.warp(start + 1_000_000 seconds / 4);

        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        assertEq(principal, 1_000_000e6);
        assertEq(interest,  10_000e6);                // 1% of principal.
        assertEq(fees,      3 * (300e6 + 10_000e6));  // Three payments of delegate and platform service fees.

        uint256 payment = principal + interest + fees;

        // Get rid of existing asset balances.
        fundsAsset.burn(address(borrower),     fundsAsset.balanceOf(address(borrower)));
        fundsAsset.burn(address(pool),         fundsAsset.balanceOf(address(pool)));
        fundsAsset.burn(address(poolDelegate), fundsAsset.balanceOf(address(poolDelegate)));
        fundsAsset.burn(address(treasury),     fundsAsset.balanceOf(address(treasury)));

        fundsAsset.mint(borrower, payment);

        vm.prank(borrower);
        fundsAsset.approve(address(loan), payment);

        assertEq(fundsAsset.balanceOf(address(pool)),         0);
        assertEq(fundsAsset.balanceOf(address(borrower)),     payment);
        assertEq(fundsAsset.balanceOf(address(loan)),         0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 0);
        assertEq(fundsAsset.balanceOf(address(treasury)),     0);

        assertEq(loan.nextPaymentDueDate(), start + 1_000_000 seconds);
        assertEq(loan.paymentsRemaining(),  3);
        assertEq(loan.principal(),          1_000_000e6);

        assertEq(loanManager.getAccruedInterest(),    90_000e6 / 4);  // A quarter of incoming interest.
        assertEq(loanManager.accountedInterest(),     0);
        assertEq(loanManager.principalOut(),          1_000_000e6);
        assertEq(loanManager.assetsUnderManagement(), 1_000_000e6 + 90_000e6 / 4);
        assertEq(loanManager.issuanceRate(),          90_000e6 * 1e30 / 1_000_000 seconds);
        assertEq(loanManager.domainStart(),           start);
        assertEq(loanManager.domainEnd(),             start + 1_000_000 seconds);

        (
            ,
            ,
            uint256 startDate,
            uint256 paymentDueDate,
            uint256 incomingNetInterest,
            uint256 refinanceInterest,
            uint256 issuanceRate
        ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));

        assertEq(incomingNetInterest, 100_000e6 - 10_000e6);  // Interest minus the management fees.
        assertEq(refinanceInterest,   0);
        assertEq(startDate,           start);
        assertEq(paymentDueDate,      start + 1_000_000 seconds);
        assertEq(issuanceRate,        90_000e6 * 1e30 / 1_000_000 seconds);

        // Close the loan.
        vm.prank(borrower);
        loan.closeLoan(payment);

        assertEq(fundsAsset.balanceOf(address(pool)),         1_000_000e6 + 9_000e6);  // Principal plus closing fees.
        assertEq(fundsAsset.balanceOf(address(borrower)),     0);
        assertEq(fundsAsset.balanceOf(address(loan)),         0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 3 * 300e6    + 200e6);  // Three service fees plus a portion of the interest.
        assertEq(fundsAsset.balanceOf(address(treasury)),     3 * 10_000e6 + 800e6);  // Three service fees plus a portion of the interest.

        assertEq(loan.nextPaymentDueDate(), 0);
        assertEq(loan.paymentsRemaining(),  0);
        assertEq(loan.principal(),          0);

        assertEq(loanManager.getAccruedInterest(),    0);
        assertEq(loanManager.accountedInterest(),     0);
        assertEq(loanManager.principalOut(),          0);
        assertEq(loanManager.assetsUnderManagement(), 0);
        assertEq(loanManager.issuanceRate(),          0);
        assertEq(loanManager.domainStart(),           block.timestamp);
        assertEq(loanManager.domainEnd(),             block.timestamp);

        (
            ,
            ,
            startDate,
            paymentDueDate,
            incomingNetInterest,
            refinanceInterest,
            issuanceRate
        ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));

        assertEq(incomingNetInterest, 0);
        assertEq(refinanceInterest,   0);
        assertEq(startDate,           0);
        assertEq(paymentDueDate,      0);
        assertEq(issuanceRate,        0);
    }

}
