// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyCancelYieldTestBase is AllocationStrategyTestBase {

    uint256 delegateFee       = 1_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialShares     = 1_000_000e6;
    uint256 netYield          = 47_500e6;
    uint256 protocolFee       = 1_500e6;
    uint256 yieldAssets       = 50_000e6;

    uint32 delegateFeeRate  = 0.02e6;  // 2%
    uint32 protocolFeeRate  = 0.03e6;  // 3%
    uint32 yieldCooldown    = 1 hours;
    uint32 yieldDuration    = 31 days;

    function setUp() public virtual override {
        super.setUp();

        // Fund pool and strategy, then deploy assets.
        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        // Set strategy fees.
        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);

        // Schedule yield so unrealized yield exists to be cancelled.
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        // Initial assertions.
        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}

contract AllocationStrategyCancelYieldFailureTests is AllocationStrategyCancelYieldTestBase {

    function test_cancelYield_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

    function test_cancelYield_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

    function test_cancelYield_revert_notAuthorized() external {
        address notAdmin = makeAddr("notAdmin");

        vm.prank(notAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

    function test_cancelYield_revert_notAuthorized_managedWallet() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

    function test_cancelYield_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(0, managedWallet);
    }

    function test_cancelYield_revert_zeroAssets_noRemainingYield() external {
        vm.warp(startingTime + yieldDuration);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedYield(), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(type(uint256).max, managedWallet);
    }

    function test_cancelYield_revert_zeroAssets_afterFlush() external {
        vm.warp(startingTime + yieldCooldown);

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedYield(), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(type(uint256).max, managedWallet);
    }

    function test_cancelYield_revert_exceedsUnrealized_boundary() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(netYield + 1, managedWallet);
    }

    function test_cancelYield_revert_exceedsUnrealized_afterPartialRealization() external {
        uint32  elapsedDuration    = 10 days;
        uint256 realizedAtCancel   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedAtCancel = netYield - realizedAtCancel;

        vm.warp(startingTime + elapsedDuration);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedYield(), unrealizedAtCancel);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(unrealizedAtCancel + 1, managedWallet);
    }

    function test_cancelYield_revert_exceedsUnrealized_afterFlush() external {
        vm.warp(startingTime + yieldCooldown);

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedYield(), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

    function test_cancelYield_revert_invalidRecipient_zeroAddress() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:INVALID_RECIPIENT");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, address(0));
    }

    function test_cancelYield_revert_invalidRecipient_notManagedWallet() external {
        address randomRecipient = makeAddr("randomRecipient");

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:INVALID_RECIPIENT");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, randomRecipient);
    }

    function test_cancelYield_revert_invalidRecipient_revokedManagedWallet() external {
        vm.prank(governor);
        globals.setValidMapleManagedWallet(managedWallet, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:INVALID_RECIPIENT");
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(1, managedWallet);
    }

}

