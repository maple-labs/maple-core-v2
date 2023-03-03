// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../contracts/Contracts.sol";

import {
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract FixedTermLoanManagerFundTests is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address lp;

    IFixedTermLoan        loan1;
    IFixedTermLoan        loan2;
    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        borrower1 = address(new Address());
        borrower2 = address(new Address());
        lp        = address(new Address());

        depositLiquidity(lp, 1_500_000e6);

        vm.prank(governor);
        globals.setValidBorrower(borrower1, true);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,     // 150,000 * 0.02 = 3,000
            platformOriginationFeeRate: 0.001e6,    // 1,500,000 * 0.001   * 3,000,000 seconds / 365 days = 136.986301
            platformServiceFeeRate:     0.31536e6,  // 1,500,000 * 0.31536 * 1,000,000 seconds / 365 days = 15,000
            platformManagementFeeRate:  0.08e6      // 150,000 * 0.08 = 12,000
        });

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        loan1 = IFixedTermLoan(createLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        }));

        loan2 = IFixedTermLoan(createLoan({
            borrower:    borrower2,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(750_000e6), uint256(750_000e6)],
            rates:       [uint256(6.3072e18), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        }));
    }

    function test_fund_failIfProtocolIsPaused() external {
        vm.prank(globals.securityAdmin());
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:PROTOCOL_PAUSED");
        loanManager.fund(address(loan1), uint256(1_500_000e6));
    }

    function test_fund_failIfNotPoolDelegate() external {
        vm.expectRevert("LM:F:NOT_PD");
        loanManager.fund(address(loan1), uint256(1_500_000e6));
    }

    function test_fund_failIfTotalSupplyIsZero() external {
        // Burn the supply
        vm.startPrank(lp);
        pool.requestRedeem(1_500_000e6, lp);

        vm.warp(start + 2 weeks);

        pool.redeem(1_500_000e6, address(lp), address(lp));
        vm.stopPrank();

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        loanManager.fund(address(loan1), uint256(1_500_000e6));
    }

    function test_fund_failIfInsufficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1e6);

        fundsAsset.mint(address(poolManager.poolDelegateCover()), 1e6 - 1);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:INSUFFICIENT_COVER");
        loanManager.fund(address(loan1), uint256(1_500_000e6));
    }

    function test_fund_failIfPrincipalIsGreaterThanAssetBalance() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        loanManager.fund(address(loan1), uint256(1_500_000e6 + 1));
    }

    function test_fund_failIfPoolDoesNotApprovePM() external {
        // It's impossible to happen with current contracts, but testing here for completeness
        vm.prank(address(pool));
        fundsAsset.approve(address(poolManager), 0);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        loanManager.fund(address(loan1), uint256(1_000_000e6));
    }

    function test_fund_failIfAmountGreaterThanLockedLiquidity() external {
        address loan = createLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        // Lock the liquidity
        vm.prank(lp);
        pool.requestRedeem(500_000e6 + 1, lp);

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:LOCKED_LIQUIDITY");
        loanManager.fund(address(loan), uint256(1_000_000e6));

        vm.prank(lp);
        pool.removeShares(1, lp);  // Remove so exactly 500k is locked.

        vm.warp(start + 4 weeks);

        vm.prank(poolDelegate);
        loanManager.fund(address(loan), uint256(1_000_000e6));
    }

    function test_fund_failIfLoanActive() external {
        depositLiquidity(lp, 1_500_000e6);  // Deposit again

        vm.prank(poolDelegate);
        loanManager.fund(address(loan1), uint256(1_500_000e6));

        vm.prank(poolDelegate);
        vm.expectRevert("ML:FL:LOAN_ACTIVE");
        loanManager.fund(address(loan1), uint256(1_500_000e6));
    }

    function test_fund_failWithExcessFunds() external {
        depositLiquidity(lp, 1);  // Deposit again

        vm.prank(poolDelegate);
        vm.expectRevert("ML:FL:UNEXPECTED_FUNDS");
        loanManager.fund(address(loan1), uint256(1_500_000e6 + 1));
    }

    function test_fund_failWithLessFundsThanRequested() external {
        vm.prank(poolDelegate);
        vm.expectRevert(ARITHMETIC_ERROR);
        loanManager.fund(address(loan1), uint256(1_500_000e6 - 1));
    }

    function test_fund_oneLoan() external {
        assertEq(loanManager.accountedInterest(),          0);
        assertEq(loanManager.domainEnd(),                  0);
        assertEq(loanManager.domainStart(),                0);
        assertEq(loanManager.issuanceRate(),               0);
        assertEq(loanManager.paymentCounter(),             0);
        assertEq(loanManager.paymentIdOf(address(loan1)),  0);
        assertEq(loanManager.paymentWithEarliestDueDate(), 0);
        assertEq(loanManager.principalOut(),               0);

        {
            (
                uint256 platformManagementFeeRate,
                uint256 delegateManagementFeeRate,
                uint256 startDate,
                uint256 paymentDueDate,
                uint256 incomingNetInterest,
                uint256 refinanceInterest,
                uint256 issuanceRate
            ) = loanManager.payments(1);

            assertEq(delegateManagementFeeRate, 0);
            assertEq(incomingNetInterest,       0);
            assertEq(issuanceRate,              0);
            assertEq(paymentDueDate,            0);
            assertEq(platformManagementFeeRate, 0);
            assertEq(refinanceInterest,         0);
            assertEq(startDate,                 0);
        }

        {
            ( uint256 previous, uint256 next, uint256 sortedPaymentDueDate ) = loanManager.sortedPayments(1);

            assertEq(previous,             0);
            assertEq(next,                 0);
            assertEq(sortedPaymentDueDate, 0);
        }

        assertEq(feeManager.platformServiceFee(address(loan1)), 0);

        assertEq(loan1.drawableFunds(),      0);
        assertEq(loan1.lender(),             address(loanManager));
        assertEq(loan1.nextPaymentDueDate(), 0);
        assertEq(loan1.principal(),          0);

        assertEq(fundsAsset.balanceOf(address(loan1)),        0);
        assertEq(fundsAsset.balanceOf(address(pool)),         1_500_000e6);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 0);
        assertEq(fundsAsset.balanceOf(address(treasury)),     0);

        assertEq(fundsAsset.allowance(address(loan1), address(feeManager)), 0);

        fundLoan(address(loan1));

        assertEq(loanManager.accountedInterest(),          0);
        assertEq(loanManager.domainEnd(),                  start + 1_000_000);
        assertEq(loanManager.domainStart(),                start);
        assertEq(loanManager.issuanceRate(),               (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
        assertEq(loanManager.paymentCounter(),             1);
        assertEq(loanManager.paymentIdOf(address(loan1)),  1);
        assertEq(loanManager.paymentWithEarliestDueDate(), 1);
        assertEq(loanManager.principalOut(),               1_500_000e6);

        {
            (
                uint256 platformManagementFeeRate,
                uint256 delegateManagementFeeRate,
                uint256 startDate,
                uint256 paymentDueDate,
                uint256 incomingNetInterest,
                uint256 refinanceInterest,
                uint256 issuanceRate
            ) = loanManager.payments(1);

            assertEq(delegateManagementFeeRate, 0.02e6);
            assertEq(incomingNetInterest,       150_000e6 - 3_000e6 - 12_000e6);
            assertEq(issuanceRate,              (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
            assertEq(paymentDueDate,            start + 1_000_000);
            assertEq(platformManagementFeeRate, 0.08e6);
            assertEq(refinanceInterest,         0);
            assertEq(startDate,                 start);
        }

        {
            ( uint256 previous, uint256 next, uint256 sortedPaymentDueDate ) = loanManager.sortedPayments(1);

            assertEq(previous,             0);
            assertEq(next,                 0);
            assertEq(sortedPaymentDueDate, start + 1_000_000);
        }

        assertEq(feeManager.platformServiceFee(address(loan1)), 15_000e6);

        assertEq(loan1.drawableFunds(),      1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(loan1.lender(),             address(loanManager));
        assertEq(loan1.nextPaymentDueDate(), start + 1_000_000);
        assertEq(loan1.principal(),          1_500_000e6);

        assertEq(fundsAsset.balanceOf(address(loan1)),        1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(fundsAsset.balanceOf(address(pool)),         0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 500e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),     142.694063e6);

        assertEq(fundsAsset.allowance(address(loan1), address(feeManager)), type(uint256).max);
    }

    function test_fund_twoLoans() external {
        fundLoan(address(loan1));

        assertEq(loanManager.paymentIdOf(address(loan1)),  1);
        assertEq(loanManager.accountedInterest(),          0);
        assertEq(loanManager.domainEnd(),                  start + 1_000_000);
        assertEq(loanManager.domainStart(),                start);
        assertEq(loanManager.issuanceRate(),               (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
        assertEq(loanManager.paymentCounter(),             1);
        assertEq(loanManager.paymentWithEarliestDueDate(), 1);
        assertEq(loanManager.principalOut(),               1_500_000e6);

        {
            (
                uint256 platformManagementFeeRate,
                uint256 delegateManagementFeeRate,
                uint256 startDate,
                uint256 paymentDueDate,
                uint256 incomingNetInterest,
                uint256 refinanceInterest,
                uint256 issuanceRate
            ) = loanManager.payments(1);

            assertEq(delegateManagementFeeRate, 0.02e6);
            assertEq(incomingNetInterest,       150_000e6 - 3_000e6 - 12_000e6);
            assertEq(issuanceRate,              (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
            assertEq(paymentDueDate,            start + 1_000_000);
            assertEq(platformManagementFeeRate, 0.08e6);
            assertEq(refinanceInterest,         0);
            assertEq(startDate,                 start);
        }

        {
            ( uint256 previous, uint256 next, uint256 sortedPaymentDueDate ) = loanManager.sortedPayments(1);

            assertEq(previous,             0);
            assertEq(next,                 0);
            assertEq(sortedPaymentDueDate, start + 1_000_000);
        }

        assertEq(feeManager.platformServiceFee(address(loan1)), 15_000e6);

        assertEq(loan1.drawableFunds(),      1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(loan1.lender(),             address(loanManager));
        assertEq(loan1.nextPaymentDueDate(), start + 1_000_000);
        assertEq(loan1.principal(),          1_500_000e6);

        assertEq(fundsAsset.balanceOf(address(loan1)),        1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(fundsAsset.balanceOf(address(pool)),         0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 500e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),     142.694063e6);

        assertEq(fundsAsset.allowance(address(loan1), address(feeManager)), type(uint256).max);

        // Mint the extra funds needed to fund the second loan1.
        fundsAsset.mint(address(pool), 750_000e6);

        // Fund the second loan1 after some time passes.
        vm.warp(start + 1_000);
        fundLoan(address(loan2));

        assertEq(loanManager.paymentIdOf(address(loan1)), 1);
        assertEq(loanManager.paymentIdOf(address(loan2)), 2);

        assertEq(loanManager.accountedInterest(),          135e6);
        assertEq(loanManager.domainEnd(),                  start + 1_000_000);
        assertEq(loanManager.domainStart(),                start + 1_000);
        assertEq(loanManager.issuanceRate(),               2 * (150_000e6 - 3000e6 - 12_000e6) * 1e30 / 1_000_000);
        assertEq(loanManager.paymentCounter(),             2);
        assertEq(loanManager.paymentWithEarliestDueDate(), 1);
        assertEq(loanManager.principalOut(),               2_250_000e6);

        {
            (
                uint256 platformManagementFeeRate,
                uint256 delegateManagementFeeRate,
                uint256 startDate,
                uint256 paymentDueDate,
                uint256 incomingNetInterest,
                uint256 refinanceInterest,
                uint256 issuanceRate
            ) = loanManager.payments(1);

            assertEq(delegateManagementFeeRate, 0.02e6);
            assertEq(incomingNetInterest,       150_000e6 - 3_000e6 - 12_000e6);
            assertEq(issuanceRate,              (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
            assertEq(paymentDueDate,            start + 1_000_000);
            assertEq(platformManagementFeeRate, 0.08e6);
            assertEq(refinanceInterest,         0);
            assertEq(startDate,                 start);
        }

        {
            (
                uint256 platformManagementFeeRate,
                uint256 delegateManagementFeeRate,
                uint256 startDate,
                uint256 paymentDueDate,
                uint256 incomingNetInterest,
                uint256 refinanceInterest,
                uint256 issuanceRate
            ) = loanManager.payments(2);

            assertEq(delegateManagementFeeRate, 0.02e6);
            assertEq(incomingNetInterest,       150_000e6 - 3_000e6 - 12_000e6);
            assertEq(issuanceRate,              (150_000e6 - 3_000e6 - 12_000e6) * 1e30 / 1_000_000);
            assertEq(paymentDueDate,            start + 1_000 + 1_000_000);
            assertEq(platformManagementFeeRate, 0.08e6);
            assertEq(refinanceInterest,         0);
            assertEq(startDate,                 start + 1_000);
        }

        {
            ( uint256 previous, uint256 next, uint256 sortedPaymentDueDate ) = loanManager.sortedPayments(1);

            assertEq(previous,             0);
            assertEq(next,                 2);
            assertEq(sortedPaymentDueDate, start + 1_000_000);
        }

        {
            ( uint256 previous, uint256 next, uint256 sortedPaymentDueDate ) = loanManager.sortedPayments(2);

            assertEq(previous,             1);
            assertEq(next,                 0);
            assertEq(sortedPaymentDueDate, start + 1_000 + 1_000_000);
        }

        assertEq(feeManager.platformServiceFee(address(loan1)), 15_000e6);
        assertEq(feeManager.platformServiceFee(address(loan2)), 7_500e6);

        assertEq(loan1.drawableFunds(),      1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(loan1.lender(),             address(loanManager));
        assertEq(loan1.nextPaymentDueDate(), start + 1_000_000);
        assertEq(loan1.principal(),          1_500_000e6);

        assertEq(loan2.drawableFunds(),      750_000e6 - 500e6 - 71.347031e6);
        assertEq(loan2.lender(),             address(loanManager));
        assertEq(loan2.nextPaymentDueDate(), start + 1_000 + 1_000_000);
        assertEq(loan2.principal(),          750_000e6);

        assertEq(fundsAsset.balanceOf(address(loan1)),        1_500_000e6 - 500e6 - 142.694063e6);
        assertEq(fundsAsset.balanceOf(address(loan2)),        750_000e6   - 500e6 - 71.347031e6);
        assertEq(fundsAsset.balanceOf(address(pool)),         0);
        assertEq(fundsAsset.balanceOf(address(poolDelegate)), 500e6 + 500e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),     142.694063e6 + 71.347031e6);

        assertEq(fundsAsset.allowance(address(loan1), address(feeManager)), type(uint256).max);
        assertEq(fundsAsset.allowance(address(loan2), address(feeManager)), type(uint256).max);
    }

}

contract OpenTermLoanManagerFundTests is TestBaseWithAssertions {

    address borrower = address(new Address());

    uint32 gracePeriod     = 5 days;
    uint32 noticePeriod    = 5 days;
    uint32 paymentInterval = 30 days;

    uint64 interestRate = 0.1e18;

    uint256 principal = 1_500_000e6;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));
        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0, interestRate, 0, 0]
        ));
    }

    function test_fund_reentrancy() external {
        // TODO
    }

    function test_fund_notPoolDelegate() external {
        // TODO
    }

    function test_fund_invalidFactory() external {
        // TODO
    }

    function test_fund_notLoanManager() external {
        // TODO
    }

    function test_fund_zeroSupply() external {
        // TODO
    }

    function test_fund_insufficientCover() external {
        // TODO
    }

    function test_fund_transferFailed() external {
        // TODO
    }

    function test_fund_lockedLiquidity() external {
        // TODO
    }

    function test_fund_approveFailed() external {
        // TODO
    }

    function test_fund_notLender() external {
        // TODO
    }

    function test_fund_loanActive() external {
        // TODO
    }

    function test_fund_loanClosed() external {
        // TODO
    }

    function test_fund_transferFromFailed() external {
        // TODO
    }

    function test_fund_oneLoan() external {
        // TODO
    }

    function test_fund_twoLoans() external {
        // TODO
    }

}
