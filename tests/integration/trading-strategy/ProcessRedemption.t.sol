// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyProcessRedemptionTests is TradingStrategyTestBase {

    function test_processRedemption_success() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Execute first deposit                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 assets = 1_000e6;

        deposit(lp, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             assets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: assets,
            availableToWithdraw:   assets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           assets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), assets);

        /**********************************************************************************************************************************/
        /*** Step 3: Request redemption from strategy manager                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 shares = IStrategyManager(tradingStrategyManager).sharesOf(address(poolManager));

        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: assets,
            availableToWithdraw:   assets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           assets,
            pendingShares:    assets,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), assets);

        /**********************************************************************************************************************************/
        /*** Step 4: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             assets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);
    }

}
