// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { OpenTermLoan, OpenTermLoanManager, Pool, PoolManager } from "../../contracts/Contracts.sol";

// TODO: Add assertOpenTermLoanPaymentState after creation.
// TODO: Add explicit asserts for all `expected*` variables at end of each section.

contract PoolLifecycleTest is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address borrower3;
    address borrower4;

    address lp1;
    address lp2;
    address lp3;
    address lp4;

    address loan1;
    address loan2;
    address loan3;
    address loan4;

    uint256 loan1AnnualInterest;
    uint256 loan2AnnualInterest;
    uint256 loan3AnnualInterest;
    uint256 loan4AnnualInterest;

    uint256 loan1IssuanceRate;
    uint256 loan2IssuanceRate;
    uint256 loan3IssuanceRate;
    uint256 loan4IssuanceRate;

    // LoanManager state assertion helper variables
    uint256 expectedAccountedInterest;
    uint256 expectedAccruedInterest;
    uint256 expectedDomainStart;
    uint256 expectedIssuanceRate;
    uint256 expectedPrincipalOut;

    // PoolManager state assertion helper variables
    uint256 expectedCash;
    uint256 expectedTotalAssets;
    uint256 expectedTotalSupply;
    uint256 expectedTotalAccruedInterest;
    uint256 expectedTotalPaidInterest;

    OpenTermLoanManager loanManager;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();

        borrower1 = address(new Address());  // TODO: makeAddr
        borrower2 = address(new Address());
        borrower3 = address(new Address());
        borrower4 = address(new Address());

        lp1 = address(new Address());
        lp2 = address(new Address());
        lp3 = address(new Address());
        lp4 = address(new Address());

        start = block.timestamp;
    }

    function test_poolLifecycle() public {
        /*******************************/
        /*** Step 1: PD creates pool ***/
        /*******************************/

        _createPool(openTermLoanManagerFactory, openTermLoanManagerInitializer, 1 weeks, 2 days);

        loanManager = OpenTermLoanManager(poolManager.loanManagerList(0));

        /****************************************/
        /*** Step 2: Governor and PD set fees ***/
        /****************************************/

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,  // TODO: Irrelevant
            delegateManagementFeeRate:  0.12e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.02e6,
            platformManagementFeeRate:  0.08e6
        });

        /*****************************************************/
        /*** Step 3: Governor sets max liquidation percent ***/
        /*****************************************************/

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 50_0000);

        /*****************************/
        /*** Step 4: PD adds cover ***/
        /*****************************/

        fundsAsset.mint(address(poolDelegate), 1_000_000e6);

        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(poolManager), 1_000_000e6);
        poolManager.depositCover(1_000_000e6);
        vm.stopPrank();

        /*******************************************/
        /*** Step 5: Governor activates the Pool ***/
        /*******************************************/

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        /******************************************/
        /*** Step 6: PD sets the Pool to public ***/
        /******************************************/

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        /***********************************************/
        /*** Step 7: 2 LPs deposit 5m each at ER = 1 ***/
        /***********************************************/

        vm.warp(start + 1 days);

        depositLiquidity(lp1, 5_000_000e6);
        depositLiquidity(lp2, 5_000_000e6);

        expectedCash        = 10_000_000e6;
        expectedTotalAssets = 10_000_000e6;
        expectedTotalSupply = 10_000_000e6;

        assertEq(Pool(pool).balanceOf(lp1), 5_000_000e6);
        assertEq(Pool(pool).balanceOf(lp2), 5_000_000e6);

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        /*******************************************************/
        /*** Step 8: Fund Loan 1 on Day 2 for 2.5m at 8% APR ***/
        /*******************************************************/

        vm.warp(start + 2 days);

        loan1 = createOpenTermLoan({
            borrower:  borrower1,
            lender:    address(loanManager),
            asset:     address(fundsAsset),
            principal: 2_500_000e6,
            terms:     [uint32(5 days), uint32(3 days),  uint32(30 days)],
            rates:     [uint64(0.01e18), uint64(0.08e18), uint64(0.05e18), uint64(0.02e18)]
        });

        loan1AnnualInterest = 2_500_000e6 * 0.8e6 * 0.08e18 / 1e6 / 1e18;

        assertOpenTermLoan({
            loan:            loan1,
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       2_500_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       0,
            issuanceRate:      0,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan1,
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertEq(fundsAsset.balanceOf(borrower1), 0);

        fundLoan(loan1);

        expectedCash         -= 2_500_000e6;
        expectedPrincipalOut += 2_500_000e6;

        uint256 grossInterest = uint256(2_500_000e6) * 0.08e18 * 30 days / 365 days / 1e18;

        loan1IssuanceRate = (grossInterest - grossInterest * 0.2e6 / 1e6) * 1e27 / 30 days;

        assertEq(fundsAsset.balanceOf(borrower1), 2_500_000e6);

        assertOpenTermLoanPaymentState({
            loan:               loan1,
            paymentTimestamp:   uint40(start + 2 days + 30 days),
            principal:          0,
            interest:           uint256(2_500_000e6) * 0.08e18 * 30 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(2_500_000e6) * 30 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(2_500_000e6) * 30 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 2 days + 30 days,
            defaultDate:        start + 2 days + 30 days + 5 days
        });

        assertOpenTermLoan({
            loan:            loan1,
            dateCalled:      0,
            dateFunded:      start + 2 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       2_500_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 2 days,
            issuanceRate:      loan1IssuanceRate,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan1,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 2 days,
            issuanceRate:    loan1IssuanceRate
        });

        /******************************************************/
        /*** Step 9: Fund Loan 2 on Day 3 for 1m at 10% APR ***/
        /******************************************************/

        vm.warp(start + 3 days);

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 1 days / 365 days +
            loan2AnnualInterest * 0 days / 365 days;

        expectedTotalAssets += expectedTotalAccruedInterest;

        // NOTE: expectedAccountedInterest == 0 here
        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        loan2 = createOpenTermLoan({
            borrower:  borrower2,
            lender:    address(loanManager),
            asset:     address(fundsAsset),
            principal: 1_000_000e6,
            terms:     [uint32(5 days),  uint32(3 days),  uint32(30 days)],
            rates:     [uint64(0.01e18), uint64(0.10e18), uint64(0.05e18), uint64(0.02e18)]
        });

        loan2AnnualInterest = 1_000_000e6 * 0.10e18 * 0.8e6 / 1e18 / 1e6;

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       1_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 2 days,
            issuanceRate:      loan1IssuanceRate,
            accountedInterest: 0,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertEq(fundsAsset.balanceOf(borrower2), 0);

        fundLoan(loan2);

        expectedCash         -= 1_000_000e6;
        expectedPrincipalOut += 1_000_000e6;

        expectedAccountedInterest += expectedAccruedInterest;
        expectedAccruedInterest    = 0;

        grossInterest = uint256(1_000_000e6) * 0.10e18 * 30 days / 365 days / 1e18;

        loan2IssuanceRate = (grossInterest - grossInterest * 0.2e6 / 1e6) * 1e27 / 30 days;

        assertEq(fundsAsset.balanceOf(borrower2), 1_000_000e6);

        assertOpenTermLoanPaymentState({
            loan:               loan2,
            paymentTimestamp:   uint40(start + 3 days + 30 days),
            principal:          0,
            interest:           uint256(1_000_000e6) * 0.10e18 * 30 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(1_000_000e6) * 30 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(1_000_000e6) * 30 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 3 days + 30 days,
            defaultDate:        start + 3 days + 30 days + 5 days
        });

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      0,
            dateFunded:      start + 3 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       1_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 3 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 3 days,
            issuanceRate:    loan2IssuanceRate
        });

        // TODO: Add a block of assertions that asserts all the `expected` state variables with explicit numbers.

        /******************************************/
        /*** Step 10: LP3 deposits 5m at ER > 1 ***/
        /******************************************/

        vm.warp(start + 5 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 3 days / 365 days +
            loan2AnnualInterest * 2 days / 365 days;

        expectedTotalAssets += expectedTotalAccruedInterest;

        // LP3 deposits 5 mil
        depositLiquidity(lp3, 5_000_000e6);

        expectedCash        += 5_000_000e6;
        expectedTotalSupply += (5_000_000e6 * expectedTotalSupply) / expectedTotalAssets;
        expectedTotalAssets += 5_000_000e6;

        assertPoolState({
            totalSupply:        expectedTotalSupply,  // LP3 gets less shares compared to LP1/LP2 as exchange rate has updated
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        /************************************************/
        /*** Step 11: LP1 requests to redeem on Day 6 ***/
        /************************************************/

        vm.warp(start + 6 days);

        // LP1 requests to withdraw full liquidity before cycle 1 finishes to hit cycle 3
        uint256 lp1Shares = Pool(pool).balanceOf(lp1);

        requestRedeem(address(pool), lp1, lp1Shares);

        assertEq(Pool(pool).balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 lp1Shares,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      lp1Shares,
            withdrawalManagerTotalShares: lp1Shares
        });

        /****************************************************************************/
        /*** Step 12: LP1 redeems on Day 14, one day into their withdrawal window ***/
        /****************************************************************************/

        // Warp to one day into WW to let LP1 redeem
        vm.warp(start + 14 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 12 days / 365 days +
            loan2AnnualInterest * 11 days / 365 days;

        expectedTotalAssets += expectedTotalAccruedInterest;

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        uint256 lp1Assets = redeem(address(pool), lp1, lp1Shares);

        assertEq(lp1Assets, (lp1Shares * expectedTotalAssets) / expectedTotalSupply);

        expectedCash        -= lp1Assets;
        expectedTotalAssets -= lp1Assets;
        expectedTotalSupply -= lp1Shares;

        assertEq(Pool(pool).balanceOf(lp1),                        0);
        assertEq(Pool(pool).balanceOf(address(withdrawalManager)), 0);
        assertEq(fundsAsset.balanceOf(lp1),                        lp1Assets);

        // Full withdrawal
        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        /*******************************************************/
        /*** Step 13: Fund Loan 3 on Day 21 for 3m at 7% APR ***/
        /*******************************************************/

        vm.warp(start + 21 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 19 days / 365 days +
            loan2AnnualInterest * 18 days / 365 days;

        expectedTotalAssets += expectedTotalAccruedInterest;

        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        loan3 = createOpenTermLoan({
            borrower:  borrower3,
            lender:    address(loanManager),
            asset:     address(fundsAsset),
            principal: 3_000_000e6,
            terms:     [uint32(5 days),  uint32(3 days),  uint32(30 days)],
            rates:     [uint64(0.01e18), uint64(0.07e18), uint64(0.05e18), uint64(0.02e18)]
        });

        loan3AnnualInterest = 3_000_000e6 * 0.07e18 * 0.8e6 / 1e18 / 1e6;

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       3_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 3 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertEq(fundsAsset.balanceOf(borrower3), 0);

        fundLoan(loan3);

        assertEq(fundsAsset.balanceOf(borrower3), 3_000_000e6);

        expectedCash         -= 3_000_000e6;
        expectedPrincipalOut += 3_000_000e6;

        expectedAccountedInterest += expectedAccruedInterest;
        expectedAccruedInterest    = 0;

        grossInterest = uint256(3_000_000e6) * 0.07e18 * 30 days / 365 days / 1e18;

        loan3IssuanceRate = (grossInterest - grossInterest * 0.2e6 / 1e6) * 1e27 / 30 days;

        assertOpenTermLoanPaymentState({
            loan:               loan3,
            paymentTimestamp:   uint40(start + 21 days + 30 days),
            principal:          0,
            interest:           uint256(3_000_000e6) * 0.07e18 * 30 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(3_000_000e6) * 30 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(3_000_000e6) * 30 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 21 days + 30 days,
            defaultDate:        start + 21 days + 30 days + 5 days
        });

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      0,
            dateFunded:      start + 21 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       3_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 21 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 21 days,
            issuanceRate:    loan3IssuanceRate
        });

        /**************************************/
        /*** Step 13: Call Loan 2 on Day 25 ***/
        /**************************************/

        vm.warp(start + 25 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 23 days / 365 days +
            loan2AnnualInterest * 22 days / 365 days +
            loan3AnnualInterest *  4 days / 365 days;

        expectedTotalAssets += expectedTotalAccruedInterest;

        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      0,
            dateFunded:      start + 3 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       1_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 21 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 3 days,
            issuanceRate:    loan2IssuanceRate
        });

        callLoan(address(loanManager), loan2, OpenTermLoan(loan2).principal());

        assertOpenTermLoanPaymentState({
            loan:               loan2,
            paymentTimestamp:   uint40(start + 3 days + 22 days + 3 days),   // Day 3 start + 22 days in + 3 day notice period
            principal:          uint256(1_000_000e6),
            interest:           uint256(1_000_000e6) * 0.10e18 * 25 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(1_000_000e6) * 25 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(1_000_000e6) * 25 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 3 days + 22 days + 3 days,
            defaultDate:        start + 3 days + 22 days + 3 days
        });

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      start + 25 days,
            dateFunded:      start +  3 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 1_000_000e6,
            principal:       1_000_000e6
        });

        // NOTE: No accounting state changes during a call.

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 21 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 3 days,
            issuanceRate:    loan2IssuanceRate
        });

        /*********************************************************/
        /*** Step 14: Make Closing Payment on Loan 2 on Day 26 ***/
        /*********************************************************/

        vm.warp(start + 26 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 24 days / 365 days +
            loan2AnnualInterest * 23 days / 365 days +
            loan3AnnualInterest *  5 days / 365 days -
            1;  // Rounding

        expectedTotalAssets += expectedTotalAccruedInterest;

        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      start + 25 days,
            dateFunded:      start +  3 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 1_000_000e6,
            principal:       1_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 21 days,
            issuanceRate:      loan1IssuanceRate + loan2IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 3 days,    // No change
            issuanceRate:    loan2IssuanceRate  // No change
        });

        ( uint256 principal, uint256 interest, ) = makeOpenTermPayment(loan2);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        // Rounding removed since payment was made and dust from mgmt fee is given to Pool.
        expectedTotalAccruedInterest =
            loan1AnnualInterest * 24 days / 365 days +
            loan3AnnualInterest *  5 days / 365 days -
            1;

        expectedTotalPaidInterest += (loan2AnnualInterest * 23 days / 365 days) + 1;  // Rounds up on payment

        expectedTotalAssets += expectedTotalAccruedInterest + expectedTotalPaidInterest;

        expectedAccountedInterest += expectedAccruedInterest;
        expectedAccountedInterest -= (loan2AnnualInterest * 23 days / 365 days);

        expectedAccruedInterest = 0;

        expectedCash += (principal + interest * 80 / 100 + 1);  // Rounding error from mgmt fees given to pool.

        expectedPrincipalOut -= 1_000_000e6;

        assertOpenTermLoanPaymentState({
            loan:               loan2,
            paymentTimestamp:   uint40(start + 26 days + 30 days),  // Non-zero timestamp to pass in.
            principal:          0,
            interest:           0,
            lateInterest:       0,
            delegateServiceFee: 0,
            platformServiceFee: 0,
            paymentDueDate:     0,
            defaultDate:        0
        });

        assertOpenTermLoan({
            loan:            loan2,
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       0
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 26 days,
            issuanceRate:      loan1IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan2,
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        /**************************************/
        /*** Step 15: Call Loan 3 on Day 27 ***/
        /**************************************/

        vm.warp(start + 27 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        expectedTotalAccruedInterest =
            loan1AnnualInterest * 25 days / 365 days +
            loan3AnnualInterest *  6 days / 365 days -
            1;  // Rounding

        expectedTotalAssets += expectedTotalAccruedInterest;

        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      0,
            dateFunded:      start + 21 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       3_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 26 days,
            issuanceRate:      loan1IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 21 days,
            issuanceRate:    loan3IssuanceRate
        });

        callLoan(address(loanManager), loan3, OpenTermLoan(loan3).principal());

        assertOpenTermLoanPaymentState({
            loan:               loan3,
            paymentTimestamp:   uint40(start + 21 days + 6 days + 3 days),
            principal:          uint256(3_000_000e6),
            interest:           uint256(3_000_000e6) * 0.07e18 * 9 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(3_000_000e6) * 9 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(3_000_000e6) * 9 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 21 days + 6 days + 3 days,
            defaultDate:        start + 21 days + 6 days + 3 days
        });

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      start + 27 days,
            dateFunded:      start + 21 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 3_000_000e6,
            principal:       3_000_000e6
        });

        // NOTE: No accounting state changes during a call.

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 26 days,
            issuanceRate:      loan1IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 21 days,
            issuanceRate:    loan3IssuanceRate
        });

        /************************************************/
        /*** Step 16: Remove Call on Loan 3 on Day 31 ***/
        /************************************************/

        vm.warp(start + 31 days);

        expectedTotalAssets -= expectedTotalAccruedInterest;  // Remove old component

        // Only accrues to Day 30 since it is the domainEnd.
        expectedTotalAccruedInterest =
            loan1AnnualInterest * 29 days / 365 days +
            loan3AnnualInterest * 10 days / 365 days -
            2;  // Rounding

        expectedTotalAssets += expectedTotalAccruedInterest;

        expectedAccruedInterest = expectedTotalAccruedInterest - expectedAccountedInterest;

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      start + 27 days,
            dateFunded:      start + 21 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 3_000_000e6,
            principal:       3_000_000e6
        });

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 26 days,
            issuanceRate:      loan1IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 21 days,
            issuanceRate:    loan3IssuanceRate
        });

        removeLoanCall(address(loanManager), loan3);

        assertOpenTermLoanPaymentState({
            loan:               loan3,
            paymentTimestamp:   uint40(start + 21 days + 30 days),
            principal:          0,
            interest:           uint256(3_000_000e6) * 0.07e18 * 30 / 365 / 1e18,
            lateInterest:       0,
            delegateServiceFee: uint256(3_000_000e6) * 30 * 0.01e6 / 1e6 / 365,
            platformServiceFee: uint256(3_000_000e6) * 30 * 0.02e6 / 1e6 / 365,
            paymentDueDate:     start + 21 days + 30 days,
            defaultDate:        start + 21 days + 30 days + 5 days
        });

        assertOpenTermLoan({
            loan:            loan3,
            dateCalled:      0,
            dateFunded:      start + 21 days,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       3_000_000e6
        });

        // NOTE: No accounting state changes during a call removal.

        assertPoolState({
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + 26 days,
            issuanceRate:      loan1IssuanceRate + loan3IssuanceRate,
            accountedInterest: expectedAccountedInterest,
            accruedInterest:   expectedAccruedInterest,
            principalOut:      expectedPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            loan3,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.12e6,
            startDate:       start + 21 days,
            issuanceRate:    loan3IssuanceRate
        });
    }

}