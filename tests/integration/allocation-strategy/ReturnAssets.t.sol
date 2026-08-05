// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyReturnAssetsTestBase is AllocationStrategyTestBase {

    uint256 initialDeployment = 400_000e6;
    uint256 initialLiquidity  = 1_000_000e6;

    function setUp() public override {
        super.setUp();

        // Fund pool and strategy, then deploy assets so there is an existing position to return from.
        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialLiquidity);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            recordedAssets:        initialLiquidity - initialDeployment,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}

contract AllocationStrategyReturnAssetsFailureTests is AllocationStrategyReturnAssetsTestBase {

    function test_returnAssets_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(initialDeployment, managedWallet, "");
    }

    function test_returnAssets_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(initialDeployment, managedWallet, "");
    }

    function test_returnAssets_revert_notManagedWallet() external {
        address notManagedWallet = makeAddr("notManagedWallet");

        vm.prank(notManagedWallet);
        vm.expectRevert("MAS:NOT_MAPLE_MANAGED_WALLET");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(initialDeployment, managedWallet, "");
    }

    function test_returnAssets_revert_notAllowed() external {
        setPermissions({
            strategy_:        allocationUnderlyingStrategy,
            account_:         managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: false,
            canRealizeYield_: true
        });

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RA:NOT_ALLOWED");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(1, managedWallet, "");
    }

    function test_returnAssets_revert_zeroAssets() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:RA:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(0, managedWallet, "");
    }

    function test_returnAssets_revert_exceedsAssets_boundary() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:RA:EXCEEDS_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(initialDeployment + 1, managedWallet, "");
    }

    function test_returnAssets_revert_exceedsAssets_afterLossRecognition() external {
        uint256 lossAmount = 100_000e6;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RA:EXCEEDS_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(initialDeployment - lossAmount + 1, managedWallet, "");
    }

    function test_returnAssets_revert_exceedsAssets_nothingDeployed() external {
        address idleManagedWallet = makeAddr("idleManagedWallet");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   idleManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   0
        });

        vm.prank(idleManagedWallet);
        vm.expectRevert("MAS:RA:EXCEEDS_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(1, idleManagedWallet, "");
    }

}

