// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";

contract BootstrapImpairmentTests is AaveV3StrategyTestBase {

    address bootstrapDelegate = makeAddr("bootstrapDelegate");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 bootstrapMint = 100_000e6;
    uint256 poolAFunding  = 600_000e6;
    uint256 poolBFunding  = 400_000e6;
    uint256 poolLiquidity = 1_000_000e6;
    uint256 roundingError = 1;

    uint256 bootstrapAssets;
    uint256 bootstrapLosses;
    uint256 bootstrapShares;
    uint256 impairmentAmount;
    uint256 poolAAssets;
    uint256 poolAExitAssets;
    uint256 poolALosses;
    uint256 poolAStrategyShares;
    uint256 poolBAssets;
    uint256 poolBExitAssets;
    uint256 poolBLosses;
    uint256 poolBStrategyShares;
    uint256 residualAssets;
    uint256 totalStrategyAssets;
    uint256 totalStrategyShares;

    function testFork_processRedemption_fullImpairmentWithBootstrapShares() external {
        /**********************************************************************************************************************************/
        /*** Deploy a bootstrap-funded strategy shared by two Pools                                                                     ***/
        /**********************************************************************************************************************************/

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            bootstrapDelegate,
            aaveToken_:                   aaveToken,
            useVirtualUnderlyingBalance_: useVirtualUnderlyingBalance,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        type(uint256).max,
            bootstrapMint_:               bootstrapMint
        });

        ( poolA, poolManagerA ) = _createPoolSharingStrategy("poolADelegate", aaveV3StrategyManager);
        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", aaveV3StrategyManager);

        deposit(poolA,  lp, poolLiquidity);
        deposit(poolB, lp, poolLiquidity);

        fundStrategyManager(poolManagerA,  aaveV3StrategyManager, poolAFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);

        bootstrapShares     = bootstrapMint - roundingError;                               // 100_000e6 - 1
        poolAStrategyShares = poolAFunding - roundingError;                                // 600_000e6 - 1
        poolBStrategyShares = poolBFunding;                                                // 400_000e6
        totalStrategyAssets = bootstrapShares + poolAStrategyShares + poolBStrategyShares; // 1_100_000e6 - 2
        totalStrategyShares = totalStrategyAssets;                                         // 1_100_000e6 - 2

        bootstrapAssets = bootstrapShares;      // 100_000e6 - 1
        bootstrapLosses = bootstrapAssets;      // 100_000e6 - 1
        poolAAssets     = poolAStrategyShares;  // 600_000e6 - 1
        poolALosses     = poolAAssets;          // 600_000e6 - 1
        poolBAssets     = poolBStrategyShares;  // 400_000e6
        poolBLosses     = poolBAssets;          // 400_000e6

        /**********************************************************************************************************************************/
        /*** Fully impair the strategy and request every Pool-owned share                                                               ***/
        /**********************************************************************************************************************************/

        impairStrategy(aaveV3UnderlyingStrategy, totalStrategyAssets);

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAStrategyShares);
        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   poolALosses,
            availableLiquidity: poolLiquidity - poolAFunding
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   poolBLosses,
            availableLiquidity: poolLiquidity - poolBFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalStrategyAssets,
            aTokenBalance:           totalStrategyAssets,
            lastRecordedTotalAssets: totalStrategyAssets,
            unrealizedLosses:        totalStrategyAssets
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    poolAStrategyShares + poolBStrategyShares,
            assetsUnderManagement: totalStrategyAssets,
            availableToWithdraw:   totalStrategyAssets,
            unrealizedLosses:      totalStrategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAStrategyShares,
            pendingShares:    poolAStrategyShares,
            unrealizedLosses: poolALosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBStrategyShares,
            pendingShares:    poolBStrategyShares,
            unrealizedLosses: poolBLosses
        });

        /**********************************************************************************************************************************/
        /*** Confirm zero-asset processing cannot burn the first Pool's shares or clear either request                                  ***/
        /**********************************************************************************************************************************/

        vm.prank(bootstrapDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).processRedemption(poolManagerA, poolAStrategyShares, "");

        /**********************************************************************************************************************************/
        /*** Confirm zero-asset processing cannot burn the second Pool's shares or clear either request                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(bootstrapDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).processRedemption(poolManagerB, poolBStrategyShares, "");

        /**********************************************************************************************************************************/
        /*** Remove the impairment and show how the restored value is divided before processing the requests                            ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, totalStrategyAssets);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolAFunding
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolBFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalStrategyAssets,
            aTokenBalance:           totalStrategyAssets,
            lastRecordedTotalAssets: totalStrategyAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    poolAStrategyShares + poolBStrategyShares,
            assetsUnderManagement: totalStrategyAssets,
            availableToWithdraw:   totalStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAStrategyShares,
            pendingShares:    poolAStrategyShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBStrategyShares,
            pendingShares:    poolBStrategyShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process both preserved requests and leave only the bootstrap shares                                                        ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAStrategyShares);

        assertEq(fundsAsset.balanceOf(poolA), poolLiquidity - poolAFunding + poolAAssets);

        poolBExitAssets = poolBFunding - roundingError;  // 400_000e6 - 1

        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBStrategyShares);

        assertEq(fundsAsset.balanceOf(poolB), poolLiquidity - poolBFunding + poolBExitAssets);

        residualAssets = bootstrapMint - 2 * roundingError;  // 100_000e6 - 2

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolAFunding + poolAAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBExitAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolBFunding + poolBExitAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     residualAssets,
            aTokenBalance:           residualAssets,
            lastRecordedTotalAssets: residualAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           bootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: residualAssets,
            availableToWithdraw:   residualAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           residualAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
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

        assertEq(IStrategyManager(aaveV3StrategyManager).assetsOf(address(0)), residualAssets);
    }

    function testFork_processRedemption_partialImpairmentWithBootstrapShares() external {
        /**********************************************************************************************************************************/
        /*** Deploy a bootstrap-funded strategy shared by two Pools                                                                     ***/
        /**********************************************************************************************************************************/

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            bootstrapDelegate,
            aaveToken_:                   aaveToken,
            useVirtualUnderlyingBalance_: useVirtualUnderlyingBalance,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        type(uint256).max,
            bootstrapMint_:               bootstrapMint
        });

        ( poolA, poolManagerA ) = _createPoolSharingStrategy("poolADelegate", aaveV3StrategyManager);
        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", aaveV3StrategyManager);

        deposit(poolA,  lp, poolLiquidity);
        deposit(poolB, lp, poolLiquidity);

        fundStrategyManager(poolManagerA,  aaveV3StrategyManager, poolAFunding);
        fundStrategyManager(poolManagerB, aaveV3StrategyManager, poolBFunding);

        bootstrapShares     = bootstrapMint - roundingError;                               // 100_000e6 - 1
        poolAStrategyShares = poolAFunding - roundingError;                                // 600_000e6 - 1
        poolBStrategyShares = poolBFunding;                                                // 400_000e6
        totalStrategyAssets = bootstrapShares + poolAStrategyShares + poolBStrategyShares; // 1_100_000e6 - 2
        totalStrategyShares = totalStrategyAssets;                                         // 1_100_000e6 - 2
        impairmentAmount    = totalStrategyAssets / 4;                                     // 275_000e6 - 1

        bootstrapAssets = bootstrapShares;      // 100_000e6 - 1
        bootstrapLosses = 25_000e6;             // 25_000e6
        poolAAssets     = poolAStrategyShares;  // 600_000e6 - 1
        poolALosses     = 150_000e6;            // 150_000e6
        poolBAssets     = poolBStrategyShares;  // 400_000e6
        poolBLosses     = 100_000e6;            // 100_000e6

        /**********************************************************************************************************************************/
        /*** Partially impair the strategy and process every Pool-owned share                                                           ***/
        /**********************************************************************************************************************************/

        impairStrategy(aaveV3UnderlyingStrategy, impairmentAmount);

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAStrategyShares);
        requestRedeemFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   poolALosses,
            availableLiquidity: poolLiquidity - poolAFunding
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   poolBLosses,
            availableLiquidity: poolLiquidity - poolBFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalStrategyAssets,
            aTokenBalance:           totalStrategyAssets,
            lastRecordedTotalAssets: totalStrategyAssets,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    poolAStrategyShares + poolBStrategyShares,
            assetsUnderManagement: totalStrategyAssets,
            availableToWithdraw:   totalStrategyAssets,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssets,
            shares:           poolAStrategyShares,
            pendingShares:    poolAStrategyShares,
            unrealizedLosses: poolALosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssets,
            shares:           poolBStrategyShares,
            pendingShares:    poolBStrategyShares,
            unrealizedLosses: poolBLosses
        });

        poolAExitAssets = 450_000e6 - roundingError;  // 450_000e6 - 1

        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, poolAStrategyShares);

        assertEq(fundsAsset.balanceOf(poolA), poolLiquidity - poolAFunding + poolAExitAssets);

        poolBExitAssets = 300_000e6 - roundingError;  // 300_000e6 - 1

        processRedemptionFromStrategyManager(poolManagerB, aaveV3StrategyManager, poolBStrategyShares);

        assertEq(fundsAsset.balanceOf(poolB), poolLiquidity - poolBFunding + poolBExitAssets);

        /**********************************************************************************************************************************/
        /*** Confirm only bootstrap shares remain and own the residual impaired value                                                   ***/
        /**********************************************************************************************************************************/

        residualAssets = 350_000e6 - 2 * roundingError;  // 350_000e6 - 2

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAExitAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolAFunding + poolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBExitAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolBFunding + poolBExitAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     residualAssets,
            aTokenBalance:           residualAssets,
            lastRecordedTotalAssets: residualAssets,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           bootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: residualAssets,
            availableToWithdraw:   residualAssets,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           residualAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
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

        assertEq(IStrategyManager(aaveV3StrategyManager).convertToExitAssets(bootstrapShares), residualAssets - impairmentAmount);

        /**********************************************************************************************************************************/
        /*** Remove the impairment and confirm the restored value remains locked in the bootstrap shares                                ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolLiquidity - poolAFunding + poolAExitAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolAFunding + poolAExitAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolLiquidity - poolBFunding + poolBExitAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - poolBFunding + poolBExitAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     residualAssets,
            aTokenBalance:           residualAssets,
            lastRecordedTotalAssets: residualAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           bootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: residualAssets,
            availableToWithdraw:   residualAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           residualAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
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

        assertEq(IStrategyManager(aaveV3StrategyManager).convertToExitAssets(bootstrapShares), residualAssets);

        assertEq(fundsAsset.balanceOf(poolA), poolLiquidity - poolAFunding + poolAExitAssets);
        assertEq(fundsAsset.balanceOf(poolB), poolLiquidity - poolBFunding + poolBExitAssets);
    }

}
