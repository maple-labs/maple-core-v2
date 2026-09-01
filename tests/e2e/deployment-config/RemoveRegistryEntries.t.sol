// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Action, ActionType } from "../../../modules/strategy-manager/contracts/interfaces/IMapleLiquidityRouter.sol";

import {
    AllocationStrategyInitializerParams,
    IMapleProxyFactory,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract RemoveRegistryEntriesTests is AllocationStrategyTestBase {

    address freshStrategyDelegate = makeAddr("freshStrategyDelegate");

    uint256 poolLiquidity    = 1_000_000e6;
    uint256 redemptionShares = 400_000e6;
    uint256 strategyFunding  = 600_000e6;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, strategyFunding);
        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, redemptionShares);
    }

    function test_removeLiquidityRouter_success() external {
        uint256 additionalFunding       = 100_000e6;
        uint256 cancelledShares         = 100_000e6;
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding;          // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 pendingAfterCancel      = redemptionShares - cancelledShares;       // 400_000e6 - 100_000e6 = 300_000e6
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares;        // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets;  // 1_000_000e6 - 200_000e6 = 800_000e6

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          redemptionShares,
            strategyData:    ""
        });

        /**********************************************************************************************************************************/
        /*** Assert the registered Router and funded position                                                                           ***/
        /**********************************************************************************************************************************/

        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter)), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the Router and confirm the position remains                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter), false);

        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter)), false);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm all Router-originated operations stop                                                                              ***/
        /**********************************************************************************************************************************/

        actions[0].actionType = ActionType.FUND_STRATEGY;
        actions[0].amount     = additionalFunding;

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        liquidityRouter.executeActions(actions, block.timestamp);

        actions[0].actionType = ActionType.REQUEST_REDEEM;
        actions[0].amount     = cancelledShares;

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        liquidityRouter.executeActions(actions, block.timestamp);

        actions[0].actionType = ActionType.CANCEL_REDEMPTION;

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        liquidityRouter.executeActions(actions, block.timestamp);

        actions[0].actionType = ActionType.PROCESS_REDEMPTION;
        actions[0].amount     = redemptionShares;

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        liquidityRouter.executeActions(actions, block.timestamp);

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).cancelRedemption(address(poolManager), cancelledShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    pendingAfterCancel,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    pendingAfterCancel,
            unrealizedLosses: 0
        });

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).requestRedeem(address(poolManager), cancelledShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Restore the Router and settle the original position                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter), true);

        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter)), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            recordedAssets:        remainingStrategyAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_removePoolManagerFactory_success() external {
        uint256 additionalFunding       = 100_000e6;
        uint256 additionalPendingShares = 100_000e6;
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding;          // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 poolManagerCap          = 1_000_000e6;
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares;        // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets;  // 1_000_000e6 - 200_000e6 = 800_000e6

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          redemptionShares,
            strategyData:    ""
        });

        /**********************************************************************************************************************************/
        /*** Assert the registered Pool Manager factory and funded position                                                             ***/
        /**********************************************************************************************************************************/

        assertEq(globals.isInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the Pool Manager factory and confirm the position remains                                                           ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        assertEq(globals.isInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory), false);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm all Strategy Manager operations requiring a valid Pool Manager stop                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), additionalFunding, "");

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:RR:INVALID_PM");
        IStrategyManager(allocationStrategyManager).requestRedeem(address(poolManager), additionalPendingShares);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:CR:INVALID_PM");
        IStrategyManager(allocationStrategyManager).cancelRedemption(address(poolManager), additionalPendingShares);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:PR:INVALID_PM");
        liquidityRouter.executeActions(actions, block.timestamp);

        vm.prank(operationalAdmin);
        vm.expectRevert("MSM:SPMC:INVALID_PM");
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), poolManagerCap);

        /**********************************************************************************************************************************/
        /*** Restore the Pool Manager factory and settle the original position                                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, true);

        assertEq(globals.isInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            recordedAssets:        remainingStrategyAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_removeStrategyManagerFactory_success() external {
        uint256 additionalFunding       = 100_000e6;
        uint256 cancelledShares         = 100_000e6;
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding;          // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 pendingAfterCancel      = redemptionShares - cancelledShares;       // 400_000e6 - 100_000e6 = 300_000e6
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares;        // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets;  // 1_000_000e6 - 200_000e6 = 800_000e6

        bytes memory deploymentData = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Fresh Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          redemptionShares,
            strategyData:    ""
        });

        vm.prank(operationalAdmin);
        globals.setValidStrategyDelegate(freshStrategyDelegate, true);

        /**********************************************************************************************************************************/
        /*** Assert the registered Strategy Manager factory and funded position                                                         ***/
        /**********************************************************************************************************************************/

        assertEq(globals.isInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the Strategy Manager factory and confirm the position remains                                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        assertEq(globals.isInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory), false);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm deployment, Router dispatch and Pool funding stop while direct redemption management remains                       ***/
        /**********************************************************************************************************************************/

        vm.prank(freshStrategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SM_FACTORY");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:INVALID_SM_FACTORY");
        liquidityRouter.executeActions(actions, block.timestamp);

        vm.prank(liquidityBot);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), additionalFunding, "");

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).cancelRedemption(address(poolManager), cancelledShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    pendingAfterCancel,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    pendingAfterCancel,
            unrealizedLosses: 0
        });

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).requestRedeem(address(poolManager), cancelledShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Restore the Strategy Manager factory, retry deployment and settle the original position                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, true);

        assertEq(globals.isInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        vm.prank(freshStrategyDelegate);
        (
            address freshStrategyManager,
            address freshUnderlyingStrategy
        ) = strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(freshStrategyManager),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(freshUnderlyingStrategy), true);
        assertEq(IStrategyManager(freshStrategyManager).underlyingStrategy(),                       freshUnderlyingStrategy);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            recordedAssets:        remainingStrategyAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_removeUnderlyingStrategyFactory_success() external {
        uint256 processedSharesWhileRemoved = 100_000e6;
        uint256 pendingAfterProcess         = redemptionShares - processedSharesWhileRemoved;  // 400_000e6 - 100_000e6 = 300_000e6
        uint256 strategyAssetsAfterProcess  = 500_000e6;
        uint256 strategyShares              = 600_000e6;
        uint256 strategySharesAfterProcess  = strategyShares - processedSharesWhileRemoved;    // 600_000e6 - 100_000e6 = 500_000e6
        uint256 remainingStrategyAssets     = 200_000e6;
        uint256 remainingStrategyShares     = strategyShares - redemptionShares;               // 600_000e6 - 400_000e6 = 200_000e6

        bytes memory deploymentData = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Restored Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          pendingAfterProcess,
            strategyData:    ""
        });

        vm.prank(operationalAdmin);
        globals.setValidStrategyDelegate(freshStrategyDelegate, true);

        /**********************************************************************************************************************************/
        /*** Assert the registered underlying Strategy factory and funded position                                                      ***/
        /**********************************************************************************************************************************/

        assertEq(globals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - strategyFunding  // 400_000e6
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the underlying Strategy factory and confirm the position remains                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory, false);

        assertEq(globals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory), false);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - strategyFunding  // 400_000e6
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            recordedAssets:        strategyFunding,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm only new deployment stops while the existing position remains operational                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(freshStrategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_FACTORY");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), processedSharesWhileRemoved, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - strategyAssetsAfterProcess  // 500_000e6
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: strategyAssetsAfterProcess,
            availableToWithdraw:   strategyAssetsAfterProcess,
            recordedAssets:        strategyAssetsAfterProcess,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategySharesAfterProcess,
            totalPendingShares:    pendingAfterProcess,
            assetsUnderManagement: strategyAssetsAfterProcess,
            availableToWithdraw:   strategyAssetsAfterProcess,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssetsAfterProcess,
            shares:           strategySharesAfterProcess,
            pendingShares:    pendingAfterProcess,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Restore the underlying Strategy factory and retry deployment                                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory, true);

        assertEq(globals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory), true);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).factory(),            strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - strategyAssetsAfterProcess  // 500_000e6
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategySharesAfterProcess,
            totalPendingShares:    pendingAfterProcess,
            assetsUnderManagement: strategyAssetsAfterProcess,
            availableToWithdraw:   strategyAssetsAfterProcess,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssetsAfterProcess,
            shares:           strategySharesAfterProcess,
            pendingShares:    pendingAfterProcess,
            unrealizedLosses: 0
        });

        vm.prank(freshStrategyDelegate);
        (
            address freshStrategyManager,
            address freshUnderlyingStrategy
        ) = strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(freshStrategyManager),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(freshUnderlyingStrategy), true);
        assertEq(IStrategyManager(freshStrategyManager).underlyingStrategy(),                       freshUnderlyingStrategy);

        assertEq(poolManager.isStrategyManager(allocationStrategyManager),         true);
        assertEq(IStrategyManager(allocationStrategyManager).underlyingStrategy(), allocationUnderlyingStrategy);

        /**********************************************************************************************************************************/
        /*** Settle the original position without replacing it                                                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - remainingStrategyAssets  // 800_000e6
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            recordedAssets:        remainingStrategyAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
