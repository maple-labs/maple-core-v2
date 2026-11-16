// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAllocationStrategy, IERC20, IERC20Like, IERC4626Like } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";
import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";
import { SkyStrategyTestBase } from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

// At the configured fork block, Aave loses one USDC base unit per cycle, leaving the pool ten base units below its initial value.
contract AaveV3StrategyRepeatedFundingAndWithdrawalTests is AaveV3StrategyTestBase {

    uint256 cycleCount    = 10;
    uint256 cycleFunding  = 100_000e6;
    uint256 poolLiquidity = 1_000_000e6;
    uint256 roundingGain  = 0; // At the fork block, Aave gains zero; Spark overrides this with one asset unit.
    uint256 roundingLoss  = 1; // At the fork block, Aave loses one asset unit; Spark overrides this with zero.

    function test_repeatedFundingAndWithdrawal_fullExitEveryCycle() external {
        deposit(lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Fully fund and exit the strategy ten times                                                                                 ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < cycleCount; ++i) {
            uint256 cumulativeGain    = (i + 1) * roundingGain; // Expected Spark gain at the fork block.
            uint256 cumulativeLoss    = (i + 1) * roundingLoss; // Expected Aave loss at the fork block.
            uint256 strategyAssets    = cycleFunding + roundingGain - roundingLoss; // Aave: 100_000e6 - 1; Spark: 100_000e6 + 1.
            uint256 strategyShares    = strategyAssets; // Equal to deployed assets.
            uint256 expectedPoolValue = poolLiquidity + cumulativeGain - cumulativeLoss; // Initial liquidity plus net cumulative rounding.

            fundStrategyManager(address(poolManager), aaveV3StrategyManager, cycleFunding);
            requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, strategyShares);

            assertStrategyManager({
                strategyManager:       aaveV3StrategyManager,
                totalShares:           strategyShares,
                totalPendingShares:    strategyShares,
                assetsUnderManagement: strategyAssets,
                availableToWithdraw:   strategyAssets,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  aaveV3StrategyManager,
                poolManager:      address(poolManager),
                assets:           strategyAssets,
                shares:           strategyShares,
                pendingShares:    strategyShares,
                unrealizedLosses: 0
            });

            processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, strategyShares);

            assertPoolState({
                pool:               address(pool),
                totalAssets:        expectedPoolValue,
                totalSupply:        poolLiquidity,
                unrealizedLosses:   0,
                availableLiquidity: expectedPoolValue
            });

            assertAaveV3Strategy({
                strategyManager:         aaveV3StrategyManager,
                aum:                     0,
                aTokenBalance:           0,
                lastRecordedTotalAssets: 0,
                unrealizedLosses:        0
            });

            assertStrategyManager({
                strategyManager:       aaveV3StrategyManager,
                totalShares:           0,
                totalPendingShares:    0,
                assetsUnderManagement: 0,
                availableToWithdraw:   0,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  aaveV3StrategyManager,
                poolManager:      address(poolManager),
                assets:           0,
                shares:           0,
                pendingShares:    0,
                unrealizedLosses: 0
            });

            assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy), 0);
            assertEq(fundsAsset.balanceOf(aaveV3StrategyManager),    0);
        }
    }

}

// At the configured fork block, Spark gains one USDC base unit per cycle, leaving the pool ten base units above its initial value.
contract SparkLendStrategyRepeatedFundingAndWithdrawalTests is AaveV3StrategyRepeatedFundingAndWithdrawalTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        roundingGain                = 1; // Spark reports one asset unit above this cycle's nominal supply at the fork block.
        roundingLoss                = 0;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

