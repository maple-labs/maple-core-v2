// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console  } from "../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract LoanDefaultTests is TestBaseWithAssertions {

    address borrower = address(new Address());
    address lp       = address(new Address());

    Loan loan;

    uint256 platformServiceFee     = uint256(1_000_000e6) * 0.0066e6 * 1_000_000 / (365 * 86400) / 1e6;
    uint256 platformOriginationFee = uint256(1_000_000e6) * 0.001e6 * 3 * 1_000_000 / (365 * 86400) / 1e6;

    function setUp() public virtual override {
        super.setUp();

        depositLiquidity({
            lp: lp,
            liquidity: 1_500_000e6
        });

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

    /*********************/
    /*** Full Cover ***/
    /*********************/

    function test_loanDefault_fullCover_withCollateral_noTDW() external {
        depositCover({ cover: 10_000_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e18 / 1e18;
        uint256 lateInterestPremium = 0.0011e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 603_216000);
        assertEq(platformFees,    342_903827);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     900e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 900e6 + netLateInterest
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6 + netLateInterest
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 900e6 + netLateInterest - 150_000e6;
        assertEq(coverUsedForPool, 851_503_216000);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           438_033202);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest);

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_withCollateral_withTDW() external {
        depositCover({ cover: 10_000_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 540e6
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 540e6 - 150_000e6;

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           268_700151);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 540e6);

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 540e6,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_noCollateral_noTDW() external {
        depositCover({ cover: 10_000_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
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

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e18 / 1e18;
        uint256 lateInterestPremium = 0.0011e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 603_216000);
        assertEq(platformFees,    342_903827);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 900e6 + netLateInterest;
        assertEq(coverUsedForPool, 100_1503_216000);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           438_033202);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest);

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 900e6 + netLateInterest,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_fullCover_noCollateral_withTDW() external {
        depositCover({ cover: 10_000_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover),    address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(10_000_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 1_000_000e6 + 540e6;

        assertEq(fundsAsset.balanceOf(address(poolCover)), 10_000_000e6 - coverUsedForPool - platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           268_700151);
        assertEq(fundsAsset.balanceOf(address(pool)),      1_000_000e6 + 500_000e6 + 540e6);

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 540e6,
            unrealizedLosses: 0
        });
    }

    /*********************/
    /*** Partial Cover ***/
    /*********************/

    function test_loanDefault_partialCover_withCollateral_noTDW() external {
        depositCover({ cover: 100_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e18 / 1e18;
        uint256 lateInterestPremium = 0.0011e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 603_216000);
        assertEq(platformFees,    342_903827);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     900e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 900e6 + netLateInterest
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6 + netLateInterest
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_657_096173);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           438_033202);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + 150_000e6 + coverUsedForPool);

        assertPoolManager({
            totalAssets:      500_000e6 + 150_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_withCollateral_withTDW() external {
        depositCover({ cover: 100_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 540e6
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_826_429224);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           268_700151);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + 150_000e6 + coverUsedForPool);

        assertPoolManager({
            totalAssets:      500_000e6 + 150_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_noCollateral_noTDW() external {
        depositCover({ cover: 100_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
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

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e18 / 1e18;
        uint256 lateInterestPremium = 0.0011e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 603_216000);
        assertEq(platformFees,    342_903827);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_657_096173);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           platformOriginationFee + platformFees);
        assertEq(fundsAsset.balanceOf(treasury),           438_033202);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + coverUsedForPool);

        assertPoolManager({
            totalAssets:      500_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    function test_loanDefault_partialCover_noCollateral_withTDW() external {
        depositCover({ cover: 100_000e6 });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        uint256 coverUsedForPool = 40_000e6 - platformFees;
        assertEq(coverUsedForPool, 39_826_429224);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 60_000e6);
        assertEq(fundsAsset.balanceOf(treasury),           268_700151);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 + coverUsedForPool);

        assertPoolManager({
            totalAssets:      500_000e6 + coverUsedForPool,
            unrealizedLosses: 0
        });
    }

    /****************/
    /*** No Cover ***/
    /****************/

    function test_loanDefault_noCover_withCollateral_noTDW() external {

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        uint256 flatLateInterest    = 1_000_000e6 * 0.0001e18 / 1e18;
        uint256 lateInterestPremium = 0.0011e6 * 1e30 * (6 days) / 1e30;

        uint256 netLateInterest = (flatLateInterest + lateInterestPremium) * 9/10;

        uint256 platformFees = platformServiceFee + (1000e6 + flatLateInterest + lateInterestPremium) * 8/100;

        assertEq(netLateInterest, 603_216000);
        assertEq(platformFees,    342_903827);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            900e6,
            lateInterest:        netLateInterest,
            platformFees:        platformFees,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     900e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 900e6 + netLateInterest
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 900e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 900e6 + netLateInterest
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 totalAssets    = 500_000e6 + (150_000e6 - platformFees);  // Platform fees are deducted from collateral liquidation.
        uint256 treasuryAssets = platformOriginationFee + platformFees;

        assertPoolManager({
            totalAssets:      totalAssets,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(pool),        address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(totalAssets), uint256(0),         uint256(500e6),        uint256(treasuryAssets)]
        );
    }

    function test_loanDefault_noCover_withCollateral_withTDW() external {

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + 540e6
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 540e6 + 500_000e6,
            unrealizedLosses: 1_000_000e6 + 540e6
        });

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertEq(fundsAsset.balanceOf(liquidator),      0);
        assertEq(collateralAsset.balanceOf(liquidator), 100e18);

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertEq(fundsAsset.balanceOf(liquidator),      150_000e6);
        assertEq(collateralAsset.balanceOf(liquidator), 0);

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.warp(start + 1_500_000);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 1_500_000,
            unrealizedLosses:      0
        });

        uint256 totalAssets     = 500_000e6 + 150_000e6 - platformFees;
        uint256 treasuryAssets  = platformOriginationFee + platformFees;

        assertPoolManager({
            totalAssets:      totalAssets,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(pool),        address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(totalAssets), uint256(0),         uint256(500e6),        uint256(treasuryAssets)]
        );
    }

    function test_loanDefault_noCover_noCollateral_noTDW() external {

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       900e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_900e6,
            issuanceRate:          0.0009e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_900e6,
            unrealizedLosses: 0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
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

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 1_000_000 + 5 days + 1,
            domainEnd:             start + 1_000_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      500_000e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );
    }

    function test_loanDefault_noCover_noCollateral_withTDW() external {

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );

        vm.warp(start + 600_000);

        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        uint256 platformFees = (platformServiceFee + 80e6) * 600_000 / 1_000_000;
        assertEq(platformFees, 173_570776);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            540e6,  // 60% of 900
            lateInterest:        0,
            platformFees:        platformFees,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 900e6,
            refinanceInterest:   0,
            issuanceRate:        0.0009e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000  // Keep original date in case TDW reverted
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     540e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_540e6,
            issuanceRate:          0,
            domainStart:           start + 600_000,
            domainEnd:             start + 600_000,
            unrealizedLosses:      1_000_540e6
        });

        assertPoolManager({
            totalAssets:      1_500_540e6,
            unrealizedLosses: 1_000_540e6
        });

        vm.warp(start + 600_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        assertLoanInfoWasDeleted(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 600_000 + 5 days + 1,
            domainEnd:             start + 600_000 + 5 days + 1,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      500_000e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(500_000e6), uint256(0),         uint256(500e6),        uint256(platformOriginationFee)]
        );
    }

}

