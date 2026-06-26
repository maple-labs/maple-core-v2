// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

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

        assertEq(fundsAsset.balanceOf(tradingStrategy),                                   0);
        assertEq(IStrategyManager(tradingStrategyManager).assetsOf(address(poolManager)), 0);

        vm.prank(strategyDelegate);
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), assets, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(tradingStrategy),                                   assets);
        assertEq(IStrategyManager(tradingStrategyManager).assetsOf(address(poolManager)), assets);
    }

}
