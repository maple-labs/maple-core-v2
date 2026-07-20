// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    Action,
    ActionType,
    IPool,
    IPoolManager,
    IStrategyManager,
    ITradingStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract StrategyManagerCancelRedemptionTestBase is TestBaseWithAssertions {

    uint256 constant INITIAL_LIQUIDITY = 1_000_000e6;

    address lp     = makeAddr("lp");
    address trader = makeAddr("trader");

    function setUp() public virtual override {
        super.setUp();

        _deployTradingStrategy();

        strategyManager = tradingStrategyManager;

        addStrategyManagerToPool(address(poolManager), strategyManager);

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  trader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
    }

}

contract StrategyManagerCancelRedemptionFailureTests is StrategyManagerCancelRedemptionTestBase {

    function test_cancelRedemption_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_strategyManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(strategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_notOperatorOrPoolDelegate() external {
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_wrongPoolDelegate() external {
        uint256 request = INITIAL_LIQUIDITY / 2;

        address firstPoolManager = address(poolManager);

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(firstPoolManager, strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(firstPoolManager, strategyManager, request);

        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManager);

        address secondPoolDelegate = IPoolManager(secondPoolManager).poolDelegate();

        assertNotEq(secondPoolDelegate, poolDelegate);
        assertEq(IStrategyManager(strategyManager).pendingSharesOf(firstPoolManager), request);

        vm.prank(secondPoolDelegate);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).cancelRedemption(firstPoolManager, request);
    }

    function test_cancelRedemption_revert_liquidityBotWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        impairTradingStrategy(tradingUnderlyingStrategy, impairment);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_liquidityRouterWhenImpaired() external {
        uint256 impairment = INITIAL_LIQUIDITY / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        impairTradingStrategy(tradingUnderlyingStrategy, impairment);

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.CANCEL_REDEMPTION,
            strategyManager: strategyManager,
            poolManager:     address(poolManager),
            amount:          INITIAL_LIQUIDITY,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_cancelRedemption_revert_invalidPoolManagerFactory() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:CR:INVALID_PM");
        IStrategyManager(strategyManager).cancelRedemption(address(queueWM), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_nonInstancePoolManager() external {
        address fakePoolManager = makeAddr("fakePoolManager");

        vm.mockCall(fakePoolManager, abi.encodeWithSignature("factory()"), abi.encode(poolManagerFactory));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:CR:INVALID_PM");
        IStrategyManager(strategyManager).cancelRedemption(fakePoolManager, INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_revert_zeroShares() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:CR:ZERO_SHARES");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), 0);
    }

    function test_cancelRedemption_revert_insufficientShares_noPendingShares() external {
        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:CR:INSUFFICIENT_SHARES");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), 1);
    }

    function test_cancelRedemption_revert_insufficientShares_exceedsPendingShares() external {
        uint256 request = INITIAL_LIQUIDITY * 2 / 5;

        deposit(lp, INITIAL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);
        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:CR:INSUFFICIENT_SHARES");
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), request + 1);
    }

}

contract StrategyManagerCancelRedemptionSuccessTests is StrategyManagerCancelRedemptionTestBase {

    function setUp() public override {
        super.setUp();

        assertInitialStateWithTrading({
            strategyManager:  strategyManager,
            initialLiquidity: 0
        });

        deposit(lp, INITIAL_LIQUIDITY);

        assertInitialStateWithTrading({
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

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

    function test_cancelRedemption_success_withOperatorRoles() external {
        uint256 firstCancellation  = INITIAL_LIQUIDITY * 2 / 5;
        uint256 secondCancellation = INITIAL_LIQUIDITY - firstCancellation;

        address newLiquidityBot    = makeAddr("newLiquidityBot");
        address newLiquidityRouter = makeAddr("liquidityRouter");

        assertEq(globals.isInstanceOf("LIQUIDITY_BOT",    newLiquidityBot),    false);
        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", newLiquidityRouter), false);

        /**********************************************************************************************************************************/
        /*** Step 1: Configure the operator roles                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.startPrank(governor);
        globals.setValidInstanceOf("LIQUIDITY_BOT",    newLiquidityBot,    true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", newLiquidityRouter, true);
        vm.stopPrank();

        assertEq(globals.isInstanceOf("LIQUIDITY_BOT",    newLiquidityBot),    true);
        assertEq(globals.isInstanceOf("LIQUIDITY_ROUTER", newLiquidityRouter), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

        /**********************************************************************************************************************************/
        /*** Step 2: Request all of the shares                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 3: Cancel as the liquidity bot                                                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(newLiquidityBot);
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), firstCancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    secondCancellation,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: secondCancellation
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Cancel as the liquidity router                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(newLiquidityRouter);
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), secondCancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

    function test_cancelRedemption_success_asPoolDelegate() external {
        uint256 request      = INITIAL_LIQUIDITY / 3;
        uint256 cancellation = request / 3;

        /**********************************************************************************************************************************/
        /*** Step 1: Request shares                                                                                                     ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel shares as the pool delegate                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        IStrategyManager(strategyManager).cancelRedemption(address(poolManager), cancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request - cancellation,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request - cancellation
        });
    }

    function test_cancelRedemption_success_multipleCancellations() external {
        uint256 firstCancellation  = INITIAL_LIQUIDITY / 4;
        uint256 secondCancellation = INITIAL_LIQUIDITY - firstCancellation;

        /**********************************************************************************************************************************/
        /*** Step 1: Request all of the shares                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel the first tranche                                                                                           ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, firstCancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    secondCancellation,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: secondCancellation
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Cancel the remaining shares                                                                                        ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, secondCancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

    function test_cancelRedemption_success_requestAgainAfterCancellation() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Request all of the shares                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 2: Cancel all of the shares                                                                                           ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

        /**********************************************************************************************************************************/
        /*** Step 3: Request all of the shares again                                                                                    ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

    function test_cancelRedemption_success_multiplePoolManagers() external {
        uint256 secondAssets = INITIAL_LIQUIDITY / 3;
        uint256 request1     = INITIAL_LIQUIDITY * 3 / 5;
        uint256 request2     = secondAssets * 3 / 5;
        uint256 cancel1      = request1 / 2;
        uint256 cancel2      = request2 / 3;

        address pool1 = address(pool);

        /**********************************************************************************************************************************/
        /*** Step 1: Create a second pool, deposit liquidity, and fund                                                                  ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("poolDelegate2", strategyManager);

        openPool(poolManager2);

        deposit(pool2, makeAddr("lp2"), secondAssets);
        fundStrategyManager(poolManager2, strategyManager, secondAssets);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
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
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Request shares from the first pool                                                                                 ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(IPool(pool1).manager(), strategyManager, request1);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
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
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Request shares from the second pool                                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManager2, strategyManager, request2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
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
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    request2,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1 + request2
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Cancel shares from the first pool                                                                                  ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(IPool(pool1).manager(), strategyManager, cancel1);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
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
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1 - cancel1,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    request2,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1 - cancel1 + request2
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Cancel shares from the second pool                                                                                 ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(poolManager2, strategyManager, cancel2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
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
            poolManager:      IPool(pool1).manager(),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request1 - cancel1,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    request2 - cancel2,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: request1 - cancel1 + request2 - cancel2
        });
    }

    function test_cancelRedemption_success_withImpairment() external {
        uint256 impairment   = INITIAL_LIQUIDITY / 5;
        uint256 request      = INITIAL_LIQUIDITY * 2 / 5;
        uint256 cancellation = request / 3;

        /**********************************************************************************************************************************/
        /*** Step 1: Request shares                                                                                                     ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 2: Impair strategy assets                                                                                             ***/
        /**********************************************************************************************************************************/

        impairTradingStrategy(tradingUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        /**********************************************************************************************************************************/
        /*** Step 3: Cancel shares from the impaired position                                                                           ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, cancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request - cancellation,
            unrealizedLosses: impairment
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request - cancellation
        });
    }

    function test_cancelRedemption_success_illiquidStrategy() external {
        uint256 request      = INITIAL_LIQUIDITY * 2 / 5;
        uint256 cancellation = request / 3;

        assertEq(fundsAsset.balanceOf(trader),                                         0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy all strategy assets                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(trader);
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(INITIAL_LIQUIDITY, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   0,
            totalDeployedAssets:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
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

        assertEq(IStrategyManager(strategyManager).availableToWithdraw(),              0);
        assertEq(fundsAsset.balanceOf(trader),                                         INITIAL_LIQUIDITY);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Request shares from the illiquid strategy                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   0,
            totalDeployedAssets:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
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

        assertEq(IStrategyManager(strategyManager).availableToWithdraw(),              0);
        assertEq(fundsAsset.balanceOf(trader),                                         INITIAL_LIQUIDITY);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Cancel shares from the illiquid strategy                                                                           ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, cancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   0,
            totalDeployedAssets:   INITIAL_LIQUIDITY,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request - cancellation,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request - cancellation
        });

        assertEq(IStrategyManager(strategyManager).availableToWithdraw(),              0);
        assertEq(fundsAsset.balanceOf(trader),                                         INITIAL_LIQUIDITY);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), INITIAL_LIQUIDITY);
    }

    function test_cancelRedemption_success_increasingExchangeRate() external {
        uint256 yieldAssets  = INITIAL_LIQUIDITY / 5;
        uint256 request      = INITIAL_LIQUIDITY * 2 / 5;
        uint256 cancellation = request / 3;
        uint32  duration     = 10 days;

        uint256 aumAfterYield = INITIAL_LIQUIDITY + yieldAssets;

        /**********************************************************************************************************************************/
        /*** Step 1: Add yield that remains unrealized                                                                                  ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY,
            availableToWithdraw:   INITIAL_LIQUIDITY,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
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

        /**********************************************************************************************************************************/
        /*** Step 2: Warp to the yield deadline                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
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
        /*** Step 3: Request shares at the higher exchange rate                                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, request);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Cancel shares at the higher exchange rate                                                                          ***/
        /**********************************************************************************************************************************/

        cancelRedemptionFromStrategyManager(address(poolManager), strategyManager, cancellation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        aumAfterYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: aumAfterYield,
            availableToWithdraw:   aumAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    request - cancellation,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: request - cancellation
        });
    }

}
