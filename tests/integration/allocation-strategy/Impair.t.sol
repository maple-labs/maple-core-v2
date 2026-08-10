// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IPool,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyImpairTestBase is AllocationStrategyTestBase {

    uint256 impairment        = 100_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialShares     = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}

contract AllocationStrategyImpairFailureTests is AllocationStrategyImpairTestBase {

    function test_impair_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);
    }

    function test_impair_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);
    }

    function test_impair_revert_notAuthorized() external {
        address notAdmin = makeAddr("notAdmin");

        vm.prank(notAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);
    }

    function test_impair_revert_notAuthorized_managedWallet() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);
    }

    function test_impair_revert_notAuthorized_governor() external {
        vm.prank(governor);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);
    }

    function test_impair_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:I:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).impair(0);
    }

}

contract AllocationStrategyImpairSuccessTests is AllocationStrategyImpairTestBase {

    address firstPool;
    address firstPoolManager;
    address secondPool;
    address secondPoolManager;

    uint256 aumAfterExit;
    uint256 delegateFee;
    uint256 excessImpairment;
    uint256 exitAssets;
    uint256 finalAum;
    uint256 firstImpairment;
    uint256 firstLoss;
    uint256 firstRedeemAssets;
    uint256 firstRedeemShares;
    uint256 firstShares;
    uint256 growthImpairment;
    uint256 initialAssets1;
    uint256 initialAssets2;
    uint256 initialShares1;
    uint256 initialShares2;
    uint256 lossAmount;
    uint256 netYield;
    uint256 protocolFee;
    uint256 realizedAtImpair;
    uint256 realizedYieldAtElapsed;
    uint256 reducedAum;
    uint256 redemptionImpairment;
    uint256 secondFund;
    uint256 secondGrossAfterExit;
    uint256 secondImpairment;
    uint256 secondLoss;
    uint256 secondLossAfterExit;
    uint256 secondRedeemAssets;
    uint256 secondRedeemShares;
    uint256 secondShares;
    uint256 sharesAfterExit;
    uint256 splitImpairment;
    uint256 topUpFund;
    uint256 totalAssets;
    uint256 totalShares;
    uint256 yieldAssets;

    uint32 delegateFeeRate;
    uint32 elapsedDuration;
    uint32 protocolFeeRate;
    uint32 yieldDuration;

    function test_impair_success_accumulatesAcrossAdmins() external {

        /**********************************************************************************************************************************/
        /*** Impair via the strategy delegate                                                                                           ***/
        /**********************************************************************************************************************************/

        firstImpairment = 100_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).impair(firstImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   firstImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      firstImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: firstImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      firstImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), firstImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair via the operational admin: the loss accumulates on top of the first                                                 ***/
        /**********************************************************************************************************************************/

        secondImpairment = 150_000e6;

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).impair(secondImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   firstImpairment + secondImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      firstImpairment + secondImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: firstImpairment + secondImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      firstImpairment + secondImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), firstImpairment + secondImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_clampsToAssetsUnderManagement() external {

        /**********************************************************************************************************************************/
        /*** Impair for more than the AUM: the unrealized loss clamps to the AUM                                                        ***/
        /**********************************************************************************************************************************/

        excessImpairment = initialAssets + 250_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, excessImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   initialAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), excessImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_unrealizedLossesGrowsAsAumIncreases() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield, then impair for slightly more than the current AUM                                                         ***/
        /**********************************************************************************************************************************/

        yieldAssets      = 300_000e6;
        yieldDuration    = 30 days;
        growthImpairment = initialAssets + 180_000e6;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);
        impairAllocationStrategy(allocationUnderlyingStrategy, growthImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   initialAssets,
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
            recordedAssets:        initialAssets - initialDeployment + yieldAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), growthImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Warp partway through the yield schedule: AUM grows but stays below the impairment                                          ***/
        /**********************************************************************************************************************************/

        elapsedDuration        = 15 days;
        realizedYieldAtElapsed = yieldAssets * elapsedDuration / yieldDuration;
        totalAssets            = initialAssets + realizedYieldAtElapsed;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   totalAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      totalAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: totalAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + yieldAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      totalAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYieldAtElapsed
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), growthImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Warp to the full yield deadline: AUM now exceeds the impairment, so the unrealized loss clamps to it                       ***/
        /**********************************************************************************************************************************/

        finalAum = initialAssets + yieldAssets;

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        finalAum,
            totalSupply:        initialShares,
            unrealizedLosses:   growthImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            unrealizedLosses:      growthImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           finalAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: growthImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + yieldAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      growthImpairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), growthImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_splitsAcrossPoolManagers() external {

        /**********************************************************************************************************************************/
        /*** Set up a second pool sharing the strategy                                                                                  ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);
        firstShares      = initialShares;

        ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        secondFund   = 450_000e6;
        secondShares = secondFund;

        totalShares = firstShares + secondShares;

        deposit(secondPool, lp, initialAssets);
        fundStrategyManager(secondPoolManager, allocationStrategyManager, secondFund);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: initialAssets - secondFund
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + secondFund,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + secondFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the position: the loss splits proportionally across both pool managers                                              ***/
        /**********************************************************************************************************************************/

        splitImpairment = 100_000e6;

        firstLoss  = divRoundUp(firstShares * splitImpairment,  totalShares);
        secondLoss = divRoundUp(secondShares * splitImpairment, totalShares);

        impairAllocationStrategy(allocationUnderlyingStrategy, splitImpairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   firstLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   secondLoss,
            availableLiquidity: initialAssets - secondFund
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + secondFund,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), splitImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + secondFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_doesNotAffectYieldSchedule() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp partway through it                                                                                 ***/
        /**********************************************************************************************************************************/

        delegateFeeRate = 0.02e6;  // 2%
        protocolFeeRate = 0.03e6;  // 3%
        yieldAssets     = 50_000e6;
        yieldDuration   = 31 days;

        delegateFee = yieldAssets * delegateFeeRate / 1e6;
        protocolFee = yieldAssets * protocolFeeRate / 1e6;
        netYield    = yieldAssets - delegateFee - protocolFee;

        elapsedDuration  = 10 days;
        realizedAtImpair = netYield * elapsedDuration / yieldDuration;
        totalAssets      = initialAssets + realizedAtImpair;

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
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
            realizedYield:        realizedAtImpair
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Impair the position: the yield schedule remains unaffected                                                                 ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
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
            realizedYield:        realizedAtImpair
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the yield deadline: the impairment is still unaffected once the schedule is fully vested                           ***/
        /**********************************************************************************************************************************/

        totalAssets = initialAssets + netYield;

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
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
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_impair_success_afterLossRecognized() external {

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the deployed assets                                                                                    ***/
        /**********************************************************************************************************************************/

        lossAmount = 50_000e6;
        reducedAum = initialAssets - lossAmount;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the position: the unrealized loss clamps to the reduced AUM                                                         ***/
        /**********************************************************************************************************************************/

        excessImpairment = reducedAum + 10_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, excessImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   reducedAum,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      reducedAum
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: reducedAum
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      reducedAum
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), excessImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_noFurtherEffectOnceClampedAtAum() external {

        /**********************************************************************************************************************************/
        /*** Impair up to the full AUM                                                                                                  ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, initialAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   initialAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), initialAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair further: the unrealized loss stays clamped, though the impairment keeps accumulating                                ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, 1);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   initialAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), initialAssets + 1);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_whenNothingDeployed() external {

        /**********************************************************************************************************************************/
        /*** Return the deployed capital so nothing remains deployed                                                                    ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

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
            availableToWithdraw:   initialAssets,
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
            availableToWithdraw:   initialAssets,
            recordedAssets:        initialAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the position against idle cash only                                                                                 ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

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
            availableToWithdraw:   initialAssets,
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
            availableToWithdraw:   initialAssets,
            recordedAssets:        initialAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_fundingNotDiscountedByExistingImpairment() external {

        /**********************************************************************************************************************************/
        /*** Deposit fresh liquidity into the pool before impairing, so there is cash on hand to fund with afterward                    ***/
        /**********************************************************************************************************************************/

        topUpFund = 200_000e6;

        deposit(lp, topUpFund);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + topUpFund,
            totalSupply:        initialShares + topUpFund,
            unrealizedLosses:   0,
            availableLiquidity: topUpFund
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the existing position                                                                                               ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + topUpFund,
            totalSupply:        initialShares + topUpFund,
            unrealizedLosses:   impairment,
            availableLiquidity: topUpFund
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Fund the strategy with the fresh cash: shares mint at the raw AUM-based price, not discounted by the existing impairment   ***/
        /**********************************************************************************************************************************/

        totalAssets = initialAssets + topUpFund;

        fundStrategyManager(address(poolManager), allocationStrategyManager, topUpFund);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        totalAssets,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalAssets,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           totalAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + topUpFund,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + topUpFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_impair_success_redemptionDiscountedAfterImpairment() external {

        /**********************************************************************************************************************************/
        /*** Redeem shares before any impairment exists: the exit value is 1:1 with the shares burned                                   ***/
        /**********************************************************************************************************************************/

        firstRedeemShares = 50_000e6;
        firstRedeemAssets = firstRedeemShares;

        totalAssets = initialAssets - firstRedeemAssets;
        totalShares = initialShares - firstRedeemShares;

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, firstRedeemShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, firstRedeemShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: firstRedeemAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           totalShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment - firstRedeemAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - firstRedeemAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the position                                                                                                        ***/
        /**********************************************************************************************************************************/

        redemptionImpairment = 190_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, redemptionImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   redemptionImpairment,
            availableLiquidity: firstRedeemAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      redemptionImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           totalShares,
            pendingShares:    0,
            unrealizedLosses: redemptionImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment - firstRedeemAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      redemptionImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), redemptionImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - firstRedeemAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Redeem the same number of shares again: the exit value is now discounted by the unrealized loss                            ***/
        /**********************************************************************************************************************************/

        secondRedeemShares = 50_000e6;
        secondRedeemAssets = secondRedeemShares * (totalAssets - redemptionImpairment) / totalShares;

        totalAssets -= secondRedeemAssets;
        totalShares -= secondRedeemShares;

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, secondRedeemShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, secondRedeemShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   redemptionImpairment,
            availableLiquidity: firstRedeemAssets + secondRedeemAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      redemptionImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           totalShares,
            pendingShares:    0,
            unrealizedLosses: redemptionImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment - firstRedeemAssets - secondRedeemAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      redemptionImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), redemptionImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialAssets - initialDeployment - firstRedeemAssets - secondRedeemAssets
        );
        assertEq(fundsAsset.balanceOf(managedWallet), initialDeployment);
    }

    function test_impair_success_exitAfterImpairment_remainingPoolGains() external {

        /**********************************************************************************************************************************/
        /*** Set up a second pool sharing the strategy                                                                                  ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);

        initialAssets1 = initialAssets;
        initialShares1 = initialShares;

        ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        initialAssets2 = 500_000e6;
        initialShares2 = initialAssets2;

        totalShares = initialShares1 + initialShares2;
        totalAssets = initialAssets1 + initialAssets2;

        deposit(secondPool, lp, initialAssets2);
        fundStrategyManager(secondPoolManager, allocationStrategyManager, initialAssets2);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        initialAssets1,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        initialAssets2,
            totalSupply:        initialShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           initialShares1,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           initialShares2,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        totalAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Impair the position: the loss splits proportionally across both pool managers                                              ***/
        /**********************************************************************************************************************************/

        splitImpairment = 150_000e6;

        firstLoss  = divRoundUp(initialShares1 * splitImpairment, totalShares);
        secondLoss = divRoundUp(initialShares2 * splitImpairment, totalShares);

        impairAllocationStrategy(allocationUnderlyingStrategy, splitImpairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        initialAssets1,
            totalSupply:        initialShares1,
            unrealizedLosses:   firstLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        initialAssets2,
            totalSupply:        initialShares2,
            unrealizedLosses:   secondLoss,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           initialShares1,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           initialShares2,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        totalAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), splitImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** First pool fully exits, taking a haircut at the impaired price; second pool is now the sole remaining shareholder          ***/
        /**********************************************************************************************************************************/

        exitAssets      = initialShares1 * (totalAssets - splitImpairment) / totalShares;
        sharesAfterExit = totalShares - initialShares1;
        aumAfterExit    = totalAssets - exitAssets;

        secondGrossAfterExit = initialShares2 * aumAfterExit / sharesAfterExit;
        secondLossAfterExit  = divRoundUp(initialShares2 * splitImpairment, sharesAfterExit);

        requestRedeemFromStrategyManager(firstPoolManager, allocationStrategyManager, initialShares1);
        processRedemptionFromStrategyManager(firstPoolManager, allocationStrategyManager, initialShares1);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        exitAssets,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: exitAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondGrossAfterExit,
            totalSupply:        initialShares2,
            unrealizedLosses:   secondLossAfterExit,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           sharesAfterExit,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit - initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondGrossAfterExit,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: secondLossAfterExit
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterExit,
            availableToWithdraw:   aumAfterExit - initialDeployment,
            recordedAssets:        aumAfterExit - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      splitImpairment
        });

        assertEq(IPool(secondPool).convertToAssets(initialShares2),     initialAssets1 + initialAssets2 - exitAssets);
        assertEq(IPool(secondPool).convertToExitAssets(initialShares2), initialAssets1 + initialAssets2 - exitAssets - splitImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                splitImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).assetsOf(secondPoolManager),     secondGrossAfterExit);
        assertEq(IStrategyManager(allocationStrategyManager).convertToAssets(initialShares2), secondGrossAfterExit);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterExit - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}
