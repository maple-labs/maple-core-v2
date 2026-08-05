// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20Like,
    IERC4626Like,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyRecognizeLossFailureTests is SkyStrategyTestBase {

    function testFork_recognizeLoss_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenNotProtocolAdmin() external {
        vm.prank(makeAddr("notProtocolAdmin"));
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenGovernor() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenLossAlreadyRecognized() external {
        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenLossAlreadyRecognized_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(operationalAdmin);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();
    }

}

contract SkyStrategyRecognizeLossTests is SkyStrategyTestBase {

    uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
    uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

    uint256 expectedRoundingLoss = 1;  // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.
    uint256 fundAmount           = 500_000e6;
    uint256 poolLiquidity        = 1_000_000e6;

    uint256 fundedAssets;
    uint256 fundedShares;
    uint256 initialSusdsBalance;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);
        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundedAssets        = fundAmount - expectedRoundingLoss;
        fundedShares        = fundAmount - expectedRoundingLoss;
        initialSusdsBalance = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_asStrategyDelegate() external {
        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_clearsImpairment() external {
        uint256 impairment = 100_000e6;

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: impairment
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: fundedAssets
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Recognize the loss and clear the impairment                                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_doesNotCollectAccruedFees() external {
        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm the outstanding fees                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netYield    = grossYield - delegateFee - protocolFee;
        uint256 netAum      = fundedAssets + netYield;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss + netYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Recognize the loss without collecting the accrued fees                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_strandsOutstandingRedemptionRequest() external {
        uint256 redeemShares = fundedShares / 4;

        /**********************************************************************************************************************************/
        /*** Request a redemption                                                                                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, redeemShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedShares,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Recognize the loss                                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm the outstanding redemption cannot be processed                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), redeemShares, "");
    }

    function testFork_recognizeLoss_strandsRedemptionRequestMadeAfterRecognition() external {
        uint256 redeemShares = fundedShares / 4;

        /**********************************************************************************************************************************/
        /*** Recognize the loss                                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        /**********************************************************************************************************************************/
        /*** Request a redemption after the loss is recognized                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, redeemShares);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm the redemption cannot be processed                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), redeemShares, "");
    }

    function testFork_recognizeLoss_donationDoesNotReviveAum() external {
        uint256 donationAssets = 100_000e18;

        /**********************************************************************************************************************************/
        /*** Recognize the loss                                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Donate assets and confirm the AUM remains zero                                                                             ***/
        /**********************************************************************************************************************************/

        deal(USDS, address(this), donationAssets, true);
        IERC20Like(USDS).approve(SAVINGS_USDS, donationAssets);

        uint256 donatedShares = IERC4626Like(SAVINGS_USDS).deposit(donationAssets, address(this));

        IERC20Like(SAVINGS_USDS).transfer(skyUnderlyingStrategy, donatedShares);

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), initialSusdsBalance + donatedShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_appliesToAllSharingPools() external {
        uint256 secondPoolFunding = 400_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        /**********************************************************************************************************************************/
        /*** Fund a second pool that shares the strategy                                                                                ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        uint256 firstPoolShares  = fundedShares;
        uint256 secondPoolShares = secondPoolFunding;
        uint256 totalShares      = firstPoolShares + secondPoolShares;
        uint256 susdsBalance     = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstPoolShares,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalShares,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: totalShares
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), susdsBalance);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolShares,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolShares,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Recognize the loss across both pools                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy),     susdsBalance);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
