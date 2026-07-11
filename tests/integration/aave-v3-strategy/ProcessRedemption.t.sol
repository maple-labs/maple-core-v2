// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyProcessRedemptionTests is AaveV3StrategyTestBase {

    function testFork_processRedemption_success() external {

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

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

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

        /**********************************************************************************************************************************/
        /*** Step 3: Request redemption from strategy manager                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 shares = IStrategyManager(aaveV3StrategyManager).sharesOf(address(poolManager));

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

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
            pendingShares:    assets + expectedRoundingGain,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assets + expectedRoundingGain,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: assets + expectedRoundingGain
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
    }

}

contract SparkLendStrategyProcessRedemptionTests is AaveV3StrategyProcessRedemptionTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;
        expectedRoundingGain        = 0;

        super.setUp();
    }

}
