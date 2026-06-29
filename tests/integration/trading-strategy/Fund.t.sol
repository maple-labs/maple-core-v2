// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyFundTests is TradingStrategyTestBase {

    function test_fund_success() external {
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
            strategyManager:  tradingStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), tradingStrategyManager, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            strategyManager:  tradingStrategyManager,
            aum:              assets,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           assets,
            shares:           assets,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
