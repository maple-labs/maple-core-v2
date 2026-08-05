// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IPool,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract StrategyManagerRequestRedeemTestBase is TestBaseWithAssertions {

    uint256 constant INITIAL_LIQUIDITY = 1_000_000e6;

    address lp = makeAddr("lp");

    function setUp() public virtual override {
        super.setUp();

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        strategyManager = allocationStrategyManager;

        addStrategyManagerToPool(address(poolManager), strategyManager);
    }

}

contract StrategyManagerRequestRedeemFailureTests is StrategyManagerRequestRedeemTestBase {

    function test_requestRedeem_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_strategyManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(strategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_notOperatorOrPoolDelegate() external {
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_liquidityBotWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_liquidityRouterWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        address liquidityRouter = makeAddr("liquidityRouter");

        vm.prank(governor);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", liquidityRouter, true);

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);

        vm.prank(liquidityRouter);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_invalidPoolManagerFactory() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:RR:INVALID_PM");
        IStrategyManager(strategyManager).requestRedeem(address(queueWM), INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_nonInstancePoolManager() external {
        address fakePoolManager = makeAddr("fakePoolManager");

        vm.mockCall(fakePoolManager, abi.encodeWithSignature("factory()"), abi.encode(poolManagerFactory));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:RR:INVALID_PM");
        IStrategyManager(strategyManager).requestRedeem(fakePoolManager, INITIAL_LIQUIDITY);
    }

    function test_requestRedeem_revert_zeroShares() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:RR:ZERO_SHARES");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), 0);
    }

    function test_requestRedeem_revert_insufficientShares_emptyPosition() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:RR:INSUFFICIENT_SHARES");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), 1);
    }

    function test_requestRedeem_revert_insufficientShares_existingPending() external {
        uint256 firstRequest  = INITIAL_LIQUIDITY * 2 / 5;
        uint256 secondRequest = INITIAL_LIQUIDITY - firstRequest + 1;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, firstRequest);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:RR:INSUFFICIENT_SHARES");
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), secondRequest);
    }

}

contract StrategyManagerRequestRedeemSuccessTests is StrategyManagerRequestRedeemTestBase {

    function setUp() public override {
        super.setUp();

        assertInitialStateWithAllocation({
            strategyManager:  strategyManager,
            initialLiquidity: 0
        });

        deposit(lp, INITIAL_LIQUIDITY);

        assertInitialStateWithAllocation({
            strategyManager:  strategyManager,
            initialLiquidity: INITIAL_LIQUIDITY
        });

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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });
    }

    function test_requestRedeem_success_multipleRequests() external {
        uint256 firstRequest  = INITIAL_LIQUIDITY / 4;
        uint256 secondRequest = INITIAL_LIQUIDITY - firstRequest;

        /**********************************************************************************************************************************/
        /*** Step 1: Request the first tranche                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, firstRequest);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    firstRequest,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: firstRequest
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Request the remaining shares                                                                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, secondRequest);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: INITIAL_LIQUIDITY
        });
    }

    function test_requestRedeem_success_withOperatorRoles() external {
        uint256 firstRequest  = INITIAL_LIQUIDITY * 2 / 5;
        uint256 secondRequest = INITIAL_LIQUIDITY - firstRequest;

        address newLiquidityBot = makeAddr("newLiquidityBot");
        address liquidityRouter = makeAddr("liquidityRouter");

        assertEq(globals.isInstanceOf("LIQUIDITY_BOT",    newLiquidityBot), false);
        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", liquidityRouter), false);

        /**********************************************************************************************************************************/
        /*** Step 1: Configure the operator roles                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.startPrank(governor);
        globals.setValidInstanceOf("LIQUIDITY_BOT",    newLiquidityBot, true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", liquidityRouter, true);
        vm.stopPrank();

        assertEq(globals.isInstanceOf("LIQUIDITY_BOT",    newLiquidityBot), true);
        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", liquidityRouter), true);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Request as the liquidity bot                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(newLiquidityBot);
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), firstRequest);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    firstRequest,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: firstRequest
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Request as the liquidity router                                                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityRouter);
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), secondRequest);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: INITIAL_LIQUIDITY
        });
    }

    function test_requestRedeem_success_asPoolDelegate() external {
        uint256 request = INITIAL_LIQUIDITY / 3;

        /**********************************************************************************************************************************/
        /*** Step 1: Request shares as the pool delegate                                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IStrategyManager(strategyManager).requestRedeem(address(poolManager), request);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request
        });
    }

    function test_requestRedeem_success_withImpairment() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;
        uint256 request    = INITIAL_LIQUIDITY * 2 / 5;

        /**********************************************************************************************************************************/
        /*** Step 1: Impair strategy assets                                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).impair(impairment);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Request shares from the impaired position                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

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

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: impairment
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request
        });
    }

    function test_requestRedeem_success_multiplePoolManagers() external {
        uint256 secondAssets = INITIAL_LIQUIDITY / 3;
        uint256 request1     = secondAssets * 3 / 5;
        uint256 request2     = secondAssets - request1;

        address pool1 = address(pool);

        /**********************************************************************************************************************************/
        /*** Step 1: Create a second pool                                                                                               ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("poolDelegate2", strategyManager);

        openPool(poolManager2);

        assertEq(globals.isPoolDelegate(makeAddr("poolDelegate2")), true);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deposit liquidity into the second pool                                                                             ***/
        /**********************************************************************************************************************************/

        deposit(pool2, makeAddr("lp2"), secondAssets);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondAssets,
            totalSupply:        secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            recordedAssets:        INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund from the second pool                                                                                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManager2, strategyManager, secondAssets);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondAssets,
            totalSupply:        secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            recordedAssets:        INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Request shares from the first pool                                                                                 ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(IPool(pool1).manager(), strategyManager, request1);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondAssets,
            totalSupply:        secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            recordedAssets:        INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Request shares from the second pool                                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManager2, strategyManager, request2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondAssets,
            totalSupply:        secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    request2,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            recordedAssets:        INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1 + request2
        });
    }

}
