// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    Action,
    ActionType,
    IPool,
    IStrategyManager,
    IAllocationStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyProcessRedemptionTestBase is AllocationStrategyTestBase {

    function setUp() public virtual override {
        super.setUp();

        strategyManager = allocationStrategyManager;
    }

}

contract AllocationStrategyProcessRedemptionFailureTests is AllocationStrategyProcessRedemptionTestBase {

    function test_processRedemption_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_strategyManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(strategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_notOperator() external {
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_poolDelegate() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_liquidityBotWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_liquidityRouterWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: strategyManager,
            poolManager:     address(poolManager),
            amount:          INITIAL_LIQUIDITY,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_processRedemption_revert_invalidPoolManagerFactory() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(strategyManager).processRedemption(address(queueWM), INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_nonInstancePoolManager() external {
        address fakePoolManager = makeAddr("fakePoolManager");

        vm.mockCall(fakePoolManager, abi.encodeWithSignature("factory()"), abi.encode(poolManagerFactory));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(strategyManager).processRedemption(fakePoolManager, INITIAL_LIQUIDITY, "");
    }

    function test_processRedemption_revert_zeroShares() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_SHARES");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), 0, "");
    }

    function test_processRedemption_revert_exceedsRequested_noPendingShares() external {
        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:EXCEEDS_REQUESTED");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), 1, "");
    }

    function test_processRedemption_revert_exceedsRequested_abovePendingShares() external {
        uint256 request = INITIAL_LIQUIDITY * 2 / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:EXCEEDS_REQUESTED");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), request + 1, "");
    }

    function test_processRedemption_revert_zeroAssets() external {
        uint256 impairment = INITIAL_LIQUIDITY - 1;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, 1);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        // One share converts to zero assets because one net asset remains across all shares and the exit conversion rounds down.
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), 1, "");
    }

    function test_processRedemption_revert_notEnoughLiquidity() external {
        uint256 deployedAssets = INITIAL_LIQUIDITY * 2 / 3;
        uint256 request        = INITIAL_LIQUIDITY * 2 / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        deployAssets(allocationUnderlyingStrategy, managedWallet, deployedAssets);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), request, "");
    }

    function test_processRedemption_revert_underlyingStrategyPaused() external {
        uint256 request = INITIAL_LIQUIDITY * 2 / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), request, "");
    }

}

