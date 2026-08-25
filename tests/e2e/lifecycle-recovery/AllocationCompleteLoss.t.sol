// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract AllocationStrategyCompleteLossTests is AllocationStrategyTestBase {

    uint256 newFunding      = 100_000e6;
    uint256 poolLiquidity   = 1_000_000e6;
    uint256 strategyFunding = 400_000e6;

    function test_recognizeLoss_completeLossMakesStrategyManagerUnusable() external {
        uint256 remainingPoolLiquidity = poolLiquidity - strategyFunding;  // 600_000e6
        uint256 strategyShares         = strategyFunding;                  // 400_000e6

        /**********************************************************************************************************************************/
        /*** Fully fund the Allocation strategy deployment while retaining liquidity in the Pool                                        ***/
        /**********************************************************************************************************************************/

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, strategyFunding);
        deployAssets(allocationUnderlyingStrategy, managedWallet, strategyFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: remainingPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   strategyFunding,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), strategyFunding);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                strategyFunding);

        /**********************************************************************************************************************************/
        /*** Recognize the complete loss and leave the Strategy Manager with zero AUM and non-zero shares                               ***/
        /**********************************************************************************************************************************/

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, strategyFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        remainingPoolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: remainingPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                strategyFunding);

        /**********************************************************************************************************************************/
        /*** Confirm new funding reverts when non-zero shares are converted against zero AUM                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert(divisionError);
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), newFunding, "");

        /**********************************************************************************************************************************/
        /*** Request every existing share and confirm no assets can be redeemed                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, strategyShares);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(strategyShares), 0);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    strategyShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    strategyShares,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), strategyShares, "");
    }

}
