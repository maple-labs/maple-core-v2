// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyProcessRedemptionTests is SkyStrategyTestBase {

    function testFork_processRedemption_success() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Execute first deposit                                                                                              ***/
        /**********************************************************************************************************************************/

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

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

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

        /**********************************************************************************************************************************/
        /*** Step 3: Request redemption from strategy manager                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 shares = IStrategyManager(skyStrategyManager).sharesOf(address(poolManager));

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

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
            pendingShares:    assets - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets - expectedRoundingLoss,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets - expectedRoundingLoss
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
    }

}