// At the configured fork block, Sky loses one USDC base unit during the first cycle, leaving the pool one base unit lower.
contract SkyStrategyRepeatedFundingAndWithdrawalTests is SkyStrategyTestBase {

    uint256 cycleCount        = 10;
    uint256 cycleFunding      = 100_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 shareRoundingLoss = 1;

    function test_repeatedFundingAndWithdrawal_fullExitEveryCycle() external {
        deposit(lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Fully fund and exit the strategy ten times                                                                                 ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < cycleCount; ++i) {
            uint256 cycleRoundingLoss = i == 0 ? shareRoundingLoss : 0; // One asset unit on the first cycle, zero thereafter.
            uint256 strategyAssets    = cycleFunding - cycleRoundingLoss; // 100_000e6 - 1 on the first cycle, 100_000e6 thereafter.
            uint256 strategyShares    = strategyAssets; // Equal to deployed assets with no existing manager shares.
            uint256 expectedPoolValue = poolLiquidity - shareRoundingLoss; // 1_000_000e6 - 1 after the first cycle.

            fundStrategyManager(address(poolManager), skyStrategyManager, cycleFunding);
            requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, strategyShares);

            assertStrategyManager({
                strategyManager:       skyStrategyManager,
                totalShares:           strategyShares,
                totalPendingShares:    strategyShares,
                assetsUnderManagement: strategyAssets,
                availableToWithdraw:   strategyAssets,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  skyStrategyManager,
                poolManager:      address(poolManager),
                assets:           strategyAssets,
                shares:           strategyShares,
                pendingShares:    strategyShares,
                unrealizedLosses: 0
            });

            processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, strategyShares);

            assertPoolState({
                pool:               address(pool),
                totalAssets:        expectedPoolValue,
                totalSupply:        poolLiquidity,
                unrealizedLosses:   0,
                availableLiquidity: expectedPoolValue
            });

            assertSkyStrategy({
                strategyManager:  skyStrategyManager,
                aum:              0,
                unrealizedLosses: 0
            });

            assertSkyStrategyStorage({
                strategy:                skyUnderlyingStrategy,
                isLossRecognized:        false,
                impairedAssets:          0,
                lastRecordedTotalAssets: 0
            });

            assertStrategyManager({
                strategyManager:       skyStrategyManager,
                totalShares:           0,
                totalPendingShares:    0,
                assetsUnderManagement: 0,
                availableToWithdraw:   0,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  skyStrategyManager,
                poolManager:      address(poolManager),
                assets:           0,
                shares:           0,
                pendingShares:    0,
                unrealizedLosses: 0
            });

            assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
            assertEq(fundsAsset.balanceOf(skyStrategyManager),          0);
            assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

            // Decimal conversion can leave sUSDS dust worth less than one USDC base unit.
            assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
        }
    }

}

// Allocation returns the exact funded amount every cycle, leaving the pool at its initial value.
contract AllocationStrategyRepeatedFundingAndWithdrawalTests is AllocationStrategyTestBase {

    uint256 cycleCount    = 10;
    uint256 cycleFunding  = 100_000e6;
    uint256 poolLiquidity = 1_000_000e6;

    function test_repeatedFundingAndWithdrawal_fullExitEveryCycle() external {
        deposit(lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Fully fund, deploy, return and exit the strategy ten times                                                                 ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < cycleCount; ++i) {
            uint256 strategyAssets = cycleFunding; // 100_000e6.
            uint256 strategyShares = cycleFunding; // 100_000e6.

            fundStrategyManager(address(poolManager), allocationStrategyManager, cycleFunding);
            deployAssets(allocationUnderlyingStrategy, managedWallet, cycleFunding);

            assertAllocationStrategy({
                allocationStrategy:    allocationUnderlyingStrategy,
                assetsUnderManagement: strategyAssets,
                availableToWithdraw:   0,
                recordedAssets:        0,
                totalDeployedAssets:   strategyAssets,
                unrealizedLosses:      0
            });

            assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), strategyAssets);

            assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
            assertEq(fundsAsset.balanceOf(managedWallet),                strategyAssets);

            vm.startPrank(managedWallet);
            fundsAsset.approve(allocationUnderlyingStrategy, cycleFunding);
            IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(cycleFunding, managedWallet, "");
            vm.stopPrank();

            assertAllocationStrategy({
                allocationStrategy:    allocationUnderlyingStrategy,
                assetsUnderManagement: strategyAssets,
                availableToWithdraw:   strategyAssets,
                recordedAssets:        strategyAssets,
                totalDeployedAssets:   0,
                unrealizedLosses:      0
            });

            assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);
            assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy),                                strategyAssets);
            assertEq(fundsAsset.balanceOf(managedWallet),                                               0);

            requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, strategyShares);

            assertStrategyManager({
                strategyManager:       allocationStrategyManager,
                totalShares:           strategyShares,
                totalPendingShares:    strategyShares,
                assetsUnderManagement: strategyAssets,
                availableToWithdraw:   strategyAssets,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  allocationStrategyManager,
                poolManager:      address(poolManager),
                assets:           strategyAssets,
                shares:           strategyShares,
                pendingShares:    strategyShares,
                unrealizedLosses: 0
            });

            processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, strategyShares);

            assertPoolState({
                pool:               address(pool),
                totalAssets:        poolLiquidity,
                totalSupply:        poolLiquidity,
                unrealizedLosses:   0,
                availableLiquidity: poolLiquidity
            });

            assertAllocationStrategy({
                allocationStrategy:    allocationUnderlyingStrategy,
                assetsUnderManagement: 0,
                availableToWithdraw:   0,
                recordedAssets:        0,
                totalDeployedAssets:   0,
                unrealizedLosses:      0
            });

            assertStrategyManager({
                strategyManager:       allocationStrategyManager,
                totalShares:           0,
                totalPendingShares:    0,
                assetsUnderManagement: 0,
                availableToWithdraw:   0,
                unrealizedLosses:      0
            });

            assertStrategyManagerPosition({
                strategyManager:  allocationStrategyManager,
                poolManager:      address(poolManager),
                assets:           0,
                shares:           0,
                pendingShares:    0,
                unrealizedLosses: 0
            });

            assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

            assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
            assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
            assertEq(fundsAsset.balanceOf(managedWallet),                0);
        }
    }

}
