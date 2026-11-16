// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IPool, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyRemoveImpairmentTestBase is AllocationStrategyTestBase {

    uint256 delegateFee       = 1_000e6;
    uint256 impairment        = 250_000e6;
    uint256 impairmentRemoval = 100_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialShares     = 1_000_000e6;
    uint256 netYield          = 47_500e6;
    uint256 protocolFee       = 1_500e6;
    uint256 yieldAssets       = 50_000e6;

    uint32 delegateFeeRate = 0.02e6; // 2%
    uint32 protocolFeeRate = 0.03e6; // 3%
    uint32 yieldDuration   = 31 days;

    function setUp() public virtual override {
        super.setUp();

        // Fund pool and strategy, then deploy assets so a realized position co-exists with the impairment.
        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        // Set strategy fees so their independence from impairment removal can be asserted.
        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);

        // Impair part of the deployed assets so there is an impairment to remove.
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        // Initial assertions.
        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

}

contract AllocationStrategyRemoveImpairmentFailureTests is AllocationStrategyRemoveImpairmentTestBase {

    function test_removeImpairment_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);
    }

    function test_removeImpairment_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);
    }

    function test_removeImpairment_revert_notAuthorized() external {
        address notAdmin = makeAddr("notAdmin");

        vm.prank(notAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);
    }

    function test_removeImpairment_revert_notAuthorized_managedWallet() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);
    }

    function test_removeImpairment_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(0);
    }

    function test_removeImpairment_revert_exceedsImpairment_boundary() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment + 1);
    }

    function test_removeImpairment_revert_exceedsImpairment_maxConvention() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(type(uint256).max);
    }

    function test_removeImpairment_revert_exceedsImpairment_afterFullRemoval() external {
        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(1);
    }

}

