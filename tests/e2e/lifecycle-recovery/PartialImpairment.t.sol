// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";

contract PartialImpairmentTests is AaveV3StrategyTestBase {

    address laterLp = makeAddr("laterLp");

    uint256 depositAmount       = 1_000_000e6;
    uint256 impairmentAmount    = 200_000e6;
    uint256 roundingError       = 1;
    uint256 secondDepositAmount = 100_000e6;

    uint256 assets;
    uint256 initialNetAssets;
    uint256 initialStrategyShares;
    uint256 sharesToRedeem;

    uint256 remainingLosses;
    uint256 remainingShares;

    uint256 exitAssets;
    uint256 fullResidualAssets;
    uint256 lpShares;
    uint256 partialResidualAssets;
    uint256 poolNetAssets;
    uint256 poolShares;

    function testFork_processRedemption_partialImpairmentE2E() external {
        /**********************************************************************************************************************************/
        /*** Fund and impair the strategy, then snapshot the initial state                                                              ***/
        /**********************************************************************************************************************************/

        openPool(address(poolManager));

        poolShares = deposit(lp, depositAmount); // 1_000_000e6

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, depositAmount);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        initialStrategyShares = depositAmount - roundingError; // 1_000_000e6 - 1
        initialNetAssets      = initialStrategyShares - impairmentAmount; // 800_000e6 - 1
        partialResidualAssets = impairmentAmount - roundingError; // 200_000e6 - 1
        fullResidualAssets    = impairmentAmount; // 200_000e6
        assets                = initialStrategyShares; // 1_000_000e6 - 1

        uint256 snapshot = vm.snapshotState();

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialStrategyShares,
            totalSupply:        poolShares,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     initialStrategyShares,
            aTokenBalance:           initialStrategyShares,
            lastRecordedTotalAssets: initialStrategyShares,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialStrategyShares,
            availableToWithdraw:   initialStrategyShares,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           initialStrategyShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        /**********************************************************************************************************************************/
        /*** Process the first strategy tranche and withdraw the matching Pool shares                                                   ***/
        /**********************************************************************************************************************************/

        sharesToRedeem  = initialStrategyShares / 4; // 250_000e6 - 1
        lpShares        = poolShares * sharesToRedeem / initialStrategyShares; // 250_000e6 - 1
        remainingShares = initialStrategyShares - sharesToRedeem; // 750_000e6
        poolNetAssets   = initialNetAssets; // 800_000e6 - 1
        exitAssets      = lpShares * poolNetAssets / poolShares; // 200_000e6 - 2
        remainingLosses = impairmentAmount; // 200_000e6

        assets -= sharesToRedeem * (assets - remainingLosses) / initialStrategyShares; // 800_000e6

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     assets,
            aTokenBalance:           assets,
            lastRecordedTotalAssets: assets,
            unrealizedLosses:        remainingLosses
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: remainingLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolNetAssets + remainingLosses,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingLosses,
            availableLiquidity: poolNetAssets + remainingLosses - assets
        });

        requestRedeem(address(pool), lp, lpShares);
        processRedemptions(address(pool), lpShares);

        poolShares    -= lpShares; // 750_000e6 + 1
        poolNetAssets -= exitAssets; // 600_000e6 + 1

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolNetAssets + remainingLosses,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingLosses,
            availableLiquidity: poolNetAssets + remainingLosses - assets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: remainingLosses
        });

        assertEq(fundsAsset.balanceOf(lp), initialNetAssets - poolNetAssets);

        /**********************************************************************************************************************************/
        /*** Process the second strategy tranche and withdraw the matching Pool shares                                                  ***/
        /**********************************************************************************************************************************/

        sharesToRedeem = initialStrategyShares / 4; // 250_000e6 - 1
        lpShares       = poolShares * sharesToRedeem / remainingShares; // 250_000e6 - 1

        assets -= sharesToRedeem * (assets - remainingLosses) / remainingShares; // 600_000e6 + 1

        remainingShares -= sharesToRedeem; // 500_000e6 + 1
        exitAssets       = lpShares * poolNetAssets / poolShares; // 200_000e6 - 1

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     assets,
            aTokenBalance:           assets,
            lastRecordedTotalAssets: assets,
            unrealizedLosses:        remainingLosses
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: remainingLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolNetAssets + remainingLosses,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingLosses,
            availableLiquidity: poolNetAssets + remainingLosses - assets
        });

        requestRedeem(address(pool), lp, lpShares);
        processRedemptions(address(pool), lpShares);

        poolShares    -= lpShares; // 500_000e6 + 2
        poolNetAssets -= exitAssets; // 400_000e6 + 2

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolNetAssets + remainingLosses,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingLosses,
            availableLiquidity: poolNetAssets + remainingLosses - assets
        });

        assertEq(fundsAsset.balanceOf(lp), initialNetAssets - poolNetAssets);

        /**********************************************************************************************************************************/
        /*** Process all remaining strategy shares and withdraw all remaining Pool shares                                               ***/
        /**********************************************************************************************************************************/

        sharesToRedeem = remainingShares; // 500_000e6 + 1
        lpShares       = poolShares; // 500_000e6 + 2
        exitAssets     = poolNetAssets; // 400_000e6 + 2

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     partialResidualAssets,
            aTokenBalance:           partialResidualAssets,
            lastRecordedTotalAssets: partialResidualAssets,
            unrealizedLosses:        partialResidualAssets
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolNetAssets,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolNetAssets
        });

        requestRedeem(address(pool), lp, lpShares);
        processRedemptions(address(pool), lpShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
        assertEq(fundsAsset.balanceOf(lp), initialNetAssets);

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: partialResidualAssets,
            availableToWithdraw:   partialResidualAssets,
            unrealizedLosses:      partialResidualAssets
        });

        /**********************************************************************************************************************************/
        /*** Revert to the impaired snapshot and process a full redemption                                                              ***/
        /**********************************************************************************************************************************/

        vm.revertToState(snapshot);

        sharesToRedeem = initialStrategyShares; // 1_000_000e6 - 1

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, sharesToRedeem);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fullResidualAssets,
            aTokenBalance:           fullResidualAssets,
            lastRecordedTotalAssets: fullResidualAssets,
            unrealizedLosses:        fullResidualAssets
        });

        exitAssets = initialNetAssets; // 800_000e6 - 1
        lpShares   = poolShares; // 1_000_000e6

        requestRedeem(address(pool), lp, lpShares);
        processRedemptions(address(pool), lpShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: fullResidualAssets,
            availableToWithdraw:   fullResidualAssets,
            unrealizedLosses:      fullResidualAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(lp), exitAssets);
    }

    function testFork_processRedemption_residualImpairmentCapture() external {
        /**********************************************************************************************************************************/
        /*** Fund and impair Pool A                                                                                                     ***/
        /**********************************************************************************************************************************/

        openPool(address(poolManager));

        poolShares = depositAmount;

        deposit(address(pool), lp, depositAmount);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, depositAmount);
        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        initialStrategyShares = depositAmount - roundingError; // 1_000_000e6 - 1
        initialNetAssets      = initialStrategyShares - impairmentAmount; // 800_000e6 - 1
        fullResidualAssets    = impairmentAmount; // 200_000e6
        assets                = initialStrategyShares; // 1_000_000e6 - 1

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialStrategyShares,
            totalSupply:        poolShares,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     initialStrategyShares,
            aTokenBalance:           initialStrategyShares,
            lastRecordedTotalAssets: initialStrategyShares,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialStrategyShares,
            availableToWithdraw:   initialStrategyShares,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           initialStrategyShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        /**********************************************************************************************************************************/
        /*** Fully exit Pool A and leave the impairment in the zero-share strategy                                                      ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, initialStrategyShares);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, initialStrategyShares);

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialNetAssets,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: initialNetAssets
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairmentAmount,
            availableToWithdraw:   impairmentAmount,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeem(address(pool), lp, poolShares);
        processRedemptions(address(pool), poolShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fullResidualAssets,
            aTokenBalance:           fullResidualAssets,
            lastRecordedTotalAssets: fullResidualAssets,
            unrealizedLosses:        fullResidualAssets
        });

        assertEq(fundsAsset.balanceOf(lp), initialNetAssets);

        /**********************************************************************************************************************************/
        /*** Remove the impairment and let Pool B's depositor capture the residual AUM                                                  ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fullResidualAssets,
            aTokenBalance:           fullResidualAssets,
            lastRecordedTotalAssets: fullResidualAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: fullResidualAssets,
            availableToWithdraw:   fullResidualAssets,
            unrealizedLosses:      0
        });

        _createPoolSharingStrategy("poolBDelegate", aaveV3StrategyManager);
        openPool(address(poolManager));

        deposit(address(pool), laterLp, secondDepositAmount);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, secondDepositAmount);

        initialStrategyShares = secondDepositAmount; // 100_000e6
        assets                = fullResidualAssets + initialStrategyShares; // 300_000e6

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        secondDepositAmount,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     assets,
            aTokenBalance:           assets,
            lastRecordedTotalAssets: assets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           initialStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: assets,
            availableToWithdraw:   assets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           initialStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, initialStrategyShares);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, initialStrategyShares);

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        secondDepositAmount,
            unrealizedLosses:   0,
            availableLiquidity: assets
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

        requestRedeem(address(pool), laterLp, secondDepositAmount);
        processRedemptions(address(pool), secondDepositAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(laterLp), assets);
    }

}
