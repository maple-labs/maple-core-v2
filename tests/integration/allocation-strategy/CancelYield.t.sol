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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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

contract AllocationStrategyCancelYieldSuccessTests is AllocationStrategyCancelYieldTestBase {

    uint256 aumAtCancel;
    uint256 cancelledAssets;
    uint256 cancelledAssets2;
    uint256 expectedShares2;
    uint256 finalAum;
    uint256 impairAmount;
    uint256 initialAssets1;
    uint256 initialAssets2;
    uint256 initialShares1;
    uint256 lossAmount;
    uint256 pool1AssetsAtCancel;
    uint256 pool1FinalAssets;
    uint256 pool2AssetsAtCancel;
    uint256 pool2FinalAssets;
    uint256 realizedAtCancel;
    uint256 realizedAtImpair;
    uint256 realizedAtLoss;
    uint256 realizedSinceCancel;
    uint256 remainingYield;
    uint256 remainingYield2;
    uint256 rescheduledYield;
    uint256 topUpAssets;
    uint256 topUpDelegateFee;
    uint256 topUpProtocolFee;
    uint256 totalPrincipal;
    uint256 totalStrategyShares;
    uint256 unrealizedAtCancel;
    uint256 unrealizedAtCancel2;

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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            availableToWithdraw:   initialAssets - initialDeployment + netYield - cancelledAssets,
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
            availableToWithdraw:   initialAssets - initialDeployment + netYield - cancelledAssets,
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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

        vm.prank(securityAdmin);
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel,
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel,
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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel,
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield,
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
            recordedAssets:        initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + rescheduledYield,
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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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

    function test_cancelYield_success_toAnotherRecipientWallet() external {
        address otherRecipient = makeAddr("otherRecipient");

        vm.prank(governor);
        globals.setValidMapleManagedWallet(otherRecipient, true);

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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
        assertEq(fundsAsset.balanceOf(otherRecipient),               0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel part of the unrealized yield to a wallet other than the one that deployed the assets                                ***/
        /**********************************************************************************************************************************/

        cancelledAssets = 10_000e6;
        remainingYield  = unrealizedAtCancel - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, otherRecipient);

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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(otherRecipient),               cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the remaining (smaller) schedule fully vests into the pool, untouched by the recipient      ***/
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
            availableToWithdraw:   initialAssets - initialDeployment + netYield - cancelledAssets,
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
            availableToWithdraw:   initialAssets - initialDeployment + netYield - cancelledAssets,
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(otherRecipient),               cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_cancelYield_success_calledTwiceWithWarpBetween() external {

        /**********************************************************************************************************************************/
        /*** Warp partway through the schedule so part of the yield has vested                                                          ***/
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
            recordedAssets:        initialAssets - initialDeployment + netYield,
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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
        /*** Warp further into the (now shorter) schedule, so more yield accrues before the second cancellation                         ***/
        /**********************************************************************************************************************************/

        postCancelElapsed   = 5 days;
        realizedSinceCancel = remainingYield * postCancelElapsed / (yieldDuration - elapsedDuration);
        unrealizedAtCancel2 = remainingYield - realizedSinceCancel;

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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets,
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
        /*** Cancel part of what remains a second time: the schedule shrinks again but stays anchored to the original deadline          ***/
        /**********************************************************************************************************************************/

        cancelledAssets2 = 5_000e6;
        remainingYield2  = unrealizedAtCancel2 - cancelledAssets2;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets2, managedWallet);

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
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets - cancelledAssets2,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield2,
            yieldStart:           startingTime + elapsedDuration + postCancelElapsed,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialAssets - initialDeployment + netYield - cancelledAssets - cancelledAssets2
        );
        assertEq(fundsAsset.balanceOf(managedWallet),    initialDeployment + cancelledAssets + cancelledAssets2);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the twice-shrunk schedule still fully vests by the same deadline                            ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedAtCancel + realizedSinceCancel + remainingYield2,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel + remainingYield2,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + remainingYield2,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedAtCancel + realizedSinceCancel + remainingYield2,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedAtCancel + realizedSinceCancel + remainingYield2,
            availableToWithdraw:   initialAssets - initialDeployment + realizedAtCancel + realizedSinceCancel + remainingYield2,
            recordedAssets:        initialAssets - initialDeployment + netYield - cancelledAssets - cancelledAssets2,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: remainingYield2,
            yieldStart:           startingTime + elapsedDuration + postCancelElapsed,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        remainingYield2
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialAssets - initialDeployment + netYield - cancelledAssets - cancelledAssets2
        );
        assertEq(fundsAsset.balanceOf(managedWallet),    initialDeployment + cancelledAssets + cancelledAssets2);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);
    }

    function test_cancelYield_success_twoPoolsShareStrategy() external {
        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        initialAssets1 = initialAssets;
        initialShares1 = initialShares;

        /**********************************************************************************************************************************/
        /*** Warp halfway through the first pool's vesting schedule                                                                     ***/
        /**********************************************************************************************************************************/

        elapsedDuration  = yieldDuration / 2;
        realizedAtCancel = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        initialAssets1 + realizedAtCancel,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares1,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets1 + realizedAtCancel,
            availableToWithdraw:   initialAssets1 - initialDeployment + realizedAtCancel,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           initialAssets1 + realizedAtCancel,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets1 + realizedAtCancel,
            availableToWithdraw:   initialAssets1 - initialDeployment + realizedAtCancel,
            recordedAssets:        initialAssets1 - initialDeployment + netYield,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets1 - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund a second pool into the same strategy manager mid-vesting: it mints shares at the current (non 1:1) price              ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        initialAssets2      = 819_000e6;
        expectedShares2     = initialAssets2 * initialShares1 / (initialAssets1 + realizedAtCancel);
        totalStrategyShares = initialShares1 + expectedShares2;
        totalPrincipal      = initialAssets1 + initialAssets2;

        deposit(pool2, makeAddr("lp2"), initialAssets2);
        fundStrategyManager(poolManager2, allocationStrategyManager, initialAssets2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        initialAssets1 + realizedAtCancel,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        initialAssets2,
            totalSupply:        initialAssets2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets1 + realizedAtCancel + initialAssets2,
            availableToWithdraw:   initialAssets1 - initialDeployment + realizedAtCancel + initialAssets2,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           initialAssets1 + realizedAtCancel,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           initialAssets2,
            shares:           expectedShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets1 + realizedAtCancel + initialAssets2,
            availableToWithdraw:   initialAssets1 - initialDeployment + realizedAtCancel + initialAssets2,
            recordedAssets:        initialAssets1 - initialDeployment + netYield + initialAssets2,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets1 - initialDeployment + netYield + initialAssets2);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp further so more yield vests, split proportionally between the two now-differently-sized positions                     ***/
        /**********************************************************************************************************************************/

        postCancelElapsed  = 5 days;
        elapsedDuration   += postCancelElapsed;
        realizedAtCancel   = netYield * elapsedDuration / yieldDuration;
        unrealizedAtCancel = netYield - realizedAtCancel;

        vm.warp(startingTime + elapsedDuration);

        aumAtCancel         = totalPrincipal + realizedAtCancel;
        pool1AssetsAtCancel = initialShares1  * aumAtCancel / totalStrategyShares;
        pool2AssetsAtCancel = expectedShares2 * aumAtCancel / totalStrategyShares;

        assertPoolState({
            pool:               pool1,
            totalAssets:        pool1AssetsAtCancel,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        pool2AssetsAtCancel,
            totalSupply:        initialAssets2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAtCancel,
            availableToWithdraw:   aumAtCancel - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           pool1AssetsAtCancel,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           pool2AssetsAtCancel,
            shares:           expectedShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAtCancel,
            availableToWithdraw:   aumAtCancel - initialDeployment,
            recordedAssets:        totalPrincipal - initialDeployment + netYield,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalPrincipal - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel part of the unrealized yield: the shared schedule shrinks for both pools' positions at once                         ***/
        /**********************************************************************************************************************************/

        cancelledAssets = 10_000e6;
        remainingYield  = unrealizedAtCancel - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

        assertPoolState({
            pool:               pool1,
            totalAssets:        pool1AssetsAtCancel,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        pool2AssetsAtCancel,
            totalSupply:        initialAssets2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAtCancel,
            availableToWithdraw:   aumAtCancel - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           pool1AssetsAtCancel,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           pool2AssetsAtCancel,
            shares:           expectedShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAtCancel,
            availableToWithdraw:   aumAtCancel - initialDeployment,
            recordedAssets:        totalPrincipal - initialDeployment + netYield - cancelledAssets,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalPrincipal - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline: the remaining (smaller) schedule fully vests, split by the current share proportions        ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        finalAum         = aumAtCancel + remainingYield;
        pool1FinalAssets = initialShares1 * finalAum / totalStrategyShares;
        pool2FinalAssets = expectedShares2 * finalAum / totalStrategyShares;

        assertPoolState({
            pool:               pool1,
            totalAssets:        pool1FinalAssets,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        pool2FinalAssets,
            totalSupply:        initialAssets2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           pool1FinalAssets,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           pool2FinalAssets,
            shares:           expectedShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            recordedAssets:        totalPrincipal - initialDeployment + netYield - cancelledAssets,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalPrincipal - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}