contract DefaultWarningTests is TestBaseWithAssertions {

    address borrower = address(new Address());
    address lp       = address(new Address());

    Loan loan;

    function setUp() public override {
        super.setUp();

        depositCover({ cover: 100_000e6 });

        depositLiquidity({
            lp: lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,     // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,     // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 7.50% * 2% / 12 = 125
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 7.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and drawdown loan ***/
        /******************************/

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5_000), uint256(ONE_MONTH), uint256(3)],
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:     [uint256(0.075e18), 0, 0, 0]
        });
    }

    function setUpTDWTest() internal {
        // Pool liquidity:  1,500,000 - 1,000,000  = 500,000
        // Gross interest:  1,000,000 * 7.50% / 12 =   6,250
        // Service fees:                 275 + 550 =     825
        // Management fees:              125 + 500 =     625
        // Net interest:         6,250 - 125 - 500 =   5,625

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6,
            unrealizedLosses: 0
        });

        // Origination fees: 500 + 250 = 750
        // Borrower cash:    1,000,000 - 750 = 999,250

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(250e6)   ]
        );

        /************************************/
        /*** Warp to 1st payment due date ***/
        /************************************/

        vm.warp(start + ONE_MONTH);

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
            accruedInterest:       5_625e6 - 1,  // -1 due to issuance rate rounding error.
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 - 1,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6 - 1,
            unrealizedLosses: 0
        });

        /************************/
        /*** Make 1st payment ***/
        /************************/

        makePayment(loan);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + 1 * ONE_MONTH,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        /*******************************************************************/
        /*** Trigger default warning at 1/5 of the next payment interval ***/
        /*******************************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5);
        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    block.timestamp,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            lateInterest:        0,
            platformFees:        1050e6 / 5,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1) / 5,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + uint256(5_625e6 - 1) / 5
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 / 5 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 / 5 - 1)
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );
    }

    function test_triggerDefaultWarning_thenCancel() external {
        setUpTDWTest();

        /******************************************************************/
        /*** Remove the default warning a day after the default warning ***/
        /******************************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6 - 1) / 5,  // No change, value no longer accruing
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1) / 5,  // No change, value no longer accruing
            issuanceRate:          0,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5,
            domainEnd:             start + ONE_MONTH + ONE_MONTH / 5,
            unrealizedLosses:      1_000_000e6 + uint256(5_625e6 - 1) / 5
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 / 5 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 / 5 - 1)
        });

        vm.prank(poolDelegate);
        poolManager.removeDefaultWarning(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           block.timestamp,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 5_625e6 + 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        /***********************************************************************/
        /*** Make another payment after the default warning has been removed ***/
        /***********************************************************************/

        vm.warp(start + 2 * ONE_MONTH);

        uint256 accountedInterest = 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH;  // Accounted at time of default warning removal.

        assertLoanManager({
            accruedInterest:       5_625e6 - accountedInterest - 1,
            accountedInterest:     accountedInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1),
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 0
        });

        makePayment(loan);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3 * ONE_MONTH,
            paymentsRemaining: 1
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 2 * ONE_MONTH,
            paymentDueDate:      start + 3 * ONE_MONTH
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           block.timestamp,
            domainEnd:             start + 3 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 2 * 5_625e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(511_250e6), uint256(100_000e6), uint256(1300e6),       uint256(2350e6)  ]
        );
    }

    function test_triggerDefaultWarning_thenRepay() external {
        setUpTDWTest();

        /******************************************************/
        /*** Make a payment a day after the default warning ***/
        /******************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);
        makePayment(loan);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH + ONE_MONTH / 5,
            paymentsRemaining: 1
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH + ONE_MONTH / 5,
            paymentDueDate:      start + 2 * ONE_MONTH + ONE_MONTH / 5
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6) * 12 / 365,  // one day of interest: 5,625 * 12 / 365
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6) * 12 / 365,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY,
            domainEnd:             start + ONE_MONTH + ONE_MONTH / 5 + ONE_MONTH,
            unrealizedLosses:      0
        });

        // TODO: Add a late interest premium to illustrate difference in late interest.
        assertPoolManager({
            totalAssets:      500_000e6 + 1_000_000e6 + 2 * 5_625e6 + 2 * uint256(5_625e6) * 12 / 365,  // 5_625e6 * 12 / 365 accounted for twice as part is from late interest and part is from the next interval
            unrealizedLosses: 0
        });

        // Pool balance:          500,000       + 5,625 * (2 + 12 / 365)
        // Pool delegate balance: 900     + 275 +   125 * (1 + 12 / 365)
        // Treasury balance:      1,300   + 550 +   500 * (1 + 12 / 365)

        assertAssetBalances(
            [address(borrower),  address(pool),             address(poolCover), address(poolDelegate),   address(treasury)      ],
            [uint256(999_250e6), uint256(511_434.931507e6), uint256(100_000e6), uint256(1_304.109589e6), uint256(2_366.438356e6)]
        );

        /*****************************/
        /*** Make the last payment ***/
        /*****************************/

        vm.warp(start + 2 * ONE_MONTH + ONE_MONTH / 5);
        makePayment(loan);

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      0
        });

        // pool balance:          1,000,000 + 500,000 + 5,625 * (3 + 12 / 365)  // Three payments plus one day of late interest.
        // pool delegate balance: 900       + 2 * 275 +   125 * (2 + 12 / 365)
        // treasury balance:      1,300     + 2 * 550 +   500 * (2 + 12 / 365)

        assertPoolManager({
            totalAssets:      1_517_059.931507e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),               address(poolCover), address(poolDelegate),   address(treasury)      ],
            [uint256(999_250e6), uint256(1_517_059.931507e6), uint256(100_000e6), uint256(1_704.109589e6), uint256(3_416.438356e6)]
        );
    }

}
