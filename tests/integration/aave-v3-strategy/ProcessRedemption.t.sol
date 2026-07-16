// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

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
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
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

        /**********************************************************************************************************************************/
        /*** Step 2: Fund strategy manager                                                                                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);

        uint256 fundedAssets = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        fundedAssets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        fundedAssets,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedAssets,
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
            totalAssets:        fundedAssets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        fundedAssets,
            totalPendingShares: fundedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedAssets,
            pendingShares:    fundedAssets,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Process redemption                                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        fundedAssets,
            totalSupply:        assets,
            unrealizedLosses:   0,
            availableLiquidity: fundedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
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
    }

}

contract SparkLendStrategyProcessRedemptionTests is AaveV3StrategyProcessRedemptionTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}
