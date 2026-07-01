// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyFundTests is SkyStrategyTestBase {

    function testFork_fund_success() external {
        uint256 assets               = 1_000e6;
        uint256 expectedRoundingLoss = 1;  // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.

        deposit(lp, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets - expectedRoundingLoss,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              assets - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           assets - expectedRoundingLoss,
            shares:           assets - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
