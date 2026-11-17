// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAaveV3Strategy, IERC20, IPool } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";

contract ImpairmentValueTransferTests is AaveV3StrategyTestBase {

    address poolA;
    address poolALp = makeAddr("poolALp");
    address poolB;
    address poolBLp = makeAddr("poolBLp");
    address poolManagerA;
    address poolManagerB;

    uint256 impairmentAmount = 200_000e6;
    uint256 poolAFunding     = 600_000e6;
    uint256 poolBFunding     = 400_000e6;
    uint256 rounding         = 1; // One funds-asset base unit.

    uint256 firstPoolAExitAssets;
    uint256 firstPoolBExitValue;
    uint256 firstRemainingAum;
    uint256 initialPoolALoss;
    uint256 initialPoolAShares;
    uint256 initialPoolBLoss;
    uint256 initialPoolBShares;
    uint256 initialStrategyAum;
    uint256 initialTotalShares;
    uint256 secondPoolAAssets;
    uint256 secondPoolAExitAssets;
    uint256 secondPoolALoss;
    uint256 secondPoolAShares;
    uint256 secondPoolBAssets;
    uint256 secondPoolBExitValue;
    uint256 secondPoolBLoss;
    uint256 secondRemainingAum;
    uint256 secondStrategyAum;
    uint256 secondTotalShares;
    uint256 thirdPoolAAssets;
    uint256 thirdPoolALoss;
    uint256 thirdPoolAShares;
    uint256 thirdPoolBAssets;
    uint256 thirdPoolBExitAssets;
    uint256 thirdPoolBLoss;
    uint256 thirdRemainingAum;
    uint256 thirdStrategyAum;
    uint256 thirdTotalShares;

    function testFork_removeImpairment_transfersValueBetweenPools() external {
        /**********************************************************************************************************************************/
        /*** Fund two Pools into one Aave strategy and impair both positions                                                            ***/
        /**********************************************************************************************************************************/

        poolA        = address(pool);
        poolManagerA = address(poolManager);

        (poolB, poolManagerB) = _createPoolSharingStrategy("poolBDelegate", aaveV3StrategyManager);

        openPool(poolManagerA);
        openPool(poolManagerB);

        deposit(poolA, poolALp, poolAFunding);
        deposit(poolB, poolBLp, poolBFunding);

        // Pool A loses two rounding units on the initial supply.
        initialPoolAShares = poolAFunding - 2 * rounding; // 600_000e6 - 2
        initialPoolBShares = poolBFunding; // 400_000e6
        initialTotalShares = initialPoolAShares + initialPoolBShares; // 1_000_000e6 - 2
        initialStrategyAum = initialTotalShares; // 1_000_000e6 - 2
        initialPoolALoss   = divRoundUp(initialPoolAShares * impairmentAmount, initialTotalShares); // 120_000e6
        initialPoolBLoss   = divRoundUp(initialPoolBShares * impairmentAmount, initialTotalShares); // 80_000e6 + 1

        fundStrategyManager(poolManagerA, aaveV3StrategyManager, poolAFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialPoolAShares,
            totalSupply:        poolAFunding,
            unrealizedLosses:   initialPoolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        initialPoolBShares,
            totalSupply:        poolBFunding,
            unrealizedLosses:   initialPoolBLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), initialPoolAShares - initialPoolALoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), initialPoolBShares - initialPoolBLoss);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     initialStrategyAum,
            aTokenBalance:           initialStrategyAum,
            lastRecordedTotalAssets: initialStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialStrategyAum,
            availableToWithdraw:   initialStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           initialPoolAShares,
            shares:           initialPoolAShares,
            pendingShares:    0,
            unrealizedLosses: initialPoolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           initialPoolBShares,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: initialPoolBLoss
        });

        /**********************************************************************************************************************************/
        /*** Fully exit Pool A while impaired and leave Pool B as the sole remaining shareholder                                        ***/
        /**********************************************************************************************************************************/

        firstPoolAExitAssets = initialPoolAShares * (initialStrategyAum - impairmentAmount) / initialTotalShares; // 480_000e6 - 2
        firstRemainingAum    = initialStrategyAum - firstPoolAExitAssets - rounding; // 520_000e6 - 1
        firstPoolBExitValue  = firstRemainingAum - impairmentAmount; // 320_000e6 - 1

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, initialPoolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, initialPoolAShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        firstPoolAExitAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        firstRemainingAum,
            totalSupply:        poolBFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             firstPoolAExitAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             firstPoolBExitValue);
        assertEq(fundsAsset.balanceOf(poolA),                                firstPoolAExitAssets);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstRemainingAum,
            aTokenBalance:           firstRemainingAum,
            lastRecordedTotalAssets: firstRemainingAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialPoolBShares,
            totalPendingShares:    0,
            assetsUnderManagement: firstRemainingAum,
            availableToWithdraw:   firstRemainingAum,
            unrealizedLosses:      impairmentAmount
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
            assets:           firstRemainingAum,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        /**********************************************************************************************************************************/
        /*** Remove the first impairment and prove that only Pool B receives the recovery                                               ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        firstPoolAExitAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        firstRemainingAum,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             firstPoolAExitAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             firstPoolBExitValue + impairmentAmount);
        assertEq(fundsAsset.balanceOf(poolA),                                firstPoolAExitAssets);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstRemainingAum,
            aTokenBalance:           firstRemainingAum,
            lastRecordedTotalAssets: firstRemainingAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialPoolBShares,
            totalPendingShares:    0,
            assetsUnderManagement: firstRemainingAum,
            availableToWithdraw:   firstRemainingAum,
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
            assets:           firstRemainingAum,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Re-fund Pool A at Pool B's recovered share price and impair both positions again                                          ***/
        /**********************************************************************************************************************************/

        secondStrategyAum = firstRemainingAum + firstPoolAExitAssets; // 1_000_000e6 - 3
        secondPoolAShares = firstPoolAExitAssets * initialPoolBShares / firstRemainingAum; // 369_230e6 + 769_229
        secondTotalShares = initialPoolBShares + secondPoolAShares; // 769_230e6 + 769_229
        secondPoolAAssets = secondPoolAShares * secondStrategyAum / secondTotalShares; // 480_000e6 - 3
        secondPoolBAssets = initialPoolBShares * secondStrategyAum / secondTotalShares; // 520_000e6 - 1
        secondPoolALoss   = divRoundUp(secondPoolAShares * impairmentAmount, secondTotalShares); // 96_000e6
        secondPoolBLoss   = divRoundUp(initialPoolBShares * impairmentAmount, secondTotalShares); // 104_000e6 + 1

        fundStrategyManager(poolManagerA, aaveV3StrategyManager, firstPoolAExitAssets);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        secondPoolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   secondPoolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        secondPoolBAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   secondPoolBLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             secondPoolAAssets - secondPoolALoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             secondPoolBAssets - secondPoolBLoss);
        assertEq(fundsAsset.balanceOf(poolA),                                0);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     secondStrategyAum,
            aTokenBalance:           secondStrategyAum,
            lastRecordedTotalAssets: secondStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           secondTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: secondStrategyAum,
            availableToWithdraw:   secondStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           secondPoolAAssets,
            shares:           secondPoolAShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           secondPoolBAssets,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolBLoss
        });

        /**********************************************************************************************************************************/
        /*** Exit Pool A a second time and compound the transfer into Pool B                                                            ***/
        /**********************************************************************************************************************************/

        secondPoolAExitAssets = secondPoolAShares * (secondStrategyAum - impairmentAmount) / secondTotalShares; // 384_000e6 - 3
        secondRemainingAum    = secondStrategyAum - secondPoolAExitAssets; // 616_000e6
        secondPoolBExitValue  = secondRemainingAum - impairmentAmount; // 416_000e6

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, secondPoolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, secondPoolAShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        secondPoolAExitAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: secondPoolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        secondRemainingAum,
            totalSupply:        poolBFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             secondPoolAExitAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             secondPoolBExitValue);
        assertEq(fundsAsset.balanceOf(poolA),                                secondPoolAExitAssets);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     secondRemainingAum,
            aTokenBalance:           secondRemainingAum,
            lastRecordedTotalAssets: secondRemainingAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialPoolBShares,
            totalPendingShares:    0,
            assetsUnderManagement: secondRemainingAum,
            availableToWithdraw:   secondRemainingAum,
            unrealizedLosses:      impairmentAmount
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
            assets:           secondRemainingAum,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        /**********************************************************************************************************************************/
        /*** Remove the second impairment and prove that repeating the cycle steals more than one recovery from Pool A                  ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        secondPoolAExitAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: secondPoolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        secondRemainingAum,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             secondPoolAExitAssets);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             secondPoolBExitValue + impairmentAmount);
        assertEq(fundsAsset.balanceOf(poolA),                                secondPoolAExitAssets);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     secondRemainingAum,
            aTokenBalance:           secondRemainingAum,
            lastRecordedTotalAssets: secondRemainingAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialPoolBShares,
            totalPendingShares:    0,
            assetsUnderManagement: secondRemainingAum,
            availableToWithdraw:   secondRemainingAum,
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
            assets:           secondRemainingAum,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertGt(poolAFunding - secondPoolAExitAssets, impairmentAmount);
        assertGt(secondRemainingAum - poolBFunding, impairmentAmount);

        assertEq(secondPoolAExitAssets + secondRemainingAum, secondStrategyAum);

        /**********************************************************************************************************************************/
        /*** Re-fund Pool A again, then reverse the exit order to direct the next recovery back into Pool A                             ***/
        /**********************************************************************************************************************************/

        thirdStrategyAum = secondRemainingAum + secondPoolAExitAssets - rounding; // 1_000_000e6 - 4
        thirdPoolAShares = (secondPoolAExitAssets - rounding) * initialPoolBShares / secondRemainingAum; // 249_350e6 + 649_348
        thirdTotalShares = initialPoolBShares + thirdPoolAShares; // 649_350e6 + 649_348
        thirdPoolAAssets = thirdPoolAShares * thirdStrategyAum / thirdTotalShares; // 384_000e6 - 5
        thirdPoolBAssets = initialPoolBShares * thirdStrategyAum / thirdTotalShares; // 616_000e6
        thirdPoolALoss   = divRoundUp(thirdPoolAShares * impairmentAmount, thirdTotalShares); // 76_800e6
        thirdPoolBLoss   = divRoundUp(initialPoolBShares * impairmentAmount, thirdTotalShares); // 123_200e6 + 1

        fundStrategyManager(poolManagerA, aaveV3StrategyManager, secondPoolAExitAssets);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        thirdPoolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   thirdPoolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        thirdPoolBAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   thirdPoolBLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             thirdPoolAAssets - thirdPoolALoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             thirdPoolBAssets - thirdPoolBLoss);
        assertEq(fundsAsset.balanceOf(poolA),                                0);
        assertEq(fundsAsset.balanceOf(poolB),                                0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     thirdStrategyAum,
            aTokenBalance:           thirdStrategyAum,
            lastRecordedTotalAssets: thirdStrategyAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           thirdTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: thirdStrategyAum,
            availableToWithdraw:   thirdStrategyAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           thirdPoolAAssets,
            shares:           thirdPoolAShares,
            pendingShares:    0,
            unrealizedLosses: thirdPoolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           thirdPoolBAssets,
            shares:           initialPoolBShares,
            pendingShares:    0,
            unrealizedLosses: thirdPoolBLoss
        });

        /**********************************************************************************************************************************/
        /*** Exit Pool B and remove the impairment so only Pool A receives the reversed recovery                                        ***/
        /**********************************************************************************************************************************/

        thirdPoolBExitAssets = initialPoolBShares * (thirdStrategyAum - impairmentAmount) / thirdTotalShares; // 492_800e6 - 1
        thirdRemainingAum    = thirdStrategyAum - thirdPoolBExitAssets - rounding; // 507_200e6 - 4

        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, initialPoolBShares);
        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, initialPoolBShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        thirdRemainingAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        thirdPoolBExitAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: thirdPoolBExitAssets
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             thirdRemainingAum - impairmentAmount);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             thirdPoolBExitAssets);
        assertEq(fundsAsset.balanceOf(poolA),                                0);
        assertEq(fundsAsset.balanceOf(poolB),                                thirdPoolBExitAssets);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     thirdRemainingAum,
            aTokenBalance:           thirdRemainingAum,
            lastRecordedTotalAssets: thirdRemainingAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           thirdPoolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: thirdRemainingAum,
            availableToWithdraw:   thirdRemainingAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           thirdRemainingAum,
            shares:           thirdPoolAShares,
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

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        thirdRemainingAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        thirdPoolBExitAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: thirdPoolBExitAssets
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding),             thirdRemainingAum);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding),             thirdPoolBExitAssets);
        assertEq(fundsAsset.balanceOf(poolA),                                0);
        assertEq(fundsAsset.balanceOf(poolB),                                thirdPoolBExitAssets);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     thirdRemainingAum,
            aTokenBalance:           thirdRemainingAum,
            lastRecordedTotalAssets: thirdRemainingAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           thirdPoolAShares,
            totalPendingShares:    0,
            assetsUnderManagement: thirdRemainingAum,
            availableToWithdraw:   thirdRemainingAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           thirdRemainingAum,
            shares:           thirdPoolAShares,
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
        /*** Exit Pool A, redeem both LPs and reconcile every asset                                                                     ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, thirdPoolAShares);
        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, thirdPoolAShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        thirdRemainingAum,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: thirdRemainingAum
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        thirdPoolBExitAssets,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: thirdPoolBExitAssets
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

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),             0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy),      0);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        requestRedeem(poolA, poolALp, poolAFunding);
        processRedemptions(poolA, poolAFunding);

        requestRedeem(poolB, poolBLp, poolBFunding);
        processRedemptions(poolB, poolBFunding);

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

        assertEq(fundsAsset.balanceOf(poolALp), thirdRemainingAum);
        assertEq(fundsAsset.balanceOf(poolBLp), thirdPoolBExitAssets);

        uint256 totalRoundingLoss = 5 * rounding; // Three supply units and two withdrawal units.

        uint256 poolAValueTransferred = poolAFunding - thirdRemainingAum; // 92_800e6 + 4
        uint256 poolBValueReceived    = thirdPoolBExitAssets - poolBFunding; // 92_800e6 - 1

        // All funded principal is returned except for the units lost to rounding.
        assertEq(thirdRemainingAum + thirdPoolBExitAssets, poolAFunding + poolBFunding - totalRoundingLoss);

        // Pool A funds Pool B's gain, with the remainder lost to rounding.
        assertEq(poolAValueTransferred, poolBValueReceived + totalRoundingLoss);

        assertGt(thirdRemainingAum, secondPoolAExitAssets);
        assertLt(thirdPoolBExitAssets, secondRemainingAum);
    }

}
