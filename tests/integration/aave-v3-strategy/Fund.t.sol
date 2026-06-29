// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyFundTests is AaveV3StrategyTestBase {

    function testFork_fund_success() external {
        uint256 assets               = 1_000e6;
        uint256 expectedRoundingGain = 1;  // Aave mints 1 wei of interest on supply at the fork block.

        deposit(lp, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets
        });

        assertAaveV3Strategy({
            strategyManager:  aaveV3StrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets + expectedRoundingGain,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:  aaveV3StrategyManager,
            aum:              assets + expectedRoundingGain,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           assets + expectedRoundingGain,
            shares:           assets + expectedRoundingGain,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
