// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILiquidator, ILoanLike } from "../../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract LoanLiquidationTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    address loan;
    address loanManager;

    uint256 constant platformServiceFee     = uint256(1_000_000e6) * 0.0066e6 * 1_000_000 / (365 * 86400) / 1e6;
    uint256 constant platformOriginationFee = uint256(1_000_000e6) * 0.001e6 * 3 * 1_000_000 / (365 * 86400) / 1e6;

    function setUp() public virtual override {
        super.setUp();

        loanManager = poolManager.loanManagerList(0);

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 3.1536% * 2% * 1,000,000 / (365 * 86400) = 20
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10%   * 3  * 1,000,000 / (365 * 86400) = 95.129375e6
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%        * 1,000,000 / (365 * 86400) = 209.2846270e6
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 3.1536% * 8% * 1,000,000 / (365 * 86400) = 80
        });

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.4e6);  // 40%
    }

    function test_setMaxCoverLiquidationPercent_asOperationalAdmin() external {
        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0);

        assertEq(globals.maxCoverLiquidationPercent(address(poolManager)), 0);

        vm.prank(operationalAdmin);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.4e6);

        assertEq(globals.maxCoverLiquidationPercent(address(poolManager)), 0.4e6);
    }

    function test_finishCollateralLiquidation_asOperationalAdmin() external {
        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        vm.warp(start + 1_000_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30;
        uint256 netLateInterest     = (flatLateInterest + lateInterestPremium) * 9/10;
        uint256 platformFees        = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        liquidateCollateral(loan);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.expectRevert("PM:NOT_PD_OR_GOV_OR_OA");
        poolManager.finishCollateralLiquidation(loan);

        vm.prank(operationalAdmin);
        poolManager.finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });
    }

    /**************************************************************************************************************************************/
    /*** Full Cover                                                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_loanDefault_fullCover_withCollateral_noImpairment() external {
        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30;
        uint256 netLateInterest     = (flatLateInterest + lateInterestPremium) * 9/10;
        uint256 platformFees        = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 1023_120000);
        assertEq(platformFees,    380_228627);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 900e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 900e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 900e6 + netLateInterest - 150_000e6;
        assertEq(coverUsedForPool, 851_923_120000);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           475_358002);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_withCollateral_withImpairment() external {
        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 540e6 - 150_000e6;

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 540e6);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 500_000e6 + 540e6,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_noCollateral_noImpairment() external {
        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        // Assert that liquidationInfo was never created
        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30; // Default interest rate is double

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 1023_120000);
        assertEq(platformFees,    380_228627);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 900e6 + netLateInterest;
        assertEq(coverUsedForPool, 1_001_923_120000);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           475_358002);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_noCollateral_withImpairment() external {
        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 540e6;

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 540e6);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 500_000e6 + 540e6,
            unrealizedLosses: 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Partial Cover                                                                                                                  ***/
    /**************************************************************************************************************************************/

    function test_loanDefault_partialCover_withCollateral_noImpairment() external {
        depositCover(100_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30;
        uint256 netLateInterest     = (flatLateInterest + lateInterestPremium) * 9/10;
        uint256 platformFees        = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 1023_120000);
        assertEq(platformFees,    380_228627);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 900e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 900e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_619_771373);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           475_358002);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + 150_000e6 + coverUsedForPool);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6 + 150_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_withCollateral_withImpairment() external {
        depositCover(100_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + 150_000e6 + 40_000e6 - platformFees);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6 + 150_000e6 + 40_000e6 - platformFees,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_noCollateral_noImpairment() external {
        depositCover(100_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        // Assert that liquidationInfo was never created
        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 1023_120000);
        assertEq(platformFees,    380_228627);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_619_771373);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           475_358002);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + coverUsedForPool);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_noCollateral_withImpairment() external {
        depositCover(100_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + 40_000e6 - platformFees);

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6 + 40_000e6 - platformFees,
            unrealizedLosses: 0
        });
    }

    /**************************************************************************************************************************************/
    /*** No Cover                                                                                                                       ***/
    /**************************************************************************************************************************************/

    function test_loanDefault_noCover_withCollateral_noImpairment() external {
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e6 / 1e6;
        uint256 lateInterestPremium = 0.002e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 1023_120000);
        assertEq(platformFees,    380_228627);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 900e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 900e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        uint256 totalAssets    = 500_000e6 + (150_000e6 - platformFees);  // Platform fees are deducted from collateral liquidation.
        uint256 treasuryAssets = platformOriginationFee + platformFees;

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      totalAssets,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),        address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(totalAssets), uint256(0),         uint256(500e6),        uint256(treasuryAssets)]
        );
    }

    function test_loanDefault_noCover_withCollateral_withImpairment() external {
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  1_000_000e6 + 540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              0);
        assertEq(collateralAsset.balanceOf(liquidator),         100e18);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),              150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator),         0);
        assertEq(ILiquidator(liquidator).collateralRemaining(), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        finishCollateralLiquidation(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 1_500_000,
            unrealizedLosses:  0
        });

        uint256 totalAssets     = 500_000e6 + 150_000e6 - platformFees;
        uint256 treasuryAssets  = platformOriginationFee + platformFees;

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      totalAssets,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),        address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(totalAssets), uint256(0),         uint256(500e6),        uint256(treasuryAssets)]
        );
    }

    function test_loanDefault_noCover_noCollateral_noImpairment() external {
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   900e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.0009e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        // Assert that liquidationInfo was never created
        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 1_000_000 + 5 days + 1,
            domainEnd:         start + 1_000_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );
    }

    function test_loanDefault_noCover_noCollateral_withImpairment() external {
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        impairLoan(loan);

        uint256 platformFees = platformServiceFee + 80e6 * 600_000 / 1_000_000;
        assertEq(platformFees, 257.284627e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 540e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            domainEnd:         start + 600_000,
            unrealizedLosses:  1_000_540e6
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertLoanInfoWasDeleted(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       start + 600_000 + 5 days + 1,
            domainEnd:         start + 600_000 + 5 days + 1,
            unrealizedLosses:  0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      500_000e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            address(fundsAsset),
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );
    }

}

contract FinishLiquidationFailureTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    address loan;

    uint256 platformServiceFee     = uint256(1_000_000e6) * 0.0066e6 * 1_000_000 / (365 * 86400) / 1e6;
    uint256 platformOriginationFee = uint256(1_000_000e6) * 0.001e6 * 3 * 1_000_000 / (365 * 86400) / 1e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 3.1536% * 2% * 1,000,000 / (365 * 86400) = 20
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10%   * 3  * 1,000,000 / (365 * 86400) = 95.129375e6
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%        * 1,000,000 / (365 * 86400) = 209.2846270e6
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 3.1536% * 8% * 1,000,000 / (365 * 86400) = 80
        });

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.4e6);  // 40%

        depositCover(10_000_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: poolManager.loanManagerList(0)
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));
    }

    function test_finishLiquidation_failIfNotPD() external {
        vm.expectRevert("PM:NOT_PD_OR_GOV_OR_OA");
        poolManager.finishCollateralLiquidation(loan);
    }

    function test_finishLiquidation_failIfNotPoolManager() external {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(ILoanLike(loan).lender());

        vm.expectRevert("LM:NOT_PM");
        loanManager.finishCollateralLiquidation(loan);
    }

    function test_finishLiquidation_failIfLiquidationNotActive() external {
        vm.prank(poolDelegate);
        vm.expectRevert("LM:FCL:LIQ_ACTIVE");
        poolManager.finishCollateralLiquidation(loan);
    }

}