// TODO: Add a test where yield is cancelled to another recipient wallet.
// TODO: Add a test where yield is cancelled twice in a row with a warp in between.
// TODO: Add a test where yield is cancelled while two pools have funded the strategy.
contract AllocationStrategyCancelYieldSuccessTests is AllocationStrategyCancelYieldTestBase {

    uint256 cancelledAssets;
    uint256 impairAmount;
    uint256 lossAmount;
    uint256 realizedAtCancel;
    uint256 realizedAtImpair;
    uint256 realizedAtLoss;
    uint256 realizedSinceCancel;
    uint256 remainingYield;
    uint256 rescheduledYield;
    uint256 topUpAssets;
    uint256 topUpDelegateFee;
    uint256 topUpProtocolFee;
    uint256 unrealizedAtCancel;

    uint32 elapsedDuration;
    uint32 newDuration;
    uint32 postCancelElapsed;

    function test_cancelYield_success_partialAmount() external {

        /**********************************************************************************************************************************/
        /*** Warp forward so part of the schedule has vested                                                                            ***/
        /**********************************************************************************************************************************/

        elapsedDuration    = 10 days;
        realizedAtCancel   = netYield * elapsedDuration / yieldDuration;
        unrealizedAtCancel = netYield - realizedAtCancel;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtCancel
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel part of the unrealized yield                                                                                        ***/
        /**********************************************************************************************************************************/

        cancelledAssets = 10_000e6;
        remainingYield  = unrealizedAtCancel - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the remaining (smaller) schedule fully vests by the same deadline                           ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel + remainingYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + remainingYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel + remainingYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + remainingYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        remainingYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_cancelYield_success_fullAmount_explicitAmount() external {

        /**********************************************************************************************************************************/
        /*** Warp forward so part of the schedule has vested                                                                            ***/
        /**********************************************************************************************************************************/

        elapsedDuration    = 8 days;
        realizedAtCancel   = netYield * elapsedDuration / yieldDuration;
        unrealizedAtCancel = netYield - realizedAtCancel;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtCancel
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel the entire remaining unrealized yield using the exact outstanding amount                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(unrealizedAtCancel, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedAtCancel);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedAtCancel);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: nothing further vests since the remaining schedule was fully cancelled                      ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedAtCancel);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedAtCancel);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_cancelYield_success_fullAmount_maxConvention() external {

        /**********************************************************************************************************************************/
        /*** Warp forward so part of the schedule has vested                                                                            ***/
        /**********************************************************************************************************************************/

        elapsedDuration    = 22 days;
        realizedAtCancel   = netYield * elapsedDuration / yieldDuration;
        unrealizedAtCancel = netYield - realizedAtCancel;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtCancel
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel the entire remaining unrealized yield using the type(uint256).max convention                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(type(uint256).max, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedAtCancel);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedAtCancel);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: nothing further vests since the remaining schedule was fully cancelled                      ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedAtCancel);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedAtCancel);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_cancelYield_success_thenRescheduled_lessYield() external {

        /**********************************************************************************************************************************/
        /*** Warp partway through the vesting period, then cancel part of the unrealized yield                                          ***/
        /**********************************************************************************************************************************/

        cancelledAssets  = 10_000e6;
        elapsedDuration  = 10 days;
        realizedAtCancel = netYield * elapsedDuration / yieldDuration;
        remainingYield   = netYield - realizedAtCancel - cancelledAssets;

        vm.warp(startingTime + elapsedDuration);

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp further into the (now shorter) schedule so more yield accrues before the managed wallet tops it back up               ***/
        /**********************************************************************************************************************************/

        postCancelElapsed   = 5 days;
        realizedSinceCancel = remainingYield * postCancelElapsed / (yieldDuration - elapsedDuration);

        vm.warp(startingTime + elapsedDuration + postCancelElapsed);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel + realizedSinceCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel + realizedSinceCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedSinceCancel
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** The managed wallet reschedules over a shorter window, topping up with less than what was cancelled                         ***/
        /**********************************************************************************************************************************/

        newDuration      = 15 days;
        topUpAssets      = 5_000e6;
        topUpDelegateFee = topUpAssets * delegateFeeRate / 1e6;
        topUpProtocolFee = topUpAssets * protocolFeeRate / 1e6;
        rescheduledYield = remainingYield - realizedSinceCancel + topUpAssets - topUpDelegateFee - topUpProtocolFee;

        realizeYield(allocationUnderlyingStrategy, managedWallet, topUpAssets, newDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel + realizedSinceCancel,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel + realizedSinceCancel,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: rescheduledYield,
            yieldStart:           startingTime + elapsedDuration + postCancelElapsed,
            yieldDeadline:        startingTime + elapsedDuration + postCancelElapsed + newDuration,
            yieldLastRealized:    startingTime + elapsedDuration + postCancelElapsed,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield
        );
        assertEq(fundsAsset.balanceOf(managedWallet),    initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee + topUpDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee + topUpProtocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the new deadline and confirm the corrected schedule fully vests                                                    ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + postCancelElapsed + newDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: rescheduledYield,
            yieldStart:           startingTime + elapsedDuration + postCancelElapsed,
            yieldDeadline:        startingTime + elapsedDuration + postCancelElapsed + newDuration,
            yieldLastRealized:    startingTime + elapsedDuration + postCancelElapsed,
            realizedYield:        rescheduledYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield
        );
        assertEq(fundsAsset.balanceOf(managedWallet),    initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee + topUpDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee + topUpProtocolFee);
    }

    function test_cancelYield_success_withExistingImpairment() external {

        /**********************************************************************************************************************************/
        /*** Warp partway through the vesting period, then impair part of the deployed assets                                           ***/
        /**********************************************************************************************************************************/

        impairAmount     = 100_000e6;
        elapsedDuration  = 10 days;
        realizedAtImpair = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        impairAllocationStrategy(allocationUnderlyingStrategy, impairAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtImpair,
            totalSupply:        initialShares,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtImpair,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtImpair,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtImpair,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairAmount
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtImpair
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel yield after the impairment is in place: the two mechanisms are independent                                          ***/
        /**********************************************************************************************************************************/

        unrealizedAtCancel = netYield - realizedAtImpair;
        cancelledAssets    = 12_000e6;
        remainingYield     = unrealizedAtCancel - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtImpair,
            totalSupply:        initialShares,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtImpair,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtImpair,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtImpair,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairAmount
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the remaining (smaller) schedule fully vests, independent of the standing impairment        ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtImpair + remainingYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtImpair + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair + remainingYield,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtImpair + remainingYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtImpair + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtImpair + remainingYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairAmount
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        remainingYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_cancelYield_success_afterLossRecognized() external {

        /**********************************************************************************************************************************/
        /*** Warp partway through the vesting period, then recognize a loss on the deployed assets                                      ***/
        /**********************************************************************************************************************************/

        lossAmount      = 50_000e6;
        elapsedDuration = 15 days;
        realizedAtLoss  = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtLoss - lossAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtLoss - lossAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtLoss
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel yield after the loss is recognized: it only affects the funds side, not the previously recognized loss              ***/
        /**********************************************************************************************************************************/

        unrealizedAtCancel = netYield - realizedAtLoss;
        cancelledAssets    = 11_000e6;
        remainingYield     = unrealizedAtCancel - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtLoss - lossAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtLoss - lossAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the remaining (smaller) schedule fully vests, independent of the recognized loss            ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtLoss - lossAmount + remainingYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss + remainingYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtLoss - lossAmount + remainingYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtLoss - lossAmount + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtLoss + remainingYield,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        remainingYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}
