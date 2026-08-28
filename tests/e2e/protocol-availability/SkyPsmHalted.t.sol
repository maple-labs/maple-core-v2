// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    IPSMLike,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

contract SkyPsmHaltedTests is SkyStrategyTestBase {

    uint256 fallbackTout       = 0.01e18;          // 1% fallback PSM exit fee.
    uint256 fundAmount         = 515_100e6 + 1;    // +1 offsets sUSDS rounding under both fallback valuations.
    uint256 lpWithdrawalShares = 100_000e6 + 1;    // +1 offsets Pool share-price rounding.
    uint256 newFallbackTout    = 0.02e18;          // 2% fallback PSM exit fee.
    uint256 poolLiquidity      = 1_000_000e6 + 1;  // +1 keeps remaining Pool cash and shares round.
    uint256 roundingLoss       = 1;                // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.

    function setUp() public override {
        super.setUp();

        openPool(address(poolManager));
        deposit(lp, poolLiquidity);
    }

    function test_skyPsmHalted_preservesAumAndPoolCashWithdrawals() external {
        /**********************************************************************************************************************************/
        /*** Fund Sky and set the fallback exit fee while the live PSM exit fee remains active                                          ***/
        /**********************************************************************************************************************************/

        uint256 fundedAum    = fundAmount - roundingLoss;   // 515_100e6.
        uint256 fundedShares = fundAmount - roundingLoss;   // 515_100e6.
        uint256 poolCash     = poolLiquidity - fundAmount;  // 484_900e6.
        uint256 poolShares   = poolLiquidity;               // 1_000_000e6 + 1.

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 savingsUsdsShares = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(),                     0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), 0);

        assertEq(IStrategyManager(skyStrategyManager).assetsUnderManagement(), fundedAum);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).assetsUnderManagement(),  fundedAum);

        setFallbackTout(skyUnderlyingStrategy, fallbackTout);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(),                     0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), fallbackTout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - roundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolCash
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: fundedAum,
            availableToWithdraw:   fundedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertGt(savingsUsdsShares, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolCash);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(lp),                    0);

        /**********************************************************************************************************************************/
        /*** Halt the PSM and value Sky with the fallback while making the strategy unavailable for withdrawal                          ***/
        /**********************************************************************************************************************************/

        uint256 haltedAum = fundAmount * 1e18 / (1e18 + fallbackTout);  // 510_000e6.

        setSkyTout(type(uint256).max);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(),                     type(uint256).max);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), fallbackTout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolCash + haltedAum,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolCash
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              haltedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: haltedAum,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           haltedAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), 0);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolCash);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(lp),                    0);

        /**********************************************************************************************************************************/
        /*** Change the fallback exit fee and update accounting without moving assets                                                   ***/
        /**********************************************************************************************************************************/

        uint256 updatedHaltedAum = fundAmount * 1e18 / (1e18 + newFallbackTout);  // 505_000e6.

        setFallbackTout(skyUnderlyingStrategy, newFallbackTout);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(),                     type(uint256).max);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), newFallbackTout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolCash + updatedHaltedAum,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolCash
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              updatedHaltedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: updatedHaltedAum,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           updatedHaltedAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), 0);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolCash);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(lp),                    0);

        /**********************************************************************************************************************************/
        /*** Withdraw an LP using Pool cash while the halted Sky position remains unavailable                                           ***/
        /**********************************************************************************************************************************/

        uint256 lpWithdrawalAssets  = lpWithdrawalShares * (poolCash + updatedHaltedAum) / poolShares;  // 98_990e6.
        uint256 remainingPoolCash   = poolCash - lpWithdrawalAssets;                                    // 385_910e6.
        uint256 remainingPoolShares = poolShares - lpWithdrawalShares;                                  // 900_000e6.

        assertEq(pool.balanceOf(lp),               poolShares);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        requestRedeem(address(pool), lp, lpWithdrawalShares);

        assertEq(pool.balanceOf(lp),               remainingPoolShares);
        assertEq(pool.balanceOf(address(queueWM)), lpWithdrawalShares);

        processRedemptions(address(pool), lpWithdrawalShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        remainingPoolCash + updatedHaltedAum,
            totalSupply:        remainingPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: remainingPoolCash
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              updatedHaltedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: updatedHaltedAum,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           updatedHaltedAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(pool.balanceOf(lp),               remainingPoolShares);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares);

        assertEq(fundsAsset.balanceOf(address(pool)),         remainingPoolCash);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(lp),                    lpWithdrawalAssets);

        /**********************************************************************************************************************************/
        /*** Restore the PSM and use its live exit fee instead of the retained fallback                                                 ***/
        /**********************************************************************************************************************************/

        setSkyTout(0);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(),                     0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), newFallbackTout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        remainingPoolCash + fundedAum,
            totalSupply:        remainingPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: remainingPoolCash
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedShares,
            totalPendingShares:    0,
            assetsUnderManagement: fundedAum,
            availableToWithdraw:   fundedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAum,
            shares:           fundedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), fundedAum);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares);

        assertEq(fundsAsset.balanceOf(address(pool)),         remainingPoolCash);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(lp),                    lpWithdrawalAssets);
    }

}