contract AllocationStrategyRemoveImpairmentSuccessTests is AllocationStrategyRemoveImpairmentTestBase {

    address bootstrapStrategyDelegate;
    address firstPool;
    address firstPoolManager;
    address secondPool;
    address secondPoolManager;
    address underlyingStrategy;

    uint256 assets1;
    uint256 assets2;
    uint256 aumAfterExit;
    uint256 aumAfterLoss;
    uint256 aumAfterYield;
    uint256 bootstrapGrossAfterExit;
    uint256 bootstrapLoss;
    uint256 bootstrapLossAfterExit;
    uint256 bootstrapMint;
    uint256 bootstrapNetAfterRemoval;
    uint256 exitAssets;
    uint256 extraImpairment;
    uint256 firstAssets;
    uint256 firstLoss;
    uint256 firstShares;
    uint256 firstUnrealizedLoss;
    uint256 impairedAfterRemoval;
    uint256 lossAmount;
    uint256 partialRemoval;
    uint256 realizedYield;
    uint256 remainingImpairment;
    uint256 removalAboveClamp;
    uint256 secondAssets;
    uint256 secondGrossAfterExit;
    uint256 secondLoss;
    uint256 secondLossAfterExit;
    uint256 secondNetAfterExit;
    uint256 secondNetAfterRemoval;
    uint256 secondNetBeforeExit;
    uint256 secondShares;
    uint256 secondUnrealizedLoss;
    uint256 shares1;
    uint256 shares2;
    uint256 sharesAfterExit;
    uint256 stackedImpairment;
    uint256 storedImpairment;
    uint256 totalAssets;
    uint256 totalShares;
    uint256 yieldDelegateFee;
    uint256 yieldGross;
    uint256 yieldNetAmount;
    uint256 yieldProtocolFee;

    uint32 elapsedDuration;

    function test_removeImpairment_success_partialAmount() external {
        remainingImpairment = impairment - impairmentRemoval;

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                remainingImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - remainingImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_fullAmount() external {
        /**********************************************************************************************************************************/
        /*** Remove the entire impairment                                                                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment);

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
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_acrossAllAdmins() external {
        /**********************************************************************************************************************************/
        /*** Remove part of the impairment as the strategy delegate                                                                     ***/
        /**********************************************************************************************************************************/

        remainingImpairment = impairment - impairmentRemoval;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                remainingImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - remainingImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Remove the remaining impairment as the operational admin                                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(remainingImpairment);

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
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_aboveAndBelowAumClamp() external {
        extraImpairment   = 900_000e6;
        storedImpairment  = impairment + extraImpairment;
        removalAboveClamp = storedImpairment - initialAssets;

        /**********************************************************************************************************************************/
        /*** Impair further so the stored impairment exceeds the strategy's AUM                                                         ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, extraImpairment);

        assertPoolState({
            pool: address(pool),
            totalAssets: initialAssets,
            totalSupply: initialShares,
            unrealizedLosses: initialAssets, // Clamped to the AUM.
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: initialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                storedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0); // Fully clamped: AUM is exhausted.

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Remove impairment above the clamp: the stored impairment falls to exactly the AUM, so unrealized losses are unaffected     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(removalAboveClamp);

        assertPoolState({
            pool: address(pool),
            totalAssets: initialAssets,
            totalSupply: initialShares,
            unrealizedLosses: initialAssets, // Still clamped to the AUM, unchanged.
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: initialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                initialAssets);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0); // Still fully clamped, unchanged.

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Remove impairment below the clamp: unrealized losses now move 1:1 with the removal                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);

        impairedAfterRemoval = initialAssets - impairmentRemoval;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAfterRemoval,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAfterRemoval
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairedAfterRemoval);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairedAfterRemoval);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_withScheduledYield() external {
        /**********************************************************************************************************************************/
        /*** Schedule yield while the impairment is outstanding                                                                         ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp partway through the vesting schedule                                                                                  ***/
        /**********************************************************************************************************************************/

        elapsedDuration = 10 days;
        realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            recordedAssets:        initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets + realizedYield - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Remove the impairment while yield is still vesting: the yield schedule and accrued fees are unaffected                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
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
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets + realizedYield);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_removeImpairment_success_afterLossRecognized() external {
        extraImpairment = 550_000e6;
        lossAmount      = 300_000e6;
        partialRemoval  = 200_000e6;

        stackedImpairment = impairment + extraImpairment;
        aumAfterLoss      = initialAssets - lossAmount;

        /**********************************************************************************************************************************/
        /*** Impair further so the impairment is large, but still within the AUM                                                        ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, extraImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   stackedImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      stackedImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: stackedImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      stackedImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                stackedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - stackedImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Recognize a loss against the managed wallet: the AUM drops below the impairment, clamping the reported loss                ***/
        /**********************************************************************************************************************************/

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        assertPoolState({
            pool: address(pool),
            totalAssets: aumAfterLoss,
            totalSupply: initialShares,
            unrealizedLosses: aumAfterLoss, // Clamped down from stackedImpairment purely by the recognized loss.
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      aumAfterLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterLoss,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: aumAfterLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      aumAfterLoss
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                stackedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).totalDeployedAssets(),           initialDeployment - lossAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0); // Fully clamped: AUM is exhausted.

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Remove part of the stacked impairment: once below the new (lower) AUM, unrealized losses move 1:1 with the removal         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(partialRemoval);

        impairedAfterRemoval = stackedImpairment - partialRemoval; // 600,000e6, now below the 700,000e6 AUM.

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAfterRemoval,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterLoss,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAfterRemoval
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairedAfterRemoval);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).totalDeployedAssets(),           initialDeployment - lossAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), aumAfterLoss - impairedAfterRemoval);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_aumGrowthReleasesClamp() external {
        extraImpairment = 900_000e6;
        yieldGross      = 200_000e6;

        stackedImpairment = impairment + extraImpairment;
        yieldDelegateFee  = yieldGross * delegateFeeRate / 1e6;
        yieldProtocolFee  = yieldGross * protocolFeeRate / 1e6;
        yieldNetAmount    = yieldGross - yieldDelegateFee - yieldProtocolFee;

        /**********************************************************************************************************************************/
        /*** Impair further so the impairment exceeds the AUM                                                                           ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, extraImpairment);

        assertPoolState({
            pool: address(pool),
            totalAssets: initialAssets,
            totalSupply: initialShares,
            unrealizedLosses: initialAssets, // Clamped to the AUM.
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: initialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                stackedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0); // Fully clamped: AUM is exhausted.

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Realize yield instantly: the AUM grows back above the impairment, and the clamp releases                                   ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldGross, 0);

        aumAfterYield = initialAssets + yieldNetAmount;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        initialShares,
            unrealizedLosses:   stackedImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield - initialDeployment,
            unrealizedLosses:      stackedImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: stackedImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield - initialDeployment,
            recordedAssets:        aumAfterYield - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      stackedImpairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldNetAmount,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldNetAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                stackedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), aumAfterYield - stackedImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             yieldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     yieldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment: now unclamped, unrealized losses move 1:1 with the removal                                  ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);

        impairedAfterRemoval = stackedImpairment - impairmentRemoval;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAfterRemoval,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield - initialDeployment,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAfterRemoval
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield - initialDeployment,
            recordedAssets:        aumAfterYield - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAfterRemoval
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldNetAmount,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldNetAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairedAfterRemoval);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), aumAfterYield - impairedAfterRemoval);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             yieldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     yieldProtocolFee);
    }

    function test_removeImpairment_success_splitsAcrossPoolManagers() external {
        /**********************************************************************************************************************************/
        /*** Remove the existing impairment for a clean baseline, then fund a second pool that shares the strategy                      ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment);

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);

        (secondPool, secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        firstAssets  = 1_000_000e6;
        secondAssets = 450_000e6;

        firstShares  = firstAssets;
        secondShares = secondAssets;
        totalShares  = firstShares + secondShares;

        deposit(secondPool, lp, secondAssets);
        fundStrategyManager(secondPoolManager, allocationStrategyManager, secondAssets);

        /**********************************************************************************************************************************/
        /*** Impair the strategy across both pools                                                                                      ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        firstUnrealizedLoss  = divRoundUp(firstShares * impairment, totalShares);
        secondUnrealizedLoss = divRoundUp(secondShares * impairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstAssets,
            totalSupply:        firstShares,
            unrealizedLosses:   firstUnrealizedLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondAssets,
            totalSupply:        secondShares,
            unrealizedLosses:   secondUnrealizedLoss,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: firstAssets + secondAssets,
            availableToWithdraw:   firstAssets + secondAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondUnrealizedLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstAssets + secondAssets,
            availableToWithdraw:   firstAssets + secondAssets - initialDeployment,
            recordedAssets:        firstAssets + secondAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IPool(firstPool).convertToExitAssets(firstShares),   firstAssets - firstUnrealizedLoss);
        assertEq(IPool(secondPool).convertToExitAssets(secondShares), secondAssets - secondUnrealizedLoss);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstAssets + secondAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment across both pools                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairmentRemoval);

        remainingImpairment = impairment - impairmentRemoval;

        firstUnrealizedLoss  = divRoundUp(firstShares * remainingImpairment, totalShares);
        secondUnrealizedLoss = divRoundUp(secondShares * remainingImpairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstAssets,
            totalSupply:        firstShares,
            unrealizedLosses:   firstUnrealizedLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondAssets,
            totalSupply:        secondShares,
            unrealizedLosses:   secondUnrealizedLoss,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: firstAssets + secondAssets,
            availableToWithdraw:   firstAssets + secondAssets - initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondUnrealizedLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstAssets + secondAssets,
            availableToWithdraw:   firstAssets + secondAssets - initialDeployment,
            recordedAssets:        firstAssets + secondAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                remainingImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IPool(firstPool).convertToExitAssets(firstShares),   firstAssets - firstUnrealizedLoss);
        assertEq(IPool(secondPool).convertToExitAssets(secondShares), secondAssets - secondUnrealizedLoss);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstAssets + secondAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_removeImpairment_success_bootstrapMint_exitThenRemoveImpairment_remainingPoolGainsAll() external {
        /**********************************************************************************************************************************/
        /*** Deploy a fresh allocation strategy funded with a bootstrap mint, then attach two pools that share it                       ***/
        /**********************************************************************************************************************************/

        bootstrapStrategyDelegate = makeAddr("bootstrapStrategyDelegate");
        bootstrapMint             = 10e6;

        (strategyManager, underlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        bootstrapStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           bootstrapMint
        });

        (firstPool, firstPoolManager)   = _createPoolSharingStrategy("bootstrapFirstPoolDelegate", strategyManager);
        (secondPool, secondPoolManager) = _createPoolSharingStrategy("bootstrapSecondPoolDelegate", strategyManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapMint,
            availableToWithdraw:   bootstrapMint,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy,
            assetsUnderManagement: bootstrapMint,
            availableToWithdraw:   bootstrapMint,
            recordedAssets:        bootstrapMint,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(underlyingStrategy), bootstrapMint);

        /**********************************************************************************************************************************/
        /*** Fund both pools through the strategy manager                                                                               ***/
        /**********************************************************************************************************************************/

        assets1 = 1_000_000e6;
        assets2 = 500_000e6;

        shares1 = assets1;
        shares2 = assets2;

        deposit(firstPool, lp, assets1);
        deposit(secondPool, lp, assets2);

        fundStrategyManager(firstPoolManager, strategyManager, assets1);
        fundStrategyManager(secondPoolManager, strategyManager, assets2);

        totalAssets = bootstrapMint + assets1 + assets2;
        totalShares = bootstrapMint + shares1 + shares2;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        assets1,
            totalSupply:        shares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        assets2,
            totalSupply:        shares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           assets1,
            shares:           shares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           assets2,
            shares:           shares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(underlyingStrategy), totalAssets);

        /**********************************************************************************************************************************/
        /*** Impair the strategy: the loss splits across both pools and the bootstrap's dead shares                                     ***/
        /**********************************************************************************************************************************/

        impairment = 150_000e6;

        impairAllocationStrategy(underlyingStrategy, impairment);

        firstLoss     = divRoundUp(shares1 * impairment, totalShares);
        secondLoss    = divRoundUp(shares2 * impairment, totalShares);
        bootstrapLoss = divRoundUp(bootstrapMint * impairment, totalShares);

        secondNetBeforeExit = shares2 * (totalAssets - impairment) / totalShares;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        assets1,
            totalSupply:        shares1,
            unrealizedLosses:   firstLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        assets2,
            totalSupply:        shares2,
            unrealizedLosses:   secondLoss,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           assets1,
            shares:           shares1,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           assets2,
            shares:           shares2,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: bootstrapLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(underlyingStrategy).impairedAssets(), impairment);

        assertEq(IPool(firstPool).convertToExitAssets(shares1),  assets1 - firstLoss);
        assertEq(IPool(secondPool).convertToExitAssets(shares2), assets2 - secondLoss);

        assertEq(fundsAsset.balanceOf(underlyingStrategy), totalAssets);

        /**********************************************************************************************************************************/
        /*** First pool fully exits the strategy, taking a haircut at the impaired price                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager, strategyManager, shares1);
        processRedemptionFromStrategyManager(firstPoolManager, strategyManager, shares1);

        exitAssets      = shares1 * (totalAssets - impairment) / totalShares;
        sharesAfterExit = totalShares - shares1;
        aumAfterExit    = totalAssets - exitAssets;

        secondGrossAfterExit    = shares2 * aumAfterExit / sharesAfterExit;
        bootstrapGrossAfterExit = bootstrapMint * aumAfterExit / sharesAfterExit;

        secondLossAfterExit    = divRoundUp(shares2 * impairment, sharesAfterExit);
        bootstrapLossAfterExit = divRoundUp(bootstrapMint * impairment, sharesAfterExit);

        secondNetAfterExit = secondGrossAfterExit - secondLossAfterExit;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        exitAssets,
            totalSupply:        shares1,
            unrealizedLosses:   0,
            availableLiquidity: exitAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondGrossAfterExit,
            totalSupply:        shares2,
            unrealizedLosses:   secondLossAfterExit,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           sharesAfterExit,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondGrossAfterExit,
            shares:           shares2,
            pendingShares:    0,
            unrealizedLosses: secondLossAfterExit
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(0),
            assets:           bootstrapGrossAfterExit,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: bootstrapLossAfterExit
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit,
            recordedAssets:        aumAfterExit,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(underlyingStrategy).impairedAssets(), impairment);

        assertEq(IPool(firstPool).convertToExitAssets(shares1),  exitAssets);
        assertEq(IPool(secondPool).convertToExitAssets(shares2), secondNetAfterExit);

        assertEq(fundsAsset.balanceOf(underlyingStrategy), aumAfterExit);

        /**********************************************************************************************************************************/
        /*** Remove the entire impairment: the released value flows entirely to the pool that stayed in, not the one that already left  ***/
        /**********************************************************************************************************************************/

        vm.prank(bootstrapStrategyDelegate);
        IAllocationStrategy(underlyingStrategy).removeImpairment(impairment);

        secondNetAfterRemoval    = secondGrossAfterExit;
        bootstrapNetAfterRemoval = bootstrapGrossAfterExit;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        exitAssets,
            totalSupply:        shares1,
            unrealizedLosses:   0,
            availableLiquidity: exitAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondNetAfterRemoval,
            totalSupply:        shares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           sharesAfterExit,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondNetAfterRemoval,
            shares:           shares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(0),
            assets:           bootstrapNetAfterRemoval,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit,
            recordedAssets:        aumAfterExit,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(underlyingStrategy).impairedAssets(), 0);

        assertEq(IStrategyManager(strategyManager).convertToExitAssets(shares2), secondNetAfterRemoval);

        assertEq(secondNetAfterRemoval, totalAssets - exitAssets - bootstrapNetAfterRemoval - 1); // Rounding error

        assertEq(IPool(firstPool).convertToExitAssets(shares1),  exitAssets);
        assertEq(IPool(secondPool).convertToExitAssets(shares2), secondNetAfterRemoval);

        assertEq(fundsAsset.balanceOf(underlyingStrategy), aumAfterExit);
    }

}