contract AllocationStrategyReturnAssetsSuccessTests is AllocationStrategyReturnAssetsTestBase {

    function test_returnAssets_success_partialAmount() external {

        /**********************************************************************************************************************************/
        /*** Return a portion of the deployed assets                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 150_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            recordedAssets:        initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - returnAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_fullAmount() external {

        /**********************************************************************************************************************************/
        /*** Return all of the deployed assets                                                                                          ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

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
            recordedAssets:        initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_freesDeploymentCapForRedeploy() external {

        /**********************************************************************************************************************************/
        /*** Return part of the deployed assets, freeing up cap headroom                                                                ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 200_000e6;

        setDeploymentCap(allocationUnderlyingStrategy, managedWallet, initialDeployment);
        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            recordedAssets:        initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - returnAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Redeploy the freed amount, proving the cap headroom was freed                                                              ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            recordedAssets:        initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment + returnAmount);
    }

    function test_returnAssets_success_freesLiquidityForWithdrawal() external {

        /**********************************************************************************************************************************/
        /*** Request and process redemption of the assets that were never deployed                                                      ***/
        /**********************************************************************************************************************************/

        uint256 idleLiquidity = initialLiquidity - initialDeployment;

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, idleLiquidity);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, idleLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: idleLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialDeployment,
            totalPendingShares:    0,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialDeployment,
            shares:           initialDeployment,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(address(pool)),                idleLiquidity);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed assets, making them available to withdraw again                                                        ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: idleLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialDeployment,
            totalPendingShares:    0,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialDeployment,
            shares:           initialDeployment,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   initialDeployment,
            recordedAssets:        initialDeployment,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),                idleLiquidity);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Request and process redemption of the newly returned assets                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, initialDeployment);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
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
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),                initialLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_onBehalfOfDifferentCaller() external {

        /**********************************************************************************************************************************/
        /*** Return assets on behalf of another wallet address                                                                          ***/
        /**********************************************************************************************************************************/

        address managedWallet2 = makeAddr("managedWallet2");
        uint256 returnAmount   = 150_000e6;

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
        returnAssets(allocationUnderlyingStrategy, managedWallet2, managedWallet, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            recordedAssets:        initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  initialDeployment - returnAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2),               0);
    }

    function test_returnAssets_success_afterOnBehalfOfPermissionRevoked() external {

        /**********************************************************************************************************************************/
        /*** Return the assets with another wallet address                                                                              ***/
        /**********************************************************************************************************************************/

        address managedWallet2 = makeAddr("managedWallet2");

        setPermissions({
            strategy_:        allocationUnderlyingStrategy,
            account_:         managedWallet,
            canDeployAssets_: false,
            canReturnAssets_: false,
            canRealizeYield_: false
        });
        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
        returnAssets(allocationUnderlyingStrategy, managedWallet2, managedWallet, initialDeployment);

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
            recordedAssets:        initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2),               0);
    }

    function test_returnAssets_success_withYield() external {

        /**********************************************************************************************************************************/
        /*** Warp some time during the vesting period                                                                                   ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 6 days;

        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, totalDuration);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
            recordedAssets:        initialLiquidity - initialDeployment + yieldAssets,
            totalDeployedAssets:   initialDeployment,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + yieldAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed principal while yield is still mid-vesting                                                             ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

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
            recordedAssets:        initialLiquidity + yieldAssets,
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
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_withYieldAndFees() external {

        /**********************************************************************************************************************************/
        /*** Set the strategy fee rates and realize yield, paying the delegate and protocol fees upfront                                ***/
        /**********************************************************************************************************************************/

        uint32 delegateFeeRate = 0.1e6;   // 10% of yield
        uint32 protocolFeeRate = 0.05e6;  // 5% of yield

        uint256 yieldAssets = 200_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 6 days;

        uint256 delegateFee = 20_000e6;   // 200_000e6 * 0.1e6  / 1e6
        uint256 protocolFee = 10_000e6;   // 200_000e6 * 0.05e6 / 1e6
        uint256 netYield    = 170_000e6;  // 200_000e6 - 20_000e6 - 10_000e6

        uint256 realizedYield = netYield * elapsedDuration / totalDuration;

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            recordedAssets:        initialLiquidity - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp partway through vesting so only part of the net yield is realized                                                     ***/
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
            recordedAssets:        initialLiquidity - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Return the deployed principal while the net yield is still mid-vesting                                                     ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

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
            recordedAssets:        initialLiquidity + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_returnAssets_success_withImpairment() external {

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            recordedAssets:        initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed assets while the strategy remains impaired                                                             ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, initialDeployment);

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
            recordedAssets:        initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_afterLossRecognition() external {

        /**********************************************************************************************************************************/
        /*** Recognize a loss on part of the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 100_000e6;

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            recordedAssets:        initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the remaining deployed assets, net of the recognized loss                                                           ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = initialDeployment - lossAmount;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, returnAmount);

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
            availableToWithdraw:   initialLiquidity - lossAmount,
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
            availableToWithdraw:   initialLiquidity - lossAmount,
            recordedAssets:        initialLiquidity - lossAmount,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - lossAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_multipleReturnsAccumulate() external {

        /**********************************************************************************************************************************/
        /*** First partial return                                                                                                       ***/
        /**********************************************************************************************************************************/

        uint256 firstReturn = 100_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, firstReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn,
            recordedAssets:        initialLiquidity - initialDeployment + firstReturn,
            totalDeployedAssets:   initialDeployment - firstReturn,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - firstReturn);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + firstReturn);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Second partial return accumulates on top of the first                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 secondReturn = 75_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, secondReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn + secondReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn + secondReturn,
            recordedAssets:        initialLiquidity - initialDeployment + firstReturn + secondReturn,
            totalDeployedAssets:   initialDeployment - firstReturn - secondReturn,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - firstReturn - secondReturn);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment + firstReturn + secondReturn);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_returnAssets_success_multipleManagedWalletAddresses() external {

        /**********************************************************************************************************************************/
        /*** Deploy assets from another wallet address                                                                                  ***/
        /**********************************************************************************************************************************/

        address managedWallet2   = makeAddr("managedWallet2");
        uint256 secondDeployment = 250_000e6;

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
        deployAssets(allocationUnderlyingStrategy, managedWallet2, secondDeployment);

        /**********************************************************************************************************************************/
        /*** First wallet address returns its share, second wallet address's position is untouched                                      ***/
        /**********************************************************************************************************************************/

        uint256 firstReturn = 100_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, firstReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn,
            recordedAssets:        initialLiquidity - initialDeployment - secondDeployment + firstReturn,
            totalDeployedAssets:   initialDeployment + secondDeployment - firstReturn,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  initialDeployment - firstReturn);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), secondDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialLiquidity - initialDeployment - secondDeployment + firstReturn);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2),               secondDeployment);

        /**********************************************************************************************************************************/
        /*** Second wallet address returns its share independently, accounted for separately from the first                             ***/
        /**********************************************************************************************************************************/

        uint256 secondReturn = 200_000e6;

        returnAssets(allocationUnderlyingStrategy, managedWallet2, managedWallet2, secondReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn,
            recordedAssets:        initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn,
            totalDeployedAssets:   initialDeployment + secondDeployment - firstReturn - secondReturn,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  initialDeployment - firstReturn);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), secondDeployment - secondReturn);

        assertEq(
            fundsAsset.balanceOf(allocationUnderlyingStrategy),
            initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn
        );

        assertEq(fundsAsset.balanceOf(managedWallet),  initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2), secondDeployment);
    }

}
