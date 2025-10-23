// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IBitcoinStrategy,
    IERC20,
    IPoolPermissionManager,
    Permit
} from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract SyrupBTCScenarioTests is ProtocolActions, TestBaseWithAssertions {

    address lp = makeAddr("lp");

    uint256 initialDepositAmount = 100e8;

    function setUp() public override {
        initialStrategiesCount = 2;

        _setupBitcoinPool();

        depositInSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), initialDepositAmount);
    }

    function test_scenario_aumGoesDown_multipleDefaults_multipleStrategies() public {
        address strategy1 = poolManager.strategyList(0);
        address strategy2 = poolManager.strategyList(1);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(assetControllerProxy);
        uint256 poolCompositeTokenBalanceBefore     = IERC20(compositeTokenProxy).balanceOf(address(pool));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();

        uint256 amountToDeployStrategy1 = 50e8;
        uint256 amountToDeployStrategy2 = 40e8;

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy1                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(strategy1).deploy(address(depositAsset), amountToDeployStrategy1);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeployStrategy1,
            assetControllerBalance:    controllerDepositAssetBalanceBefore - amountToDeployStrategy1,
            poolTotalAssets:           poolTotalAssetsBefore,
            poolCompositeTokenBalance: poolCompositeTokenBalanceBefore - amountToDeployStrategy1
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeployStrategy1,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy funds into strategy2                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(strategy2).deploy(address(depositAsset), amountToDeployStrategy2);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeployStrategy1 + amountToDeployStrategy2,
            assetControllerBalance:    controllerDepositAssetBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2,
            poolTotalAssets:           poolTotalAssetsBefore,
            poolCompositeTokenBalance: poolCompositeTokenBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeployStrategy1,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeployStrategy2,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 amountToDefaultStrategy1 = 20e8;

        /**********************************************************************************************************************************/
        /*** Step 3: Partially default strategy1                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IBitcoinStrategy(strategy1).setDefault(amountToDefaultStrategy1);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeployStrategy1 + amountToDeployStrategy2,
            assetControllerBalance:    controllerDepositAssetBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2,
            poolTotalAssets:           poolTotalAssetsBefore - amountToDefaultStrategy1,
            poolCompositeTokenBalance: poolCompositeTokenBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeployStrategy1 - amountToDefaultStrategy1,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeployStrategy2,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 amountToDefaultStrategy2 = 30e8;

        /**********************************************************************************************************************************/
        /*** Step 4: Partially default strategy2                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IBitcoinStrategy(strategy2).setDefault(amountToDefaultStrategy2);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeployStrategy1 + amountToDeployStrategy2,
            assetControllerBalance:    controllerDepositAssetBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2,
            poolTotalAssets:           poolTotalAssetsBefore - amountToDefaultStrategy1 - amountToDefaultStrategy2,
            poolCompositeTokenBalance: poolCompositeTokenBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeployStrategy1 - amountToDefaultStrategy1,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeployStrategy2 - amountToDefaultStrategy2,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Fully default strategy1                                                                                            ***/
        /**********************************************************************************************************************************/

        amountToDefaultStrategy1 = IBitcoinStrategy(strategy1).assetsUnderManagement();

        vm.prank(poolDelegate);
        IBitcoinStrategy(strategy1).setDefault(amountToDefaultStrategy1);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeployStrategy1 + amountToDeployStrategy2,
            assetControllerBalance:    controllerDepositAssetBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2,
            poolTotalAssets:           poolTotalAssetsBefore - amountToDeployStrategy1 - amountToDefaultStrategy2,
            poolCompositeTokenBalance: poolCompositeTokenBalanceBefore - amountToDeployStrategy1 - amountToDeployStrategy2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeployStrategy2 - amountToDefaultStrategy2,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_addNewStrategy_whileCapitalIsDeployedInPreviousStrategies() public {
        address strategy1 = poolManager.strategyList(0);
        address strategy2 = poolManager.strategyList(1);

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy1 and strategy2                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 amountToDeploy = pool.totalAssets() / 2;

        vm.startPrank(strategyManager);
        IBitcoinStrategy(strategy1).deploy(address(depositAsset), amountToDeploy);
        IBitcoinStrategy(strategy2).deploy(address(depositAsset), amountToDeploy);
        vm.stopPrank();

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy * 2,
            assetControllerBalance:    initialDepositAmount - amountToDeploy * 2,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy * 2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Add new strategy                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        address strategy3 = poolManager.addStrategy(bitcoinStrategyFactory, "");

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy3,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Whitelist strategy3                                                                                                ***/
        /**********************************************************************************************************************************/

        vm.startPrank(governor);
        globals.setValidInstanceOf("BITCOIN_STRATEGY", strategy3, true);

        address[] memory addresses = new address[](1);
        bool[]    memory allowed   = new bool[](1);

        addresses[0] = strategy3;
        allowed[0]   = true;

        compositeAsset.allowAddresses(addresses, allowed);
        assetController.setStrategies(addresses, allowed);

        addresses[0] = strategyManager;
        allowed[0]   = true;

        IBitcoinStrategy(strategy3).setPermissions(addresses, allowed, allowed, allowed);
        IBitcoinStrategy(strategy3).setAssetController(address(depositAsset), address(assetController));
        vm.stopPrank();

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy3,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Reconcile strategy2 and deploy those funds into strategy3                                                          ***/
        /**********************************************************************************************************************************/

        uint256 amountToReconcile = amountToDeploy / 4;

        vm.startPrank(strategyManager);
        depositAsset.approve(address(strategy2), amountToReconcile);
        IBitcoinStrategy(strategy2).reconcile(address(depositAsset), amountToReconcile);
        IBitcoinStrategy(strategy3).deploy(address(depositAsset), amountToReconcile);
        vm.stopPrank();

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy * 2,
            assetControllerBalance:    initialDepositAmount - amountToDeploy * 2,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy * 2
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeploy - amountToReconcile,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy3,
            assetsUnderManagement: amountToReconcile,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_depositDuringScheduledYieldOnStrategy_exchangeRateIsEffected() public {
        address targetStrategy = poolManager.strategyList(0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 yieldToSchedule = pool.totalAssets(); // Double the total assets
        uint256 yieldDuration   = 100 days;

        uint256 snapshot = vm.snapshot();

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldToSchedule, uint32(startingTime + yieldDuration));

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for quarter of the schedule and deposit assets                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 4);

        uint256 depositAmount                         = 50e8;
        uint256 sharesReceivedOnDepositDuringSchedule = depositInSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), depositAmount);

        uint256 expectedExchangeRate    = 1.25e8;
        uint256 expectedSharesToReceive = depositAmount * 1e8 / expectedExchangeRate;

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount + depositAmount,
            poolTotalAssets:           initialDepositAmount + depositAmount + yieldToSchedule / 4,
            poolCompositeTokenBalance: initialDepositAmount + depositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 4,
            accruedYield:          yieldToSchedule / 4,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(sharesReceivedOnDepositDuringSchedule, expectedSharesToReceive);

        /**********************************************************************************************************************************/
        /*** Step 3: Revert to snapshot and deposit assets without schedule                                                             ***/
        /**********************************************************************************************************************************/

        // Here we are reverting to this snapshot so we can execute deposit without schedule and compare state with and without schedule.
        vm.revertTo(snapshot);
        uint256 sharesReceivedOnDepositNoSchedule = depositInSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), depositAmount);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount + depositAmount,
            poolTotalAssets:           initialDepositAmount + depositAmount,
            poolCompositeTokenBalance: initialDepositAmount + depositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(sharesReceivedOnDepositNoSchedule, depositAmount);
    }

    function test_scenario_defaultProperlyDuringSchedule() public {
        address targetStrategy  = poolManager.strategyList(0);
        uint256 amountToDeploy  = pool.totalAssets();
        uint256 yieldToSchedule = 50e8;
        uint256 amountToDefault = 60e8;
        uint256 yieldDuration   = 100 days;
        uint32  deadline        = uint32(startingTime + yieldDuration);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).deploy(address(depositAsset), amountToDeploy);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldToSchedule, deadline);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        vm.warp(startingTime + yieldDuration / 3);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy + yieldToSchedule / 3,
            accruedYield:          yieldToSchedule / 3,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Remove schedule                                                                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(0, 0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy + yieldToSchedule / 3,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Partially default strategy                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IBitcoinStrategy(targetStrategy).setDefault(amountToDefault);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 - amountToDefault,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy + yieldToSchedule / 3 - amountToDefault,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Assert system state at the end of initial schedule                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 - amountToDefault,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy + yieldToSchedule / 3 - amountToDefault,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_impairAndDeposit_exchangeRateIsNotEffected() public {
        address targetStrategy = poolManager.strategyList(0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 assetsToDeploy = 50e8;
        uint256 assetsToImpair = 30e8;

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).deploy(address(depositAsset), assetsToDeploy);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    assetsToDeploy,
            assetControllerBalance:    initialDepositAmount - assetsToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - assetsToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: assetsToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        uint256 assetsToDeposit = 20e8;

        /**********************************************************************************************************************************/
        /*** Step 2: Deposit assets into strategy and take a snapshot before deposit                                                    ***/
        /**********************************************************************************************************************************/

        uint256 snapshot = vm.snapshot();

        uint256 receivedSharesNoImpair = depositInSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), assetsToDeposit);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    assetsToDeploy,
            assetControllerBalance:    initialDepositAmount - assetsToDeploy + assetsToDeposit,
            poolTotalAssets:           initialDepositAmount + assetsToDeposit,
            poolCompositeTokenBalance: initialDepositAmount - assetsToDeploy + assetsToDeposit
        });

        uint256 totalAssetsAfterDepositNoImpair    = pool.totalAssets();
        uint256 strategyAumAfterDepositNoImpair    = IBitcoinStrategy(targetStrategy).assetsUnderManagement();
        uint256 impairedAssetsAfterDepositNoImpair = IBitcoinStrategy(targetStrategy).impairedAssets();
        uint256 lpSharesAfterDepositNoImpair       = pool.balanceOf(lp);
        uint256 lpAssetsAfterDepositNoImpair       = depositAsset.balanceOf(lp);
        uint256 exchangeRateAfterDepositNoImpair   = pool.convertToAssets(1e8);

        assertEq(strategyAumAfterDepositNoImpair,    assetsToDeploy);
        assertEq(impairedAssetsAfterDepositNoImpair, 0);
        assertEq(lpSharesAfterDepositNoImpair,       receivedSharesNoImpair + initialDepositAmount);
        assertEq(receivedSharesNoImpair,             assetsToDeposit);

        /**********************************************************************************************************************************/
        /*** Step 3: Revert to snapshot prior to deposit and set impairment                                                             ***/
        /**********************************************************************************************************************************/

        vm.revertTo(snapshot);

        vm.prank(poolDelegate);
        IBitcoinStrategy(targetStrategy).setImpairment(assetsToImpair);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    assetsToDeploy,
            assetControllerBalance:    initialDepositAmount - assetsToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - assetsToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: assetsToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        assetsToImpair
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Deposit assets into strategy                                                                                       ***/
        /**********************************************************************************************************************************/

        // Workaround stack too deep error
        {
            uint256 receivedSharesWithImpair = depositInSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), assetsToDeposit);
            assertEq(receivedSharesWithImpair, receivedSharesNoImpair);
        }

        assertSyrupBtcSystemState({
            strategyManagerBalance:    assetsToDeploy,
            assetControllerBalance:    initialDepositAmount - assetsToDeploy + assetsToDeposit,
            poolTotalAssets:           initialDepositAmount + assetsToDeposit,
            poolCompositeTokenBalance: initialDepositAmount - assetsToDeploy + assetsToDeposit
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: assetsToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        assetsToImpair
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Compare system state with and without impairment                                                                   ***/
        /**********************************************************************************************************************************/

        uint256 totalAssetsAfterDepositWithImpair  = pool.totalAssets();
        uint256 strategyAumAfterDepositWithImpair  = IBitcoinStrategy(targetStrategy).assetsUnderManagement();
        uint256 lpSharesAfterDepositWithImpair     = pool.balanceOf(lp);
        uint256 lpAssetsAfterDepositWithImpair     = depositAsset.balanceOf(lp);
        uint256 exchangeRateAfterDepositWithImpair = pool.convertToAssets(1e8);

        assertEq(totalAssetsAfterDepositWithImpair,  totalAssetsAfterDepositNoImpair);
        assertEq(strategyAumAfterDepositWithImpair,  strategyAumAfterDepositNoImpair);
        assertEq(lpSharesAfterDepositWithImpair,     lpSharesAfterDepositNoImpair);
        assertEq(lpAssetsAfterDepositWithImpair,     lpAssetsAfterDepositNoImpair);
        assertEq(exchangeRateAfterDepositWithImpair, exchangeRateAfterDepositNoImpair);
    }

    function test_scenario_redeem_completeDefault_userReceivesZeroAssets() public {
        address targetStrategy  = poolManager.strategyList(0);
        uint256 amountToDeploy  = pool.totalAssets();
        uint256 amountToDefault = amountToDeploy;

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).deploy(address(depositAsset), amountToDeploy);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);
        assertEq(pool.balanceOf(lp),         initialDepositAmount);

        uint256 sharesToRedeem = pool.balanceOf(lp);

        /**********************************************************************************************************************************/
        /*** Step 2: Request complete redeem                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 requestId = requestRedeemFromSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), sharesToRedeem);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);
        assertEq(pool.balanceOf(lp),         0);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(depositAsset),
            owner:     address(lp),
            shares:    sharesToRedeem
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(bitcoinRouter),
            shares:    sharesToRedeem
        });

        assertQueue({
            poolManager:   address(poolManager),
            nextRequestId: requestId,
            lastRequestId: requestId
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Default strategy completely                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IBitcoinStrategy(targetStrategy).setDefault(amountToDefault);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           0,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);
        assertEq(pool.balanceOf(lp),         0);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestId;

        /**********************************************************************************************************************************/
        /*** Step 4: Process redeem on withdrawal manager                                                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToRedeem);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           0,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);
        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.totalSupply(),         initialDepositAmount);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    sharesToRedeem
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(0),
            shares:    0
        });

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId + 1,
            lastRequestId: requestId
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Process redeem on router                                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 timeToPass = 100 days;
        vm.warp(startingTime + timeToPass);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           0,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(depositAsset.balanceOf(lp), 0);
        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.totalSupply(),         0);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(0),
            shares:    0
        });

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId + 1,
            lastRequestId: requestId
        });
    }

    function test_scenario_replaceCurrentSchedule_differentDuration() public {
        address targetStrategy = poolManager.strategyList(0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldToSchedule = pool.totalAssets(); // Double the total assets
        uint256 yieldDuration   = 100 days;

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldToSchedule, uint32(startingTime + yieldDuration));

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for third of the schedule                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 3);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3,
            accruedYield:          yieldToSchedule / 3,
            accruedFees:           0,
            impairedAssets:        0
        });

        ( uint256 remainingYield, , uint32 remainingDuration ) = IBitcoinStrategy(targetStrategy).schedules(0);

        // Accrue did happen so we need to manually subtract the accrued yield or to execute any action on the strategy contract
        remainingYield = remainingYield - IBitcoinStrategy(targetStrategy).accruedYield();

        /**********************************************************************************************************************************/
        /*** Step 3: Replace current schedule with a new one                                                                            ***/
        /**********************************************************************************************************************************/

        uint32 newDuration  = remainingDuration * 2;
        uint32 nowTimestamp = uint32(block.timestamp);
        uint32 newDeadline  = nowTimestamp + newDuration;

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(remainingYield, newDeadline);

        vm.warp(nowTimestamp + newDuration / 4);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 + remainingYield / 4,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3 + remainingYield / 4,
            accruedYield:          remainingYield / 4,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Wait for the end of the new schedule                                                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(newDeadline);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 + remainingYield,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3 + remainingYield,
            accruedYield:          remainingYield,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_replaceCurrentSchedule_differentYieldAmount_sameDeadline() public {
        address targetStrategy = poolManager.strategyList(0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldToSchedule = pool.totalAssets(); // Double the total assets
        uint256 yieldDuration   = 100 days;
        uint32  deadline        = uint32(startingTime + yieldDuration);

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldToSchedule, deadline);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for third of the schedule                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 3);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3,
            accruedYield:          yieldToSchedule / 3,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Replace current schedule with a new one                                                                            ***/
        /**********************************************************************************************************************************/

        ( uint256 remainingYield, , ) = IBitcoinStrategy(targetStrategy).schedules(0);

        // Accrue did happen so we need to manually subtract the accrued yield or to execute any action on the strategy contract
        remainingYield = remainingYield - IBitcoinStrategy(targetStrategy).accruedYield();

        uint256 nowTimestamp       = uint32(block.timestamp);
        uint256 newDuration        = deadline - nowTimestamp;
        uint256 newYieldToSchedule = remainingYield / 4;

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(newYieldToSchedule, deadline);

        vm.warp(nowTimestamp + newDuration / 4);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 + newYieldToSchedule / 4,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3 + newYieldToSchedule / 4,
            accruedYield:          newYieldToSchedule / 4,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Wait for the end of the new schedule                                                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(deadline);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3 + newYieldToSchedule,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 3 + newYieldToSchedule,
            accruedYield:          newYieldToSchedule,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_strategyMigration_duringSchedule() public {
        address strategy1 = poolManager.strategyList(0);
        address strategy2 = poolManager.strategyList(1);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy funds into strategy1                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 amountToDeploy = pool.totalAssets();

        vm.prank(strategyManager);
        IBitcoinStrategy(strategy1).deploy(address(depositAsset), amountToDeploy);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Schedule yield on strategy1                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 yieldToSchedule = 50e8;
        uint256 yieldDuration   = 100 days;

        vm.prank(strategyManager);
        IBitcoinStrategy(strategy1).schedule(yieldToSchedule, uint32(startingTime + yieldDuration));

        vm.warp(startingTime + yieldDuration / 3);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: amountToDeploy + yieldToSchedule / 3,
            accruedYield:          yieldToSchedule / 3,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Reconcile strategy1                                                                                                ***/
        /**********************************************************************************************************************************/

        vm.startPrank(strategyManager);

        depositAsset.approve(address(strategy1), amountToDeploy);
        IBitcoinStrategy(strategy1).reconcile(address(depositAsset), amountToDeploy);

        vm.stopPrank();

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 3,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: yieldToSchedule / 3,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Deploy funds into strategy2                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        vm.prank(strategyManager);
        IBitcoinStrategy(strategy2).deploy(address(depositAsset), amountToDeploy);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    amountToDeploy,
            assetControllerBalance:    initialDepositAmount - amountToDeploy,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule,
            poolCompositeTokenBalance: initialDepositAmount - amountToDeploy
        });

        assertBitcoinStrategyState({
            strategy:              strategy1,
            assetsUnderManagement: yieldToSchedule,
            accruedYield:          yieldToSchedule - yieldToSchedule / 3,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertBitcoinStrategyState({
            strategy:              strategy2,
            assetsUnderManagement: amountToDeploy,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });
    }

    function test_scenario_updateFee_duringSchedule_exchangeRateIsEffected() public {
        address targetStrategy = poolManager.strategyList(0);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldToSchedule = pool.totalAssets(); // Double the total assets
        uint256 yieldDuration   = 100 days;

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldToSchedule, uint32(startingTime + yieldDuration));

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: 0,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for quarter of the schedule                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 4);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 4,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 4,
            accruedYield:          yieldToSchedule / 4,
            accruedFees:           0,
            impairedAssets:        0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Set fee rate to 50% of the yield during yield accrual                                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        IBitcoinStrategy(targetStrategy).setFeeRate(0.5e6); // 50% of yield

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 4,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 4,
            accruedYield:          0,
            accruedFees:           0,
            impairedAssets:        0
        });

        assertEq(IBitcoinStrategy(targetStrategy).feeRate(), 0.5e6);

        /**********************************************************************************************************************************/
        /*** Step 4: Wait for the end of the schedule                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertSyrupBtcSystemState({
            strategyManagerBalance:    0,
            assetControllerBalance:    initialDepositAmount,
            poolTotalAssets:           initialDepositAmount + yieldToSchedule / 4 + yieldToSchedule * 3 / 8,
            poolCompositeTokenBalance: initialDepositAmount
        });

        assertBitcoinStrategyState({
            strategy:              targetStrategy,
            assetsUnderManagement: yieldToSchedule / 4 + yieldToSchedule * 3 / 8,
            accruedYield:          yieldToSchedule * 3 / 4,
            accruedFees:           yieldToSchedule * 3 / 8,
            impairedAssets:        0
        });
    }

    function test_scenario_switchingOnAndOffRequestRedeemPermission() public {
        /**********************************************************************************************************************************/
        /*** Step 1: Malicious actor deposits into SyrupBTC                                                                             ***/
        /**********************************************************************************************************************************/

        address maliciousActor = makeAddr("maliciousActor");
        uint256 depositAmount  = 100e8;

        depositInSyrupBtc(maliciousActor, address(bitcoinRouter), address(depositAsset), depositAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Remove lender allowlist from SyrupBTC router                                                                       ***/
        /**********************************************************************************************************************************/

        address[] memory addresses = new address[](1);
        bool[]    memory allowed   = new bool[](1);

        addresses[0] = address(bitcoinRouter);
        allowed[0]   = false;

        vm.prank(governor);
        IPoolPermissionManager(poolPermissionManager).setLenderAllowlist(address(poolManager), addresses, allowed);

        /**********************************************************************************************************************************/
        /*** Step 3: Configure lender bitmaps for SyrupBTC router to allow everything except requesting redeem                          ***/
        /**********************************************************************************************************************************/

        address[] memory lenders       = new address[](1);
        uint256[] memory lenderBitmaps = new uint256[](1);

        lenders[0]       = address(bitcoinRouter);
        lenderBitmaps[0] = 2 ** 5;

        vm.prank(governor);
        IPoolPermissionManager(poolPermissionManager).setLenderBitmaps(lenders, lenderBitmaps);

        bytes32[] memory functionIds = new bytes32[](1);
        uint256[] memory poolBitmaps = new uint256[](1);

        functionIds[0] = "P:requestRedeem";
        poolBitmaps[0] = 2 ** 5 + 1; // All other function are set to 2**5

        vm.prank(governor);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(address(poolManager), functionIds, poolBitmaps);

        /**********************************************************************************************************************************/
        /*** Step 3: Try to request redeem                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 redeemAmount = 50e8;

        vm.startPrank(lp);
        pool.approve(address(bitcoinRouter), redeemAmount);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /*** Step 4: Allow requesting redeem on SyrupBTC router                                                                         ***/
        /**********************************************************************************************************************************/

        poolBitmaps[0] = 2 ** 5;

        vm.prank(governor);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(address(poolManager), functionIds, poolBitmaps);

        /**********************************************************************************************************************************/
        /*** Step 5: Malicious actor requests redemption                                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromSyrupBtc(maliciousActor, address(bitcoinRouter), address(depositAsset), redeemAmount);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     maliciousActor,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 6: Honest actor requests redemption                                                                                   ***/
        /**********************************************************************************************************************************/

        requestRedeemFromSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), redeemAmount);

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });


        /**********************************************************************************************************************************/
        /*** Step 7: Restrict requesting redeem on SyrupBTC router                                                                      ***/
        /**********************************************************************************************************************************/

        poolBitmaps[0] = 2 ** 5 + 1; // All other function are set to 2**5

        vm.prank(governor);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(address(poolManager), functionIds, poolBitmaps);

        /**********************************************************************************************************************************/
        /*** Step 8: Request redemption reverts on SyrupBTC router                                                                      ***/
        /**********************************************************************************************************************************/

        vm.startPrank(lp);
        pool.approve(address(bitcoinRouter), redeemAmount);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /** Step 9: Admin removes malicious actor's request from withdrawal manager                                                     ***/
        /**********************************************************************************************************************************/

        uint256[] memory expectedRequests = new uint256[](2);
        expectedRequests[0]               = 1;
        expectedRequests[1]               = 2;

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequests);

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(address(bitcoinRouter)),     0);
        assertEq(pool.balanceOf(maliciousActor),             depositAmount - redeemAmount);
        assertEq(pool.balanceOf(address(withdrawalManager)), redeemAmount + redeemAmount);

        uint256[] memory requestsToRemove = new uint256[](1);
        requestsToRemove[0]               = 1;

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(address(bitcoinRouter), requestsToRemove);

        expectedRequests    = new uint256[](1);
        expectedRequests[0] = 2;

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequests);

        assertRequestOnWm({
            requestId: 1,
            owner:     address(0),
            shares:    0
        });

        assertEq(pool.balanceOf(address(bitcoinRouter)),     redeemAmount);
        assertEq(pool.balanceOf(maliciousActor),             depositAmount - redeemAmount);
        assertEq(pool.balanceOf(address(withdrawalManager)), redeemAmount);

        /**********************************************************************************************************************************/
        /*** Step 10: Honest actor decreases shares on their request                                                                    ***/
        /**********************************************************************************************************************************/

        assertRequestOnWm({
            requestId: 2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(lp), initialDepositAmount - redeemAmount);

        uint256 sharesToRemove = 10e8;

        vm.prank(lp);
        bitcoinRouter.removeSharesById(2, sharesToRemove);

        assertRequestOnWm({
            requestId: 2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount - sharesToRemove
        });

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount - sharesToRemove
        });

        assertEq(pool.balanceOf(lp), initialDepositAmount - redeemAmount + sharesToRemove);

        /**********************************************************************************************************************************/
        /*** Step 11: Process redemption on WM and router                                                                               ***/
        /**********************************************************************************************************************************/

        assertEq(depositAsset.balanceOf(lp), 0);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(redeemAmount - sharesToRemove);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = 2;

        vm.prank(redeemer);
        bitcoinRouter.processRedemptions(requestIds);

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 2,
            owner:     address(0),
            shares:    0
        });

        assertEq(depositAsset.balanceOf(lp), redeemAmount - sharesToRemove);
    }

    function test_scenario_wmMustProcessRequestsInOrder_routerCanCherryPick() public {
        /**********************************************************************************************************************************/
        /*** Step 1: Make 3 redeem requests                                                                                             ***/
        /**********************************************************************************************************************************/

        uint256 redeemAmount1 = 50e8;
        uint256 redeemAmount2 = 20e8;
        uint256 redeemAmount3 = 10e8;

        requestRedeemFromSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), redeemAmount1);
        requestRedeemFromSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), redeemAmount2);
        requestRedeemFromSyrupBtc(lp, address(bitcoinRouter), address(depositAsset), redeemAmount3);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount2
        });

        assertRequestOnRouter({
            requestId: 3,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount3
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: 2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: 3,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount3
        });

        uint256[] memory requestIds = new uint256[](3);
        requestIds[0]               = 1;
        requestIds[1]               = 2;
        requestIds[2]               = 3;

        assertUsersRequestsOnWm(address(bitcoinRouter), requestIds);

        uint256 amountToProcess = redeemAmount1 + redeemAmount2 + redeemAmount3;

        /**********************************************************************************************************************************/
        /*** Step 2: Process all of them on WM but only 1 and 3 on router                                                               ***/
        /**********************************************************************************************************************************/

        assertEq(depositAsset.balanceOf(lp), 0);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(amountToProcess);

        uint256[] memory requestsToProcessOnRouter = new uint256[](2);
        requestsToProcessOnRouter[0]               = 1;
        requestsToProcessOnRouter[1]               = 3;

        vm.prank(redeemer);
        bitcoinRouter.processRedemptions(requestsToProcessOnRouter);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnRouter({
            requestId: 2,
            asset:     address(depositAsset),
            owner:     lp,
            shares:    redeemAmount2
        });

        assertRequestOnRouter({
            requestId: 3,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 2,
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 3,
            owner:     address(0),
            shares:    0
        });

        assertEq(depositAsset.balanceOf(lp), redeemAmount1 + redeemAmount3);
    }

    function test_scenario_deposit_gasCostIsApproximatelyTheSame_regardlessOfNumberOfRedeemRequests() public {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy fresh instance of SyrupBTC system and measure gas cost of deposit with 1 redeem request                     ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp1, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp1, 1);

        uint256 depositGasCost1 = _measureDepositGasCost(lp1);

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy fresh instance of SyrupBTC system and measure gas cost of deposit with 500 redeem requests                  ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp2, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp2, 500);

        uint256 depositGasCost2 = _measureDepositGasCost(lp2);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy fresh instance of SyrupBTC system and measure gas cost of deposit with 5,000 redeem requests                ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp3, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp3, 5_000);

        uint256 depositGasCost3 = _measureDepositGasCost(lp3);

        /**********************************************************************************************************************************/
        /*** Step 4: Assert that the gas cost is approximately the same                                                                 ***/
        /**********************************************************************************************************************************/

        assertApproxEqRel(depositGasCost1, depositGasCost2, 2.5e16); // Allow 2.5% delta
        assertApproxEqRel(depositGasCost1, depositGasCost3, 5e16);   // Allow 5.0% delta
    }

    function test_scenario_removeSharesById_gasCostIsTheSame_regardlessOfNumberOfRedeemRequests() public {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        uint256 sharesToRemove = 1;

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy fresh instance of SyrupBTC system and measure gas cost of remove shares with 1 redeem request               ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp1, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp1, 1);

        uint256 removeSharesGasCost1 = _measureRemoveSharesByIdGasCost({
            user:           lp1,
            requestId:      1,
            sharesToRemove: sharesToRemove
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy fresh instance of SyrupBTC system and measure gas cost of remove shares with 500 redeem requests            ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp2, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp2, 500);

        uint256 removeSharesGasCost2 = _measureRemoveSharesByIdGasCost({
            user:           lp2,
            requestId:      250,
            sharesToRemove: sharesToRemove
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy fresh instance of SyrupBTC system and measure gas cost of remove shares with 5,000 redeem requests          ***/
        /**********************************************************************************************************************************/

        _setupBitcoinPool();

        depositInSyrupBtc(lp3, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp3, 5_000);

        uint256 removeSharesGasCost3 = _measureRemoveSharesByIdGasCost({
            user:           lp3,
            requestId:      2_500,
            sharesToRemove: sharesToRemove
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Assert that the gas cost is the same                                                                               ***/
        /**********************************************************************************************************************************/

        assertEq(removeSharesGasCost1, removeSharesGasCost2);
        assertEq(removeSharesGasCost1, removeSharesGasCost3);
    }

    function test_scenario_wmRemoveRequests_gasCostIsTheSame_regardlessOfNumberOfRedeemRequests() public {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy fresh instance of SyrupBTC system and measure gas cost of removal of the request in the middle out of 3     ***/
        /**********************************************************************************************************************************/

        uint256 numberOfRequests = 3;
        uint256 requestToRemove  = 2;

        _setupBitcoinPool();

        depositInSyrupBtc(lp1, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp1, numberOfRequests);

        uint256 removeRequestsGasCost1 = _measureRemoveRequestsGasCost(address(bitcoinRouter), requestToRemove);

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy fresh instance of SyrupBTC system and measure gas cost of removal of the request in the middle out of 5,000 ***/
        /**********************************************************************************************************************************/

        numberOfRequests = 5_000;
        requestToRemove  = 2_500;

        _setupBitcoinPool();

        depositInSyrupBtc(lp2, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        _seedRedeemRequests(lp2, numberOfRequests);

        uint256 removeRequestsGasCost2 = _measureRemoveRequestsGasCost(address(bitcoinRouter), requestToRemove);

        /**********************************************************************************************************************************/
        /*** Step 3: Assert that the gas cost is the same                                                                               ***/
        /**********************************************************************************************************************************/

        assertEq(removeRequestsGasCost1, removeRequestsGasCost2);
    }

    function _seedRedeemRequests(address user, uint256 numberOfRequestsToMake) internal {
        uint256 redeemAmount = initialDepositAmount / numberOfRequestsToMake;

        for (uint256 i = 0; i < numberOfRequestsToMake; i++) {
            requestRedeemFromSyrupBtc(user, address(bitcoinRouter), address(depositAsset), redeemAmount);
        }
    }

    function _measureDepositGasCost(address user) internal returns (uint256 gasCost) {
        uint256 gasBefore = gasleft();

        depositInSyrupBtc(user, address(bitcoinRouter), address(depositAsset), initialDepositAmount);

        gasCost = gasBefore - gasleft();
    }

    function _measureRemoveSharesByIdGasCost(
        address user,
        uint256 requestId,
        uint256 sharesToRemove
    ) internal returns (uint256 gasCost) {
        uint256 gasBefore = gasleft();

        vm.prank(user);
        bitcoinRouter.removeSharesById(requestId, sharesToRemove);

        gasCost = gasBefore - gasleft();
    }

    function _measureRemoveRequestsGasCost(address user, uint256 requestToRemove) internal returns (uint256 gasCost) {
        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestToRemove;

        uint256 gasBefore = gasleft();

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(user, requestIds);

        gasCost = gasBefore - gasleft();
    }

}

