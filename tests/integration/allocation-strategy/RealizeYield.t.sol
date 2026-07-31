// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyRealizeYieldTestBase is AllocationStrategyTestBase {

    uint256 delegateFee       = 1_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialShares     = 1_000_000e6;
    uint256 netYield          = 47_500e6;
    uint256 protocolFee       = 1_500e6;
    uint256 yieldAssets       = 50_000e6;

    uint32 delegateFeeRate = 0.02e6;  // 2%
    uint32 protocolFeeRate = 0.03e6;  // 3%
    uint32 yieldCooldown   = 1 hours;
    uint32 yieldDuration   = 31 days;

    function setUp() public virtual override {
        super.setUp();

        // Fund pool and strategy, then deploy assets so a realized position co-exists with the yield being realized.
        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        // Set strategy fees.
        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);

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
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}

contract AllocationStrategyRealizeYieldFailureTests is AllocationStrategyRealizeYieldTestBase {

    function test_realizeYield_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_notManagedWallet() external {
        address notManagedWallet = makeAddr("notManagedWallet");

        vm.prank(notManagedWallet);
        vm.expectRevert("MAS:NOT_MAPLE_MANAGED_WALLET");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_notAllowed() external {
        setPermissions({
            strategy_:        allocationUnderlyingStrategy,
            account_:         managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: false
        });

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:NOT_ALLOWED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_yieldCap() external {
        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).setYieldCap(yieldAssets);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:CAP_EXCEEDED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets + 1, yieldDuration, "");
    }

    function test_realizeYield_revert_yieldCooldown() external {
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        vm.warp(startingTime + yieldCooldown - 1 seconds);
        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:COOLDOWN");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_sharedYieldCooldown() external {
        address managedWallet2 = makeAddr("managedWallet2");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: false,
            canReturnAssets_: false,
            canRealizeYield_: true,
            deploymentCap_:   0
        });

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        vm.warp(startingTime + yieldCooldown - 1 seconds);
        vm.prank(managedWallet2);
        vm.expectRevert("MAS:RY:COOLDOWN");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_insufficientApproval() external {
        erc20_approve(address(fundsAsset), managedWallet, allocationUnderlyingStrategy, yieldAssets - 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:TRANSFER_FROM_FAILED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_insufficientBalance() external {
        erc20_approve(address(fundsAsset), managedWallet, allocationUnderlyingStrategy, initialDeployment + 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:TRANSFER_FROM_FAILED");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(initialDeployment + 1, yieldDuration, "");
    }

}

contract AllocationStrategyRealizeYieldSuccessTests is AllocationStrategyRealizeYieldTestBase {

    uint256 poolAssets1;
    uint256 poolShares1;
    uint256 strategyShares1;

    uint256 poolAssets2;
    uint256 poolShares2;
    uint256 strategyShares2;

    function test_realizeYield_success_yieldCap() external {

        /**********************************************************************************************************************************/
        /*** Set the yield cap to match the amount that will be realized                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).setYieldCap(yieldAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldCap(), yieldAssets);

        /**********************************************************************************************************************************/
        /*** Realize yield exactly at the cap                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

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

    function test_realizeYield_success_yieldCooldown() external {

        /**********************************************************************************************************************************/
        /*** Realize yield instantly, starting the cooldown                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldLastRealized(), startingTime);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldCooldown(),     yieldCooldown);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the cooldown and realize yield again                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldCooldown);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldCooldown(), 0);

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldLastRealized(), startingTime + yieldCooldown);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).yieldCooldown(),     yieldCooldown);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + yieldCooldown,
            yieldDeadline:        startingTime + yieldCooldown,
            yieldLastRealized:    startingTime + yieldCooldown,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_yieldAccrual() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield                                                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

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

        /**********************************************************************************************************************************/
        /*** Warp forwards in time                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint32  elapsedDuration = yieldDuration / 3;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the exact deadline                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the deadline                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration + 5 days);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_yieldAccrual_withBootstrapMint() external {

        /**********************************************************************************************************************************/
        /*** Fully unwind the existing (non-bootstrap) strategy so the pool starts clean                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        fundsAsset.transfer(address(0xdead), initialDeployment);

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);
        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, initialShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, initialShares);

        vm.prank(governor);
        poolManager.removeStrategyManager(allocationStrategyManager);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: initialAssets
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

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Deploy a bootstrap-minted strategy in its place and attach the existing pool to it                                         ***/
        /**********************************************************************************************************************************/

        strategyDelegate = makeAddr("bootstrapDelegate");

        uint256 bootstrapAssets = 10e6;
        uint256 bootstrapShares = 10e6;

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: delegateFeeRate,
            strategyProtocolFeeRate_: protocolFeeRate,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapAssets
        });

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        addStrategyManagerToPool(address(poolManager), allocationStrategyManager);
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
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
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

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Schedule yield                                                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
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

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp forwards in time                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint32  elapsedDuration = yieldDuration / 3;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        uint256 poolAssets = initialShares * (bootstrapAssets + initialAssets + realizedYield) / (bootstrapShares + initialShares);
        uint256 deadAssets = bootstrapShares * (bootstrapAssets + initialAssets + realizedYield) / (bootstrapShares + initialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + realizedYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + realizedYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + realizedYield,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the exact deadline                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        poolAssets = initialShares * (bootstrapAssets + initialAssets + netYield) / (bootstrapShares + initialShares);
        deadAssets = bootstrapShares * (bootstrapAssets + initialAssets + netYield) / (bootstrapShares + initialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the deadline                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration + 5 days);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_instantYield() external {

        /**********************************************************************************************************************************/
        /*** Realize yield instantly                                                                                                    ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_scheduleExtended() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards in time                                                                                   ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 10 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Extend the schedule with a longer duration                                                                                 ***/
        /**********************************************************************************************************************************/

        uint32 extendedDuration = 40 days;

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, extendedDuration);

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
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extendedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the extended deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + extendedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extendedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_scheduleShortened() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 3 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Shorten the schedule to a duration shorter than the time remaining                                                         ***/
        /**********************************************************************************************************************************/

        uint32 shortenedDuration = 10 days;

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, shortenedDuration);

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
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + shortenedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the shortened deadline                                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + shortenedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + shortenedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_scheduledUnchanged() external {

        /**********************************************************************************************************************************/
        /*** Realize yield normally and warp forwards                                                                                   ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 7 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize yield again with a zero amount while the duration stays the same                                                   ***/
        /**********************************************************************************************************************************/

        uint32 remainingDuration = yieldDuration - elapsedDuration;

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, remainingDuration);

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
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_flushYield() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 23 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Set the duration to zero and flush all remaining yield                                                                     ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_topUpYield() external {

        /**********************************************************************************************************************************/
        /*** Schedule an initial batch of yield and warp forwards                                                                       ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 25 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize a second batch of yield with a new duration                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 extraYieldAssets = 30_000e6;
        uint32  extraDuration    = 35 days;

        uint256 extraDelegateFee = 600e6;
        uint256 extraProtocolFee = 900e6;
        uint256 extraNetYield    = 28_500e6;

        uint256 combinedScheduledYield = unrealizedYield + extraNetYield;

        realizeYield(allocationUnderlyingStrategy, managedWallet, extraYieldAssets, extraDuration);

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
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extraDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee + extraProtocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the new deadline                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + extraDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extraDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        combinedScheduledYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_yieldIncreased() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 12 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Increase the scheduled yield while keeping the same deadline                                                               ***/
        /**********************************************************************************************************************************/

        uint32  remainingDuration = yieldDuration - elapsedDuration;
        uint256 extraYieldAssets  = 20_000e6;
        uint256 extraDelegateFee  = 400e6;
        uint256 extraProtocolFee  = 600e6;
        uint256 extraNetYield     = 19_000e6;

        uint256 combinedScheduledYield = unrealizedYield + extraNetYield;

        realizeYield(allocationUnderlyingStrategy, managedWallet, extraYieldAssets, remainingDuration);

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
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee + extraProtocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the unchanged deadline and assert the combined yield fully vests                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        combinedScheduledYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_yieldReduced() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 17 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel part of the unrealized yield                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 cancelledAssets = 10_000e6;
        uint256 remainingYield  = unrealizedYield - cancelledAssets;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(cancelledAssets, managedWallet);

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
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield + remainingYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + remainingYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield + remainingYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + remainingYield,
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

    function test_realizeYield_success_yieldCancelled() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 22 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel the entire remaining amount of unrealized yield                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(type(uint256).max, managedWallet);

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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + realizedYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + unrealizedYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_lossRealized() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 17 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the managedWallet's deployed assets                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 lostAssets = 50_000e6;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lostAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lostAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lostAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lostAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lostAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment - lostAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lostAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lostAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lostAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lostAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lostAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment - lostAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lostAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_impairedBeforeSchedule() external {

        /**********************************************************************************************************************************/
        /*** Impair part of the strategy before any yield has been scheduled                                                            ***/
        /**********************************************************************************************************************************/

        uint256 impairedAssets = 100_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, impairedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Schedule yield on top of the pre-existing impairment                                                                       ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
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

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the yield fully vests despite the impairment                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_impairedDuringSchedule() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 11 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Impair part of the strategy                                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 impairedAssets = 150_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, impairedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the yield still fully vests                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_yieldRedeployed() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration   = 15 days;
        uint256 realizedYield     = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield   = netYield - realizedYield;
        uint256 strategyLiquidity = initialAssets - initialDeployment + realizedYield;

        vm.warp(startingTime + elapsedDuration);

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
            availableToWithdraw:   strategyLiquidity,
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
            availableToWithdraw:   strategyLiquidity,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Deploy all assets, including the realized yield                                                                            ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, strategyLiquidity);

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
            availableToWithdraw:   0,
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
            availableToWithdraw:   0,
            totalDeployedAssets:   initialDeployment + strategyLiquidity,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment + strategyLiquidity);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), unrealizedYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + strategyLiquidity);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the full net yield still vests correctly                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   netYield - realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   netYield - realizedYield,
            totalDeployedAssets:   initialDeployment + strategyLiquidity,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment + strategyLiquidity);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), unrealizedYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + strategyLiquidity);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_assetsReturned() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 11 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Return part of the originally deployed principal                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 returnedAssets = 100_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, returnedAssets);

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
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + returnedAssets,
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
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + returnedAssets,
            totalDeployedAssets:   initialDeployment - returnedAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - returnedAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + returnedAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + returnedAssets,
            totalDeployedAssets:   initialDeployment - returnedAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - returnedAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + returnedAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_strategyFunded() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 16 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund the strategy                                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 fundAssets = 100_000e6;

        deposit(lp, fundAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, fundAssets);

        uint256 mintedShares = fundAssets * initialShares / (initialAssets + realizedYield);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield + fundAssets,
            totalSupply:        initialShares + mintedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares + mintedShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield + fundAssets,
            shares:           initialShares + mintedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + fundAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + fundAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + fundAssets,
            totalSupply:        initialShares + mintedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares + mintedShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + fundAssets,
            shares:           initialShares + mintedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + fundAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + fundAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_yieldWithdrawn() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 20 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Redeem as many shares as possible                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 strategyLiquidity  = initialAssets - initialDeployment + realizedYield;
        uint256 redeemableShares   = strategyLiquidity * initialShares / (initialAssets + realizedYield);
        uint256 withdrawableAssets = redeemableShares * (initialAssets + realizedYield) / initialShares;

        assertApproxEqAbs(strategyLiquidity, withdrawableAssets, 1);

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, redeemableShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, redeemableShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: withdrawableAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares - redeemableShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield - withdrawableAssets,
            availableToWithdraw:   strategyLiquidity - withdrawableAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield - withdrawableAssets,
            shares:           initialShares - redeemableShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield - withdrawableAssets,
            availableToWithdraw:   strategyLiquidity - withdrawableAssets,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - withdrawableAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: withdrawableAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares - redeemableShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield - withdrawableAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield - withdrawableAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield - withdrawableAssets,
            shares:           initialShares - redeemableShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield - withdrawableAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield - withdrawableAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield - withdrawableAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_feesUpdated() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 9 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Update the fee rates mid vesting, which has no effect on the already-scheduled yield                                       ***/
        /**********************************************************************************************************************************/

        uint32 newDelegateFeeRate = 0.05e6;  // 5%
        uint32 newProtocolFeeRate = 0.07e6;  // 7%

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, newDelegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, newProtocolFeeRate);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Flush the remaining schedule before its natural deadline, proving the flushed amount is unaffected by the new fee rates    ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, 0, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize brand new yield, proving the new fee rates apply going forward                                                     ***/
        /**********************************************************************************************************************************/

        uint256 extraYieldAssets = 40_000e6;
        uint256 extraDelegateFee = 2_000e6;
        uint256 extraProtocolFee = 2_800e6;
        uint256 extraNetYield    = 35_200e6;

        vm.warp(startingTime + elapsedDuration + yieldCooldown);

        realizeYield(allocationUnderlyingStrategy, managedWallet, extraYieldAssets, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: extraNetYield,
            yieldStart:           startingTime + elapsedDuration + yieldCooldown,
            yieldDeadline:        startingTime + elapsedDuration + yieldCooldown,
            yieldLastRealized:    startingTime + elapsedDuration + yieldCooldown,
            realizedYield:        extraNetYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_poolsVestTogether() external {

        /**********************************************************************************************************************************/
        /*** Fund a second pool into the same strategy manager, so both pools share the same underlying allocation strategy             ***/
        /**********************************************************************************************************************************/

        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        uint256 initialAssets1 = initialAssets;
        uint256 initialShares1 = initialShares;
        uint256 initialAssets2 = 500_000e6;
        uint256 initialShares2 = 500_000e6;

        uint256 totalAssets = initialAssets1 + initialAssets2;
        uint256 totalShares = initialShares1 + initialShares2;

        deposit(pool2, makeAddr("lp2"), initialAssets2);
        fundStrategyManager(poolManager2, allocationStrategyManager, initialAssets2);
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        initialAssets1,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
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
            poolManager:      poolManager1,
            assets:           initialAssets1,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           initialAssets2,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the vested yield splits between both pools in proportion to their shares                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        uint256 finalAum         = totalAssets + netYield;
        uint256 firstPoolAssets  = initialShares1 * finalAum / totalShares;
        uint256 secondPoolAssets = initialShares2 * finalAum / totalShares;

        assertPoolState({
            pool:               pool1,
            totalAssets:        firstPoolAssets,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondPoolAssets,
            totalSupply:        initialShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           firstPoolAssets,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           secondPoolAssets,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_realizeYield_success_poolJoinsMidVesting() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards, before the 2nd pool exists                                                               ***/
        /**********************************************************************************************************************************/

        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        poolAssets1     = initialAssets;
        poolShares1     = initialShares;
        strategyShares1 = initialShares;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 13 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1 + realizedYield,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares1,
            totalPendingShares:    0,
            assetsUnderManagement: poolAssets1 + realizedYield,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1 + realizedYield,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolAssets1 + realizedYield,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolAssets1 - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund a 2nd pool into the same strategy manager mid vesting                                                                 ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        poolAssets2     = 500_000e6;
        poolShares2     = poolAssets2;
        strategyShares2 = poolAssets2 * strategyShares1 / (poolAssets1 + realizedYield);

        deposit(pool2, makeAddr("lp2"), poolAssets2);
        fundStrategyManager(poolManager2, allocationStrategyManager, poolAssets2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1 + realizedYield,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        poolAssets2 - 1,  // Rounding error
            totalSupply:        poolShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares1 + strategyShares2,
            totalPendingShares:    0,
            assetsUnderManagement: poolAssets1 + realizedYield + poolAssets2,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield + poolAssets2,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1 + realizedYield,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           poolAssets2 - 1,  // Rounding error
            shares:           strategyShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolAssets1 + realizedYield + poolAssets2,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield + poolAssets2,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolAssets1 - initialDeployment + netYield + poolAssets2);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the remaining yield splits by shares held from the moment the 2nd pool joined              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        uint256 aum = poolAssets1 + netYield + poolAssets2;

        poolAssets1 = strategyShares1 * aum / (strategyShares1 + strategyShares2);
        poolAssets2 = strategyShares2 * aum / (strategyShares1 + strategyShares2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        poolAssets2,
            totalSupply:        poolShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares1 + strategyShares2,
            totalPendingShares:    0,
            assetsUnderManagement: aum,
            availableToWithdraw:   aum - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           poolAssets2,
            shares:           strategyShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aum,
            availableToWithdraw:   aum - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aum - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}
