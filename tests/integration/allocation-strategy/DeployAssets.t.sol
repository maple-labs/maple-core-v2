// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyDeployAssetsFailureTests is AllocationStrategyTestBase {

    uint256 deployAmount     = 400_000e6;
    uint256 initialLiquidity = INITIAL_LIQUIDITY;

    function setUp() public override {
        super.setUp();

        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialLiquidity);
    }

    function test_deployAssets_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_notManagedWallet() external {
        address notManagedWallet = makeAddr("notManagedWallet");

        vm.prank(notManagedWallet);
        vm.expectRevert("MAS:NOT_MAPLE_MANAGED_WALLET");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_notAllowed() external {
        address restrictedManagedWallet = makeAddr("restrictedManagedWallet");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   restrictedManagedWallet,
            canDeployAssets_: false,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        vm.prank(restrictedManagedWallet);
        vm.expectRevert("MAS:DA:NOT_ALLOWED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_zeroAssets() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(0, "");
    }

    function test_deployAssets_revert_insufficientAssets_boundary() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(initialLiquidity + 1, "");
    }

    function test_deployAssets_revert_insufficientAssets_unvestedYield() external {
        uint32 elapsedDuration = 7 days;
        uint32 totalDuration   = 10 days;

        uint256 yieldAssets   = 100_000e6;
        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, totalDuration);

        vm.warp(startingTime + elapsedDuration);
        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(initialLiquidity + realizedYield + 1, "");
    }

    function test_deployAssets_revert_capExceeded_zeroCap() external {
        address zeroCapManagedWallet = makeAddr("zeroCapManagedWallet");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   zeroCapManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   0
        });

        vm.prank(zeroCapManagedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(1, "");
    }

    function test_deployAssets_revert_capExceeded_boundary() external {
        address cappedManagedWallet = makeAddr("cappedManagedWallet");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   cappedManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount - 1
        });

        vm.prank(cappedManagedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_capExceeded_withPriorDeployment() external {
        address cappedManagedWallet = makeAddr("cappedManagedWallet");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   cappedManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        vm.prank(cappedManagedWallet);
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount - 1, "");

        vm.prank(cappedManagedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(2, "");
    }

    function test_deployAssets_revert_transferFailed() external {
        fundsAsset.__failWhenCalledBy(allocationUnderlyingStrategy);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:TRANSFER_FAILED");
        IAllocationStrategy(allocationUnderlyingStrategy).deployAssets(deployAmount, "");
    }

}

contract AllocationStrategyDeployAssetsSuccessTests is AllocationStrategyTestBase {

    uint256 initialLiquidity = INITIAL_LIQUIDITY;

    function setUp() public override {
        super.setUp();

        // Fund pool and strategy.
        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialLiquidity);

        // Initial assertions.
        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
    }

    function test_deployAssets_success_partialAmount() external {
        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_fullAvailableAmount() external {
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   0,
            totalDeployedAssets:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialLiquidity);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialLiquidity);
    }

    function test_deployAssets_success_exactDeploymentCapBoundary() external {
        address cappedManagedWallet = makeAddr("cappedManagedWallet");
        uint256 deployAmount        = 400_000e6;

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   cappedManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Deploy exactly up to the deployment cap                                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, cappedManagedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount);
    }

    function test_deployAssets_success_multipleDeploymentsAccumulate() external {

        /**********************************************************************************************************************************/
        /*** Step 1: First deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 250_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), firstAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Second deployment accumulates on top of the first                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 150_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), firstAmount + secondAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount + secondAmount);
    }

    function test_deployAssets_success_multipleManagedWalletAddresses() external {
        address managedWallet2 = makeAddr("managedWallet2");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Step 1: First wallet address deploys its share                                                                             ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 300_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  firstAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet2),               0);

        /**********************************************************************************************************************************/
        /*** Step 2: Second wallet address deploys independently, accounted for separately from the first                               ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 120_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet2, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  firstAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), secondAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet2),               secondAmount);
    }

    function test_deployAssets_success_afterReturnAssetsFreesCap() external {
        address cappedManagedWallet = makeAddr("cappedManagedWallet");
        uint256 deployAmount        = 400_000e6;

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   cappedManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy up to the full deployment cap                                                                               ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, cappedManagedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Return part of the deployed assets, freeing up cap headroom                                                        ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 100_000e6;

        returnAssets(allocationUnderlyingStrategy, cappedManagedWallet, cappedManagedWallet, returnAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount + returnAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount + returnAmount,
            totalDeployedAssets:   deployAmount - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount - returnAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount + returnAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again, reusing the freed-up cap headroom                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, cappedManagedWallet, returnAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount + returnAmount);
    }

    function test_deployAssets_success_afterLossRecognitionFreesCap() external {
        address cappedManagedWallet = makeAddr("cappedManagedWallet");
        uint256 deployAmount        = 400_000e6;

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   cappedManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy up to the full deployment cap                                                                               ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, cappedManagedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Recognize a loss on the deployed assets, freeing up cap headroom                                                   ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 100_000e6;

        recognizeLoss(allocationUnderlyingStrategy, cappedManagedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again, reusing the freed-up cap headroom                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, cappedManagedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount - lossAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(cappedManagedWallet), deployAmount - lossAmount + lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount - lossAmount);
        assertEq(fundsAsset.balanceOf(cappedManagedWallet),          deployAmount + lossAmount);
    }

    function test_deployAssets_success_scheduledYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 duration = 10 days;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_partiallyRealizedYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets  = 100_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 7 days;

        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for partial accrual                                                                                           ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + realizedYield,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + realizedYield,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + realizedYield,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + realizedYield,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_fullyRealizedYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration = 10 days;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait until full accrual                                                                                            ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_pastYieldDeadline() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration    = 10 days;
        uint32 timePastDeadline = 3 days;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait past full accrual                                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + totalDuration + timePastDeadline);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_impairment() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Impair assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 impairAmount = 250_000e6;

        impairAllocationStrategy(allocationUnderlyingStrategy, impairAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      impairAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployAmount);
    }

    function test_deployAssets_success_afterLossRecognition() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 400_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), firstAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Recognize a loss on the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 150_000e6;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), firstAmount - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again after the loss has been recognized                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 100_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount - lossAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), firstAmount - lossAmount + secondAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                firstAmount + secondAmount);
    }

}
