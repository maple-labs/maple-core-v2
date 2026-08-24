// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IPool
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";

contract ImpairedPoolJoinTests is AaveV3StrategyTestBase {

    address poolALp = makeAddr("poolALp");
    address poolBLp = makeAddr("poolBLp");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 impairmentAmount = 300_000e6 - 1;
    uint256 poolAFunding     = 1_000_000e6;
    uint256 poolBFunding     = 500_000e6;
    uint256 rounding         = 1;  // One funds-asset base unit.

    uint256 initialNetAssets;
    uint256 initialStrategyAum;
    uint256 jointNetAssets;
    uint256 jointStrategyAum;
    uint256 poolAAssets;
    uint256 poolALoss;
    uint256 poolANetAssets;
    uint256 poolAShares;
    uint256 poolBAssets;
    uint256 poolBExitAssets;
    uint256 poolBLoss;
    uint256 poolBShares;
    uint256 postCleanExitAum;
    uint256 postExitAum;
    uint256 totalShares;
    uint256 valueTransferred;

    function setUp() public override {
        super.setUp();

        poolA        = address(pool);
        poolManagerA = address(poolManager);

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", aaveV3StrategyManager);

        openPool(poolManagerA);
        openPool(poolManagerB);

        deposit(poolA, poolALp, poolAFunding);
        fundStrategyManager(poolManagerA, aaveV3StrategyManager, poolAFunding);

        poolAShares        = poolAFunding - rounding;    // 1_000_000e6 - 1
        initialStrategyAum = poolAShares;                // 1_000_000e6 - 1
        poolBShares        = poolBFunding;               // 500_000e6
        totalShares        = poolAShares + poolBShares;  // 1_500_000e6 - 1
        jointStrategyAum   = totalShares;                // 1_500_000e6 - 1

        poolAAssets = poolAShares * jointStrategyAum / totalShares;  // 1_000_000e6 - 1
        poolBAssets = poolBShares * jointStrategyAum / totalShares;  // 500_000e6

        postCleanExitAum = initialStrategyAum - rounding;  // 1_000_000e6 - 2
    }

    function testFork_joinBeforeImpairment_valueTransfersToIncumbentPool() external {
        /**********************************************************************************************************************************/
        /*** Assert Pool A is the sole shareholder before Pool B joins                                                                  ***/
        /**********************************************************************************************************************************/

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialStrategyAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     initialStrategyAum,
            aTokenBalance:           initialStrategyAum,
            lastRecordedTotalAssets: initialStrategyAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           poolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialStrategyAum,
            availableToWithdraw:   initialStrategyAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           initialStrategyAum,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Let Pool B join before impairment and allocate the subsequent loss across both Pools                                       ***/
        /**********************************************************************************************************************************/

        jointNetAssets   = jointStrategyAum - impairmentAmount;                      // 1_200_000e6
        poolALoss        = divRoundUp(poolAShares * impairmentAmount, totalShares);  // 200_000e6
        poolBLoss        = divRoundUp(poolBShares * impairmentAmount, totalShares);  // 100_000e6
        poolANetAssets   = poolAAssets - poolALoss;                                  // 800_000e6 - 1
        poolBExitAssets  = poolBShares * jointNetAssets / totalShares;               // 400_000e6
        postExitAum      = jointStrategyAum - poolBExitAssets - rounding;            // 1_100_000e6 - 2
        valueTransferred = postExitAum - postCleanExitAum;                           // 100_000e6

        deposit(poolB, poolBLp, poolBFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   poolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   poolBLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolANetAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBExitAssets);

        assertEq(poolALoss + poolBLoss, impairmentAmount + rounding);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     jointStrategyAum,
            aTokenBalance:           jointStrategyAum,
            lastRecordedTotalAssets: jointStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: jointStrategyAum,
            availableToWithdraw:   jointStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: poolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBShares,
            pendingShares:    0,
            unrealizedLosses: poolBLoss
        });

        /**********************************************************************************************************************************/
        /*** Exit Pool B while impaired and prove its loss remains with Pool A                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);
        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        postExitAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBExitAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolBExitAssets
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), postExitAum - impairmentAmount);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBExitAssets);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     postExitAum,
            aTokenBalance:           postExitAum,
            lastRecordedTotalAssets: postExitAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           poolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: postExitAum,
            availableToWithdraw:   postExitAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           postExitAum,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(poolBFunding - poolBExitAssets, valueTransferred);

        requestRedeem(poolB, poolBLp, poolBFunding);
        processRedemptions(poolB, poolBFunding);

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(poolBLp), poolBExitAssets);

        /**********************************************************************************************************************************/
        /*** Remove the impairment, fully exit Pool A and reconcile the first branch                                                    ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        postExitAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     postExitAum,
            aTokenBalance:           postExitAum,
            lastRecordedTotalAssets: postExitAum,
            unrealizedLosses:        0
        });

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        postExitAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: postExitAum
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        requestRedeem(poolA, poolALp, poolAFunding);
        processRedemptions(poolA, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(poolALp), postExitAum);
        assertEq(fundsAsset.balanceOf(poolBLp), poolBExitAssets);

        assertEq(postExitAum + poolBExitAssets, poolAFunding + poolBFunding - 2 * rounding);

        assertEq(poolBFunding - poolBExitAssets, postExitAum - poolAFunding + 2 * rounding);
        assertEq(poolBFunding - poolBExitAssets, valueTransferred);
        assertEq(postExitAum - postCleanExitAum, valueTransferred);
    }

    function testFork_joinWhileImpaired_valueTransfersToIncumbentPool() external {
        /**********************************************************************************************************************************/
        /*** Impair Pool A before Pool B joins the Strategy Manager                                                                     ***/
        /**********************************************************************************************************************************/

        initialNetAssets = poolAShares - impairmentAmount;                           // 700_000e6
        jointNetAssets   = jointStrategyAum - impairmentAmount;                      // 1_200_000e6
        poolALoss        = divRoundUp(poolAShares * impairmentAmount, totalShares);  // 200_000e6
        poolBLoss        = divRoundUp(poolBShares * impairmentAmount, totalShares);  // 100_000e6
        poolANetAssets   = poolAAssets - poolALoss;                                  // 800_000e6 - 1
        poolBExitAssets  = poolBShares * jointNetAssets / totalShares;               // 400_000e6
        postExitAum      = jointStrategyAum - poolBExitAssets - rounding;            // 1_100_000e6 - 2
        valueTransferred = postExitAum - postCleanExitAum;                           // 100_000e6

        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialStrategyAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), initialNetAssets);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     initialStrategyAum,
            aTokenBalance:           initialStrategyAum,
            lastRecordedTotalAssets: initialStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           poolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialStrategyAum,
            availableToWithdraw:   initialStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           initialStrategyAum,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        deposit(poolB, poolBLp, poolBFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);

        // Gross-AUM share minting gives the new Pool the same position and pre-existing loss as the first branch.
        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   poolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   poolBLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolANetAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBExitAssets);

        assertEq(poolANetAssets - initialNetAssets, valueTransferred - rounding);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     jointStrategyAum,
            aTokenBalance:           jointStrategyAum,
            lastRecordedTotalAssets: jointStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: jointStrategyAum,
            availableToWithdraw:   jointStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: poolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBShares,
            pendingShares:    0,
            unrealizedLosses: poolBLoss
        });

        /**********************************************************************************************************************************/
        /*** Exit Pool B and reconcile the transfer from the new Pool to the incumbent Pool                                             ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);
        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        postExitAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBExitAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolBExitAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     postExitAum,
            aTokenBalance:           postExitAum,
            lastRecordedTotalAssets: postExitAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           poolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: postExitAum,
            availableToWithdraw:   postExitAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           postExitAum,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeem(poolB, poolBLp, poolBFunding);
        processRedemptions(poolB, poolBFunding);

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeem(poolA, poolALp, poolAFunding);
        processRedemptions(poolA, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(poolALp), postExitAum);
        assertEq(fundsAsset.balanceOf(poolBLp), poolBExitAssets);

        assertEq(postExitAum + poolBExitAssets,  poolAFunding + poolBFunding - 2 * rounding);
        assertEq(poolBFunding - poolBExitAssets, valueTransferred);
        assertEq(postExitAum - postCleanExitAum, valueTransferred);
    }

    function testFork_joinAfterImpairmentRemoval_noValueTransfer() external {
        /**********************************************************************************************************************************/
        /*** Remove Pool A's impairment before Pool B joins the Strategy Manager                                                        ***/
        /**********************************************************************************************************************************/

        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);
        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialStrategyAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        deposit(poolB, poolBLp, poolBFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBAssets);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     jointStrategyAum,
            aTokenBalance:           jointStrategyAum,
            lastRecordedTotalAssets: jointStrategyAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: jointStrategyAum,
            availableToWithdraw:   jointStrategyAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Exit both Pools without an impairment and prove no value moves between them                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);
        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        postCleanExitAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolBFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     postCleanExitAum,
            aTokenBalance:           postCleanExitAum,
            lastRecordedTotalAssets: postCleanExitAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           poolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: postCleanExitAum,
            availableToWithdraw:   postCleanExitAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           postCleanExitAum,
            shares:           poolAShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeem(poolB, poolBLp, poolBFunding);
        processRedemptions(poolB, poolBFunding);

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAShares);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        requestRedeem(poolA, poolALp, poolAFunding);
        processRedemptions(poolA, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(poolALp), postCleanExitAum);
        assertEq(fundsAsset.balanceOf(poolBLp), poolBFunding);

        assertEq(postCleanExitAum + poolBFunding, poolAFunding + poolBFunding - 2 * rounding);
    }

}