contract AllocationStrategyProcessRedemptionSuccessTests is AllocationStrategyProcessRedemptionTestBase {

    uint256 firstPoolAssets;
    uint256 secondPoolAssets;
    uint256 firstPoolSharesRequested;
    uint256 secondPoolSharesRequested;
    uint256 firstPoolSharesToProcess;
    uint256 secondPoolSharesToProcess;
    uint256 firstPoolYield;
    uint256 secondPoolYield;
    uint256 firstPoolYieldAssetsOut;
    uint256 secondPoolYieldAssetsOut;

    function setUp() public override {
        super.setUp();

        assertInitialStateWithAllocation({
            strategyManager:  strategyManager,
            initialLiquidity: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        deposit(lp, INITIAL_LIQUIDITY);

        assertInitialStateWithAllocation({
            strategyManager:  strategyManager,
            initialLiquidity: INITIAL_LIQUIDITY
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_fullRedemption() external {

        /**********************************************************************************************************************************/
        /*** Request all shares                                                                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    INITIAL_LIQUIDITY,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process all shares                                                                                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: INITIAL_LIQUIDITY
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_withOperatorRoles() external {
        uint256 request             = INITIAL_LIQUIDITY * 4 / 5;
        uint256 botProcessAmount    = request / 3;
        uint256 routerProcessAmount = request / 4;
        uint256 totalProcessed      = botProcessAmount + routerProcessAmount;

        /**********************************************************************************************************************************/
        /*** Assert the operator roles are configured                                                                                   ***/
        /**********************************************************************************************************************************/

        assertEq(globals.isInstanceOf("LIQUIDITY_BOT",    liquidityBot),             true);
        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter)), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Request shares                                                                                                             ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process shares as the liquidity bot                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        IStrategyManager(strategyManager).processRedemption(address(poolManager), botProcessAmount, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: botProcessAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - botProcessAmount,
            availableToWithdraw:   INITIAL_LIQUIDITY - botProcessAmount,
            recordedAssets:        INITIAL_LIQUIDITY - botProcessAmount,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - botProcessAmount,
            totalPendingShares:    request - botProcessAmount,
            assetsUnderManagement: INITIAL_LIQUIDITY - botProcessAmount,
            availableToWithdraw:   INITIAL_LIQUIDITY - botProcessAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - botProcessAmount,
            shares:           INITIAL_LIQUIDITY - botProcessAmount,
            pendingShares:    request - botProcessAmount,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                botProcessAmount);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY - botProcessAmount);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process shares as the liquidity router                                                                                     ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: strategyManager,
            poolManager:     address(poolManager),
            amount:          routerProcessAmount,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: totalProcessed
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - totalProcessed,
            availableToWithdraw:   INITIAL_LIQUIDITY - totalProcessed,
            recordedAssets:        INITIAL_LIQUIDITY - totalProcessed,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - totalProcessed,
            totalPendingShares:    request - totalProcessed,
            assetsUnderManagement: INITIAL_LIQUIDITY - totalProcessed,
            availableToWithdraw:   INITIAL_LIQUIDITY - totalProcessed,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - totalProcessed,
            shares:           INITIAL_LIQUIDITY - totalProcessed,
            pendingShares:    request - totalProcessed,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                totalProcessed);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY - totalProcessed);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_multiplePoolManagers() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        firstPoolAssets           = INITIAL_LIQUIDITY;
        secondPoolAssets          = firstPoolAssets * 3 / 5;
        firstPoolSharesRequested  = firstPoolAssets * 2 / 5;
        secondPoolSharesRequested = secondPoolAssets * 2 / 5;
        firstPoolSharesToProcess  = firstPoolSharesRequested / 3;
        secondPoolSharesToProcess = secondPoolSharesRequested / 3;

        uint256 totalAssets = firstPoolAssets + secondPoolAssets;

        /**********************************************************************************************************************************/
        /*** Create and fund a second pool                                                                                              ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManager);

        deposit(secondPool, makeAddr("lp2"), secondPoolAssets);
        fundStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets,
            shares:           secondPoolAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Request shares from both pools                                                                                             ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesRequested);
        requestRedeemFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesRequested);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets,
            totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets,
            shares:           firstPoolAssets,
            pendingShares:    firstPoolSharesRequested,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets,
            shares:           secondPoolAssets,
            pendingShares:    secondPoolSharesRequested,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process shares for the first pool                                                                                          ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesToProcess);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolSharesToProcess
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets - firstPoolSharesToProcess,
            availableToWithdraw:   totalAssets - firstPoolSharesToProcess,
            recordedAssets:        totalAssets - firstPoolSharesToProcess,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets - firstPoolSharesToProcess,
            totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess,
            assetsUnderManagement: totalAssets - firstPoolSharesToProcess,
            availableToWithdraw:   totalAssets - firstPoolSharesToProcess,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets - firstPoolSharesToProcess,
            shares:           firstPoolAssets - firstPoolSharesToProcess,
            pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets,
            shares:           secondPoolAssets,
            pendingShares:    secondPoolSharesRequested,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    firstPoolSharesToProcess);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - firstPoolSharesToProcess);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process shares for the second pool                                                                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesToProcess);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolSharesToProcess
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: secondPoolSharesToProcess
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            availableToWithdraw:   totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            recordedAssets:        totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        uint256 remainingPendingShares =
            firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess - secondPoolSharesToProcess;

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            totalPendingShares:    remainingPendingShares,
            assetsUnderManagement: totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            availableToWithdraw:   totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets - firstPoolSharesToProcess,
            shares:           firstPoolAssets - firstPoolSharesToProcess,
            pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets - secondPoolSharesToProcess,
            shares:           secondPoolAssets - secondPoolSharesToProcess,
            pendingShares:    secondPoolSharesRequested - secondPoolSharesToProcess,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    firstPoolSharesToProcess);
        assertEq(fundsAsset.balanceOf(secondPool),                   secondPoolSharesToProcess);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - firstPoolSharesToProcess - secondPoolSharesToProcess);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_withImpairment() external {
        uint256 impairment    = INITIAL_LIQUIDITY / 4;
        uint256 request       = INITIAL_LIQUIDITY * 2 / 5;
        uint256 processAmount = request / 3;

        // Partial shares convert to exit assets with round-down division.
        uint256 assetsOut = processAmount * (INITIAL_LIQUIDITY - impairment) / INITIAL_LIQUIDITY;

        uint256 remainingAssets = INITIAL_LIQUIDITY - assetsOut;
        uint256 remainingShares = INITIAL_LIQUIDITY - processAmount;

        uint256 expectedAssetsPerShare = INITIAL_LIQUIDITY * remainingAssets / remainingShares;
        uint256 expectedSharesPerAsset = INITIAL_LIQUIDITY * remainingShares / remainingAssets;

        /**********************************************************************************************************************************/
        /*** Request shares                                                                                                             ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        assertEq(IStrategyManager(strategyManager).convertToAssets(INITIAL_LIQUIDITY), INITIAL_LIQUIDITY);
        assertEq(IStrategyManager(strategyManager).convertToShares(INITIAL_LIQUIDITY), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Process shares at the impaired exit rate                                                                                   ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, processAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   impairment,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            recordedAssets:        remainingAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    request - processAmount,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    request - processAmount,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), remainingAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        assertEq(IStrategyManager(strategyManager).convertToAssets(INITIAL_LIQUIDITY), expectedAssetsPerShare);
        assertEq(IStrategyManager(strategyManager).convertToShares(INITIAL_LIQUIDITY), expectedSharesPerAsset);
    }

    function test_processRedemption_success_fullAmountWithImpairment() external {
        uint256 impairment = INITIAL_LIQUIDITY / 4;
        uint256 assetsOut  = INITIAL_LIQUIDITY - impairment;

        /**********************************************************************************************************************************/
        /*** Request all shares                                                                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    INITIAL_LIQUIDITY,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    INITIAL_LIQUIDITY,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process all shares at the impaired exit rate                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsOut,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), impairment);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_withDeployedAssets() external {
        uint256 deployedAssets = INITIAL_LIQUIDITY * 2 / 3;
        uint256 request        = INITIAL_LIQUIDITY * 2 / 5;
        uint256 processAmount  = request / 3;
        uint256 liquidAssets   = INITIAL_LIQUIDITY - deployedAssets;

        /**********************************************************************************************************************************/
        /*** Deploy strategy assets                                                                                                     ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   liquidAssets,
            recordedAssets:        liquidAssets,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   liquidAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), liquidAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets);

        /**********************************************************************************************************************************/
        /*** Request a liquid amount of shares                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   liquidAssets,
            recordedAssets:        liquidAssets,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   liquidAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), liquidAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets);

        /**********************************************************************************************************************************/
        /*** Process the liquid tranche                                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, processAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: processAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - processAmount,
            availableToWithdraw:   liquidAssets - processAmount,
            recordedAssets:        liquidAssets - processAmount,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - processAmount,
            totalPendingShares:    request - processAmount,
            assetsUnderManagement: INITIAL_LIQUIDITY - processAmount,
            availableToWithdraw:   liquidAssets - processAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - processAmount,
            shares:           INITIAL_LIQUIDITY - processAmount,
            pendingShares:    request - processAmount,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                processAmount);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), liquidAssets - processAmount);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets);
    }

    function test_processRedemption_success_afterReturnAssetsProvidesLiquidity() external {
        uint256 deployedAssets = 600_000e6;
        uint256 returnedAssets = 200_000e6;
        uint256 request        = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Deploy assets and request shares                                                                                           ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, deployedAssets);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets,
            recordedAssets:        INITIAL_LIQUIDITY - deployedAssets,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY - deployedAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets);

        /**********************************************************************************************************************************/
        /*** Return assets                                                                                                              ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, returnedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets + returnedAssets,
            recordedAssets:        INITIAL_LIQUIDITY - deployedAssets + returnedAssets,
            totalDeployedAssets:   deployedAssets - returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets + returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY - deployedAssets + returnedAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets - returnedAssets);

        /**********************************************************************************************************************************/
        /*** Process the requested shares                                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: request
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - request,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets + returnedAssets - request,
            recordedAssets:        INITIAL_LIQUIDITY - deployedAssets + returnedAssets - request,
            totalDeployedAssets:   deployedAssets - returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - request,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY - request,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets + returnedAssets - request,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - request,
            shares:           INITIAL_LIQUIDITY - request,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                request);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY - deployedAssets + returnedAssets - request);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                deployedAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssets - returnedAssets);
    }

    function test_processRedemption_success_partialAndFullAfterRecognizedLoss() external {
        uint256 loss            = 250_000e6;
        uint256 partialShares   = 400_000e6;
        uint256 assetsAfterLoss = INITIAL_LIQUIDITY - loss;
        uint256 partialAssets   = partialShares * assetsAfterLoss / INITIAL_LIQUIDITY;

        /**********************************************************************************************************************************/
        /*** Recognize a loss and request all shares                                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, loss);
        recognizeLoss(allocationUnderlyingStrategy, managedWallet, loss);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   assetsAfterLoss,
            recordedAssets:        assetsAfterLoss,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    INITIAL_LIQUIDITY,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   assetsAfterLoss,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), assetsAfterLoss);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                loss);

        /**********************************************************************************************************************************/
        /*** Process some shares                                                                                                        ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, partialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: partialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss - partialAssets,
            availableToWithdraw:   assetsAfterLoss - partialAssets,
            recordedAssets:        assetsAfterLoss - partialAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - partialShares,
            totalPendingShares:    INITIAL_LIQUIDITY - partialShares,
            assetsUnderManagement: assetsAfterLoss - partialAssets,
            availableToWithdraw:   assetsAfterLoss - partialAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss - partialAssets,
            shares:           INITIAL_LIQUIDITY - partialShares,
            pendingShares:    INITIAL_LIQUIDITY - partialShares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                partialAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), assetsAfterLoss - partialAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                loss);

        /**********************************************************************************************************************************/
        /*** Process all remaining shares                                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY - partialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: assetsAfterLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsAfterLoss);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                loss);
    }

    function test_processRedemption_success_multiplePoolManagersWithImpairment() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        uint256 impairment = 320_000e6;

        firstPoolAssets           = INITIAL_LIQUIDITY;
        secondPoolAssets          = 600_000e6;
        firstPoolSharesRequested  = 400_000e6;
        secondPoolSharesRequested = 300_000e6;
        firstPoolSharesToProcess  = 200_000e6;
        secondPoolSharesToProcess = 150_000e6;

        /**********************************************************************************************************************************/
        /*** Fund a second pool manager, impair the strategy, and request shares                                                        ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManager);

        deposit(secondPool, makeAddr("lp2"), secondPoolAssets);
        fundStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);
        requestRedeemFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesRequested);
        requestRedeemFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesRequested);

        {
            uint256 totalShares = firstPoolAssets + secondPoolAssets;
            uint256 firstLoss   = divRoundUp(firstPoolAssets  * impairment, totalShares);
            uint256 secondLoss  = divRoundUp(secondPoolAssets * impairment, totalShares);

            assertPoolState({
                pool:               firstPool,
                totalAssets:        firstPoolAssets,
                totalSupply:        firstPoolAssets,
                unrealizedLosses:   firstLoss,
                availableLiquidity: 0
            });

            assertPoolState({
                pool:               secondPool,
                totalAssets:        secondPoolAssets,
                totalSupply:        secondPoolAssets,
                unrealizedLosses:   secondLoss,
                availableLiquidity: 0
            });

            assertAllocationStrategy({
                allocationStrategy:    allocationUnderlyingStrategy,
                assetsUnderManagement: totalShares,
                availableToWithdraw:   totalShares,
                recordedAssets:        totalShares,
                totalDeployedAssets:   0,
                unrealizedLosses:      impairment
            });

            assertStrategyManager({
                strategyManager:       strategyManager,
                totalShares:           totalShares,
                totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested,
                assetsUnderManagement: totalShares,
                availableToWithdraw:   totalShares,
                unrealizedLosses:      impairment
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      firstPoolManager,
                assets:           firstPoolAssets,
                shares:           firstPoolAssets,
                pendingShares:    firstPoolSharesRequested,
                unrealizedLosses: firstLoss
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      secondPoolManager,
                assets:           secondPoolAssets,
                shares:           secondPoolAssets,
                pendingShares:    secondPoolSharesRequested,
                unrealizedLosses: secondLoss
            });
        }

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets + secondPoolAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        uint256 firstAssetsOut = firstPoolSharesToProcess * (firstPoolAssets + secondPoolAssets - impairment) /
            (firstPoolAssets + secondPoolAssets);

        /**********************************************************************************************************************************/
        /*** Process shares for the first pool manager                                                                                  ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesToProcess);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets - firstAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets - firstAssetsOut,
            recordedAssets:        firstPoolAssets + secondPoolAssets - firstAssetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess,
            totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets - firstAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets - firstAssetsOut,
            unrealizedLosses:      impairment
        });

        // First pool
        {
            uint256 strategyShares = firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess;
            uint256 strategyAssets = firstPoolAssets + secondPoolAssets - firstAssetsOut;

            uint256 shareBalanceAfterFirstRedemption   = firstPoolAssets - firstPoolSharesToProcess;
            uint256 assetBalanceAfterFirstRedemption   = shareBalanceAfterFirstRedemption * strategyAssets / strategyShares;
            uint256 unrealizedLossAfterFirstRedemption = divRoundUp(shareBalanceAfterFirstRedemption * impairment, strategyShares);

            assertPoolState({
                pool:               firstPool,
                totalAssets:        assetBalanceAfterFirstRedemption + firstAssetsOut,
                totalSupply:        firstPoolAssets,
                unrealizedLosses:   unrealizedLossAfterFirstRedemption,
                availableLiquidity: firstAssetsOut
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      firstPoolManager,
                assets:           assetBalanceAfterFirstRedemption,
                shares:           shareBalanceAfterFirstRedemption,
                pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
                unrealizedLosses: unrealizedLossAfterFirstRedemption
            });
        }

        // Second pool
        {
            uint256 strategyShares = firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess;
            uint256 strategyAssets = firstPoolAssets + secondPoolAssets - firstAssetsOut;

            uint256 assetBalanceAfterFirstRedemption   = secondPoolAssets * strategyAssets / strategyShares;
            uint256 unrealizedLossAfterFirstRedemption = divRoundUp(secondPoolAssets * impairment, strategyShares);

            assertPoolState({
                pool:               secondPool,
                totalAssets:        assetBalanceAfterFirstRedemption,
                totalSupply:        secondPoolAssets,
                unrealizedLosses:   unrealizedLossAfterFirstRedemption,
                availableLiquidity: 0
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      secondPoolManager,
                assets:           assetBalanceAfterFirstRedemption,
                shares:           secondPoolAssets,
                pendingShares:    secondPoolSharesRequested,
                unrealizedLosses: unrealizedLossAfterFirstRedemption
            });
        }

        assertEq(fundsAsset.balanceOf(firstPool),                    firstAssetsOut);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets + secondPoolAssets - firstAssetsOut);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        uint256 secondAssetsOut = secondPoolSharesToProcess * (firstPoolAssets + secondPoolAssets - firstAssetsOut - impairment) /
            (firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess);

        /**********************************************************************************************************************************/
        /*** Process shares for the second pool manager                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesToProcess);

        uint256 pendingSharesAfterSecondRedemption =
            firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess - secondPoolSharesToProcess;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut,
            recordedAssets:        firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess - secondPoolSharesToProcess,
            totalPendingShares:    pendingSharesAfterSecondRedemption,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut,
            unrealizedLosses:      impairment
        });

        // First pool
        {
            uint256 strategyShares = firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess - secondPoolSharesToProcess;
            uint256 strategyAssets = firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut;

            uint256 shareBalanceAfterSecondRedemption   = firstPoolAssets - firstPoolSharesToProcess;
            uint256 assetBalanceAfterSecondRedemption   = shareBalanceAfterSecondRedemption * strategyAssets / strategyShares;
            uint256 unrealizedLossAfterSecondRedemption = divRoundUp(shareBalanceAfterSecondRedemption * impairment, strategyShares);

            assertPoolState({
                pool:               firstPool,
                totalAssets:        assetBalanceAfterSecondRedemption + firstAssetsOut,
                totalSupply:        firstPoolAssets,
                unrealizedLosses:   unrealizedLossAfterSecondRedemption,
                availableLiquidity: firstAssetsOut
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      firstPoolManager,
                assets:           assetBalanceAfterSecondRedemption,
                shares:           shareBalanceAfterSecondRedemption,
                pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
                unrealizedLosses: unrealizedLossAfterSecondRedemption
            });
        }

        // Second pool
        {
            uint256 strategyShares = firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess - secondPoolSharesToProcess;
            uint256 strategyAssets = firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut;

            uint256 shareBalanceAfterSecondRedemption   = secondPoolAssets - secondPoolSharesToProcess;
            uint256 assetBalanceAfterSecondRedemption   = shareBalanceAfterSecondRedemption * strategyAssets / strategyShares;
            uint256 unrealizedLossAfterSecondRedemption = divRoundUp(shareBalanceAfterSecondRedemption * impairment, strategyShares);

            assertPoolState({
                pool:               secondPool,
                totalAssets:        assetBalanceAfterSecondRedemption + secondAssetsOut,
                totalSupply:        secondPoolAssets,
                unrealizedLosses:   unrealizedLossAfterSecondRedemption,
                availableLiquidity: secondAssetsOut
            });

            assertStrategyManagerPosition({
                strategyManager:  strategyManager,
                poolManager:      secondPoolManager,
                assets:           assetBalanceAfterSecondRedemption,
                shares:           shareBalanceAfterSecondRedemption,
                pendingShares:    secondPoolSharesRequested - secondPoolSharesToProcess,
                unrealizedLosses: unrealizedLossAfterSecondRedemption
            });
        }

        assertEq(fundsAsset.balanceOf(firstPool),                    firstAssetsOut);
        assertEq(fundsAsset.balanceOf(secondPool),                   secondAssetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets + secondPoolAssets - firstAssetsOut - secondAssetsOut);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

    function test_processRedemption_success_multiplePoolManagersWithYield() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        uint256 yieldAssets = 150_000e6;
        uint32  duration    = 10 days;

        firstPoolAssets  = INITIAL_LIQUIDITY;
        secondPoolAssets = 500_000e6;

        firstPoolSharesRequested  = 200_000e6;
        secondPoolSharesRequested = 100_000e6;
        firstPoolSharesToProcess  = 100_000e6;
        secondPoolSharesToProcess = 50_000e6;

        firstPoolYield  = yieldAssets * firstPoolAssets / (firstPoolAssets + secondPoolAssets);
        secondPoolYield = yieldAssets - firstPoolYield;

        firstPoolYieldAssetsOut  = firstPoolSharesToProcess * (firstPoolAssets + firstPoolYield) / firstPoolAssets;
        secondPoolYieldAssetsOut = secondPoolSharesToProcess * (secondPoolAssets + secondPoolYield) / secondPoolAssets;

        /**********************************************************************************************************************************/
        /*** Fund a second pool manager and realize yield                                                                               ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManager);

        deposit(secondPool, makeAddr("lp2"), secondPoolAssets);
        fundStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, duration);

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets + firstPoolYield,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets + secondPoolYield,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets,
            recordedAssets:        firstPoolAssets + secondPoolAssets + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets + secondPoolAssets,
            totalPendingShares:    0,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets + firstPoolYield,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets + secondPoolYield,
            shares:           secondPoolAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets + secondPoolAssets + yieldAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Request shares from both pool managers                                                                                     ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesRequested);
        requestRedeemFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesRequested);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets + firstPoolYield,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets + secondPoolYield,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets,
            recordedAssets:        firstPoolAssets + secondPoolAssets + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets + secondPoolAssets,
            totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets + firstPoolYield,
            shares:           firstPoolAssets,
            pendingShares:    firstPoolSharesRequested,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets + secondPoolYield,
            shares:           secondPoolAssets,
            pendingShares:    secondPoolSharesRequested,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets + secondPoolAssets + yieldAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Process shares for the first pool manager                                                                                  ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, strategyManager, firstPoolSharesToProcess);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets + firstPoolYield,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolYieldAssetsOut
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets + secondPoolYield,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut,
            recordedAssets:        firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess,
            totalPendingShares:    firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets + firstPoolYield - firstPoolYieldAssetsOut,
            shares:           firstPoolAssets - firstPoolSharesToProcess,
            pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets + secondPoolYield,
            shares:           secondPoolAssets,
            pendingShares:    secondPoolSharesRequested,
            unrealizedLosses: 0
        });

        uint256 strategyBalanceAfterFirstRedemption = firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut;

        assertEq(fundsAsset.balanceOf(firstPool),                    firstPoolYieldAssetsOut);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), strategyBalanceAfterFirstRedemption);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Process shares for the second pool manager                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, strategyManager, secondPoolSharesToProcess);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets + firstPoolYield,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolYieldAssetsOut
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets + secondPoolYield,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: secondPoolYieldAssetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut,
            recordedAssets:        firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        uint256 remainingTotalShares = firstPoolAssets + secondPoolAssets - firstPoolSharesToProcess - secondPoolSharesToProcess;

        uint256 remainingPendingShares =
            firstPoolSharesRequested + secondPoolSharesRequested - firstPoolSharesToProcess - secondPoolSharesToProcess;

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           remainingTotalShares,
            totalPendingShares:    remainingPendingShares,
            assetsUnderManagement: firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut,
            availableToWithdraw:   firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets + firstPoolYield - firstPoolYieldAssetsOut,
            shares:           firstPoolAssets - firstPoolSharesToProcess,
            pendingShares:    firstPoolSharesRequested - firstPoolSharesToProcess,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets + secondPoolYield - secondPoolYieldAssetsOut,
            shares:           secondPoolAssets - secondPoolSharesToProcess,
            pendingShares:    secondPoolSharesRequested - secondPoolSharesToProcess,
            unrealizedLosses: 0
        });

        uint256 expectedStrategyBalance =
            firstPoolAssets + secondPoolAssets + yieldAssets - firstPoolYieldAssetsOut - secondPoolYieldAssetsOut;

        assertEq(fundsAsset.balanceOf(firstPool),                    firstPoolYieldAssetsOut);
        assertEq(fundsAsset.balanceOf(secondPool),                   secondPoolYieldAssetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), expectedStrategyBalance);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
    }

    function test_processRedemption_success_fullAvailableAmountWithPartiallyRealizedYieldAndFees() external {
        uint256 yieldAssets = 200_000e6;
        uint32  duration    = 10 days;

        uint32 delegateFeeRate = 0.1e6;   // 10% delegate fee
        uint32 protocolFeeRate = 0.05e6;  // 5% protocol fee

        uint256 delegateFee = 20_000e6;
        uint256 protocolFee = 10_000e6;
        uint256 netYield    = 170_000e6;
        uint256 vestedYield = netYield / 2;
        uint256 assetsOut   = INITIAL_LIQUIDITY + vestedYield;

        /**********************************************************************************************************************************/
        /*** Configure fees and partially realize yield                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).setStrategyDelegateFeeRate(delegateFeeRate);

        vm.prank(governor);
        IAllocationStrategy(allocationUnderlyingStrategy).setStrategyProtocolFeeRate(protocolFeeRate);

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, duration);

        vm.warp(block.timestamp + duration / 2);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsOut,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsOut,
            availableToWithdraw:   assetsOut,
            recordedAssets:        assetsOut + netYield - vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        vestedYield
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: assetsOut,
            availableToWithdraw:   assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           assetsOut,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY + netYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Request all shares                                                                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsOut,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsOut,
            availableToWithdraw:   assetsOut,
            recordedAssets:        assetsOut + netYield - vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        vestedYield
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    INITIAL_LIQUIDITY,
            assetsUnderManagement: assetsOut,
            availableToWithdraw:   assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           assetsOut,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY + netYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Process all shares                                                                                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsOut,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        netYield - vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        vestedYield
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), netYield - vestedYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
    }

    function test_processRedemption_success_afterPartiallyRealizedYieldCancelled() external {
        uint256 yieldAssets      = 200_000e6;
        uint256 request          = 400_000e6;
        uint256 vestedYield      = yieldAssets / 2;
        uint256 assetsOut        = request * (INITIAL_LIQUIDITY + vestedYield) / INITIAL_LIQUIDITY;
        uint32  duration         = 10 days;
        uint32  cancellationTime = startingTime + duration / 2;

        /**********************************************************************************************************************************/
        /*** Partially realize and cancel yield                                                                                         ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, duration);

        vm.warp(cancellationTime);

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).cancelYield(type(uint256).max, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield,
            recordedAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           cancellationTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + vestedYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY + vestedYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                yieldAssets - vestedYield);

        /**********************************************************************************************************************************/
        /*** Request shares                                                                                                             ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield,
            recordedAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           cancellationTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + vestedYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY + vestedYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                yieldAssets - vestedYield);

        /**********************************************************************************************************************************/
        /*** Process shares                                                                                                             ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield - assetsOut,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield - assetsOut,
            recordedAssets:        INITIAL_LIQUIDITY + vestedYield - assetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           cancellationTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - request,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield - assetsOut,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield - assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + vestedYield - assetsOut,
            shares:           INITIAL_LIQUIDITY - request,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), INITIAL_LIQUIDITY + vestedYield - assetsOut);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(fundsAsset.balanceOf(managedWallet),                yieldAssets - vestedYield);
    }

    function test_processRedemption_success_immediatelyAfterFundingImpairedStrategy() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        uint256 impairment = 250_000e6;

        firstPoolAssets  = INITIAL_LIQUIDITY;
        secondPoolAssets = 500_000e6;

        uint256 totalAssets = firstPoolAssets + secondPoolAssets;
        uint256 assetsOut   = secondPoolAssets * (totalAssets - impairment) / totalAssets;
        uint256 firstLoss   = divRoundUp(firstPoolAssets  * impairment, totalAssets);
        uint256 secondLoss  = divRoundUp(secondPoolAssets * impairment, totalAssets);

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: firstPoolAssets,
            availableToWithdraw:   firstPoolAssets,
            recordedAssets:        firstPoolAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets,
            totalPendingShares:    0,
            assetsUnderManagement: firstPoolAssets,
            availableToWithdraw:   firstPoolAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), firstPoolAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Fund the impaired strategy from a second pool manager                                                                      ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManager);

        deposit(secondPool, makeAddr("lp2"), secondPoolAssets);
        fundStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   firstLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   secondLoss,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets,
            shares:           secondPoolAssets,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Request all shares from the second pool manager                                                                            ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   firstLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondPoolAssets,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   secondLoss,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            recordedAssets:        totalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalAssets,
            totalPendingShares:    secondPoolAssets,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolAssets,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolAssets,
            shares:           secondPoolAssets,
            pendingShares:    secondPoolAssets,
            unrealizedLosses: secondLoss
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process all shares from the second pool manager                                                                            ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, strategyManager, secondPoolAssets);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        totalAssets - assetsOut,
            totalSupply:        firstPoolAssets,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        assetsOut,
            totalSupply:        secondPoolAssets,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets - assetsOut,
            availableToWithdraw:   totalAssets - assetsOut,
            recordedAssets:        totalAssets - assetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           firstPoolAssets,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets - assetsOut,
            availableToWithdraw:   totalAssets - assetsOut,
            unrealizedLosses:      impairment
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
            poolManager:      firstPoolManager,
            assets:           totalAssets - assetsOut,
            shares:           firstPoolAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(firstPool),                    0);
        assertEq(fundsAsset.balanceOf(secondPool),                   assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssets - assetsOut);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
        assertEq(secondPoolAssets - assetsOut,                       secondLoss);
    }

    function test_processRedemption_success_increasingExchangeRate() external {
        uint256 yieldAssets   = INITIAL_LIQUIDITY / 5;
        uint256 request       = INITIAL_LIQUIDITY * 2 / 5;
        uint256 processAmount = request / 3;
        uint32  duration      = 10 days;

        uint256 aumAfterYield = INITIAL_LIQUIDITY + yieldAssets;

        // Partial shares convert to assets with round-down division.
        uint256 assetsOut     = processAmount * aumAfterYield / INITIAL_LIQUIDITY;

        /**********************************************************************************************************************************/
        /*** Add yield that remains unrealized                                                                                          ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY + yieldAssets,
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

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Warp to the yield deadline                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            recordedAssets:        aumAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Request shares at the higher exchange rate                                                                                 ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            recordedAssets:        aumAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY,
            totalPendingShares:    request,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);

        /**********************************************************************************************************************************/
        /*** Process shares at the higher exchange rate                                                                                 ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManager, processAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield - assetsOut,
            availableToWithdraw:   aumAfterYield - assetsOut,
            recordedAssets:        aumAfterYield - assetsOut,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           INITIAL_LIQUIDITY - processAmount,
            totalPendingShares:    request - processAmount,
            assetsUnderManagement: aumAfterYield - assetsOut,
            availableToWithdraw:   aumAfterYield - assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield - assetsOut,
            shares:           INITIAL_LIQUIDITY - processAmount,
            pendingShares:    request - processAmount,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), aumAfterYield - assetsOut);
        assertEq(fundsAsset.balanceOf(strategyManager),              0);
    }

}
