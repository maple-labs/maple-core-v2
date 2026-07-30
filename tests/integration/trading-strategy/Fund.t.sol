// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolManager, IStrategyManager, ITradingStrategy } from "../../../contracts/interfaces/Interfaces.sol";
import { TradingStrategyInitializerParams }                 from "../../../contracts/interfaces/Interfaces.sol";

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyFundFailureTests is TradingStrategyTestBase {

    function setUp() public override {
        super.setUp();

        deposit(lp, INITIAL_LIQUIDITY);
    }

    function test_fundUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MTS:NOT_STRATEGY_MANAGER");
        ITradingStrategy(tradingUnderlyingStrategy).fundUnderlyingStrategy(INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_strategyPausedThroughStrategyManager() external {
        vm.prank(governor);
        globals.setContractPause(tradingUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_strategyManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(tradingStrategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_notOperator() external {
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_strategyManagerNotActive() external {
        address inactiveStrategyDelegate = makeAddr("inactiveStrategyDelegate");

        TradingStrategyInitializerParams memory params = TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        });

        vm.prank(governor);
        globals.setValidStrategyDelegate(inactiveStrategyDelegate, true);

        vm.prank(inactiveStrategyDelegate);
        ( address inactiveStrategyManager, ) =
            strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, 0, abi.encode(params), "");

        vm.prank(inactiveStrategyDelegate);
        vm.expectRevert("MSM:FSM:NOT_ACTIVE");
        IStrategyManager(inactiveStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_ASSETS");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), 0, "");
    }

    function test_fundUnderlyingStrategy_revert_invalidPoolManagerFactory() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(queueWM), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_nonInstancePoolManager() external {
        address fakePoolManager = makeAddr("fakePoolManager");

        vm.mockCall(fakePoolManager, abi.encodeWithSignature("factory()"), abi.encode(poolManagerFactory));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(fakePoolManager, INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_exceedingPoolStrategyCap() external {
        uint256 cap = 500_000e6;

        vm.prank(governor);
        poolManager.setStrategyCap(tradingStrategyManager, cap);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), cap + 1, "");
    }

    function test_fundUnderlyingStrategy_revert_insufficientPoolLiquidity() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY + 1, "");
    }

    function test_fundUnderlyingStrategy_revert_zeroSharesMinted() external {
        uint256 assets      = 900_000e6;
        uint256 yieldAssets = 100_000e6;
        uint32  duration    = 10 days;

        fundStrategyManager(address(poolManager), tradingStrategyManager, assets);

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        vm.warp(block.timestamp + duration);

        // With the exchange rate above one, 1 wei converts to 1 * assets / (assets + yieldAssets) shares, rounding down to zero.
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), 1, "");
    }

    function test_fundUnderlyingStrategy_revert_blockedPoolManager() external {
        vm.prank(strategyDelegate);
        IStrategyManager(tradingStrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), INITIAL_LIQUIDITY, "");
    }

    function test_fundUnderlyingStrategy_revert_poolManagerCapExceeded_boundary() external {
        uint256 cap = 500_000e6;

        vm.prank(strategyDelegate);
        IStrategyManager(tradingStrategyManager).setPoolManagerCap(address(poolManager), cap);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), cap + 1, "");
    }

    function test_fundUnderlyingStrategy_revert_strategyLiquidityCapExceeded_boundary() external {
        uint256 cap = 500_000e6;

        vm.prank(strategyDelegate);
        IStrategyManager(tradingStrategyManager).setStrategyLiquidityCap(cap);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), cap + 1, "");
    }

}

contract TradingStrategyFundSuccessTests is TradingStrategyTestBase {

    function setUp() public override {
        super.setUp();

        deposit(lp, INITIAL_LIQUIDITY);
    }

    function test_fundUnderlyingStrategy_success_secondFundingExistingAum() external {
        uint256 firstAssets  = 400_000e6;
        uint256 secondAssets = 600_000e6;

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy for the first time                                                                               ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, firstAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: firstAssets,
            availableToWithdraw:   firstAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAssets,
            shares:           firstAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        firstAssets,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             INITIAL_LIQUIDITY - firstAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), firstAssets);

        /**********************************************************************************************************************************/
        /*** Step 3: Fund the same pool manager position again                                                                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);
    }

    function test_fundUnderlyingStrategy_success_withOperatorRoles() external {
        uint256 firstAssets  = 400_000e6;
        uint256 secondAssets = 600_000e6;

        address newLiquidityBot = makeAddr("newLiquidityBot");
        address liquidityRouter = makeAddr("liquidityRouter");

        vm.startPrank(governor);
        globals.setValidInstanceOf("LIQUIDITY_BOT",    newLiquidityBot, true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", liquidityRouter, true);
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund as the liquidity bot                                                                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(newLiquidityBot);
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), firstAssets, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: firstAssets,
            availableToWithdraw:   firstAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAssets,
            shares:           firstAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        firstAssets,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             INITIAL_LIQUIDITY - firstAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), firstAssets);

        /**********************************************************************************************************************************/
        /*** Step 3: Fund as the liquidity router                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityRouter);
        IStrategyManager(tradingStrategyManager).fundStrategyManager(address(poolManager), secondAssets, "");

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);
    }

    function test_fundUnderlyingStrategy_success_afterFullExit() external {
        uint256 secondAssets = 600_000e6;

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the full position                                                                                             ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Request a full redemption                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    INITIAL_LIQUIDITY,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: INITIAL_LIQUIDITY
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 4: Process the full redemption                                                                                        ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: INITIAL_LIQUIDITY
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);

        /**********************************************************************************************************************************/
        /*** Step 5: Fund again from zero strategy manager shares                                                                       ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: INITIAL_LIQUIDITY - secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: secondAssets,
            availableToWithdraw:   secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           secondAssets,
            shares:           secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        secondAssets,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             INITIAL_LIQUIDITY - secondAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), secondAssets);
    }

    function test_fundUnderlyingStrategy_success_afterAssetsDeployed() external {
        uint256 firstAssets    = 700_000e6;
        uint256 secondAssets   = 300_000e6;
        uint256 deployedAssets = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the first tranche                                                                                             ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, firstAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: firstAssets,
            availableToWithdraw:   firstAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAssets,
            shares:           firstAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        firstAssets,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),             secondAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), firstAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets from the trading strategy                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(trader);
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployedAssets, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: firstAssets,
            availableToWithdraw:   firstAssets - deployedAssets,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAssets,
            shares:           firstAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        firstAssets,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),             secondAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), firstAssets - deployedAssets);
        assertEq(fundsAsset.balanceOf(trader),                    deployedAssets);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund more assets while the strategy has deployed exposure                                                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

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
            availableToWithdraw:   INITIAL_LIQUIDITY - deployedAssets,
            totalDeployedAssets:   deployedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY - deployedAssets);
        assertEq(fundsAsset.balanceOf(trader),                    deployedAssets);
    }

    function test_fundUnderlyingStrategy_success_withUnrealizedYield() external {
        uint256 secondAssets    = 500_000e6;
        uint256 unrealizedYield = 100_000e6;
        uint32  duration        = 10 days;

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Add yield that remains unrealized                                                                                  ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, unrealizedYield, duration);

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
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + unrealizedYield);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund again while the yield is still excluded from AUM                                                              ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + secondAssets,
            shares:           INITIAL_LIQUIDITY + secondAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + secondAssets + unrealizedYield);
    }

    function test_fundUnderlyingStrategy_success_withFullyRealizedYield() external {
        uint256 yieldAssets  = 100_000e6;
        uint256 secondAssets = 550_000e6;
        uint32  duration     = 10 days;

        uint256 expectedShares = 500_000e6;  // secondAssets * INITIAL_LIQUIDITY / (INITIAL_LIQUIDITY + yieldAssets)

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Realize yield and warp past the yield deadline                                                                     ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + yieldAssets,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund again at an exchange rate above one                                                                           ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + expectedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            shares:           INITIAL_LIQUIDITY + expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets + secondAssets);
    }

    function test_fundUnderlyingStrategy_success_withMidVestingYield() external {
        uint256 yieldAssets  = 100_000e6;
        uint256 vestedYield  = 20_000e6;   // 100_000e6 * 2 days / 10 days
        uint256 secondAssets = 510_000e6;
        uint32  duration     = 10 days;

        uint256 expectedShares = 500_000e6;  // secondAssets * INITIAL_LIQUIDITY / (INITIAL_LIQUIDITY + vestedYield)

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Realize yield and warp partway through the vesting period                                                          ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        // Warp to an asymmetric point of the vesting period so swapped realized/unrealized terms cannot cancel out.
        vm.warp(block.timestamp + duration / 5);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + vestedYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        vestedYield
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + vestedYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund mid-vesting at an exchange rate above one                                                                     ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + vestedYield + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + expectedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + vestedYield + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + vestedYield + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        vestedYield
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + vestedYield + secondAssets,
            shares:           INITIAL_LIQUIDITY + expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + secondAssets + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 5: Warp past the deadline so remaining yield accrues to the position                                                  ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + expectedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            shares:           INITIAL_LIQUIDITY + expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets + secondAssets);
    }

    function test_fundUnderlyingStrategy_success_withStrategyFees() external {
        uint256 yieldAssets  = 200_000e6;
        uint256 secondAssets = 585_000e6;
        uint32  duration     = 10 days;

        uint32 delegateFeeRate = 0.1e6;   // 10% of yield
        uint32 protocolFeeRate = 0.05e6;  // 5% of yield

        uint256 delegateFee = 20_000e6;   // 200_000e6 * 0.1e6 / 1e6
        uint256 protocolFee = 10_000e6;   // 200_000e6 * 0.05e6 / 1e6
        uint256 netYield    = 170_000e6;  // 200_000e6 - 20_000e6 - 10_000e6

        uint256 expectedShares = 500_000e6;  // secondAssets * INITIAL_LIQUIDITY / (INITIAL_LIQUIDITY + netYield)

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Set the strategy fee rates and fund the strategy                                                                   ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(tradingUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(tradingUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        /**********************************************************************************************************************************/
        /*** Step 3: Realize yield, paying the delegate and protocol fees upfront                                                       ***/
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
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Step 4: Warp past the yield deadline so the net yield vests                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + netYield,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + netYield,
            availableToWithdraw:   INITIAL_LIQUIDITY + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + netYield,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Step 5: Fund again at the post-fee exchange rate                                                                           ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + netYield + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + expectedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + netYield + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + netYield + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + netYield + secondAssets,
            shares:           INITIAL_LIQUIDITY + expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + netYield + secondAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_fundUnderlyingStrategy_success_withImpairment() external {
        uint256 secondAssets = 500_000e6;
        uint256 impairment   = 250_000e6;

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Impair the strategy                                                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).impair(impairment);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund again while the impairment remains active                                                                     ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + secondAssets,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY + secondAssets,
            shares:           INITIAL_LIQUIDITY + secondAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + secondAssets,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + secondAssets);
    }

    function test_fundUnderlyingStrategy_success_afterLossRecognition() external {
        uint256 deployed     = 400_000e6;
        uint256 loss         = 250_000e6;
        uint256 secondAssets = 300_000e6;

        uint256 expectedShares = 400_000e6;  // secondAssets * INITIAL_LIQUIDITY / (INITIAL_LIQUIDITY - loss)

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy and deploy assets                                                                                ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

        vm.prank(trader);
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployed, "");

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
            availableToWithdraw:   INITIAL_LIQUIDITY - deployed,
            totalDeployedAssets:   deployed,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployed);

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY - deployed);
        assertEq(fundsAsset.balanceOf(trader),                    deployed);

        /**********************************************************************************************************************************/
        /*** Step 3: Recognize a loss on the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).recognizeLoss(loss, trader);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY - loss,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - loss,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployed,
            totalDeployedAssets:   deployed - loss,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - loss,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployed - loss);

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY - deployed);
        assertEq(fundsAsset.balanceOf(trader),                    deployed);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund at an exchange rate below one                                                                                 ***/
        /**********************************************************************************************************************************/

        deposit(lp, secondAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, secondAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        INITIAL_LIQUIDITY - loss + secondAssets,
            totalSupply:        INITIAL_LIQUIDITY + expectedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY - loss + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY - deployed + secondAssets,
            totalDeployedAssets:   deployed - loss,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY - loss + secondAssets,
            shares:           INITIAL_LIQUIDITY + expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployed - loss);

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY - deployed + secondAssets);
        assertEq(fundsAsset.balanceOf(trader),                    deployed);
    }

    function test_fundUnderlyingStrategy_success_atPoolManagerAndStrategyLiquidityCaps() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Configure exact funding caps                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.startPrank(strategyDelegate);
        IStrategyManager(tradingStrategyManager).setPoolManagerCap(address(poolManager), INITIAL_LIQUIDITY);
        IStrategyManager(tradingStrategyManager).setStrategyLiquidityCap(INITIAL_LIQUIDITY);
        vm.stopPrank();

        assertEq(IStrategyManager(tradingStrategyManager).poolManagerCapOf(address(poolManager)), INITIAL_LIQUIDITY);
        assertEq(IStrategyManager(tradingStrategyManager).strategyLiquidityCap(),                 INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Fund exactly to both caps                                                                                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), tradingStrategyManager, INITIAL_LIQUIDITY);

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

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),             0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);
    }

    function test_fundUnderlyingStrategy_success_multiplePoolManagers() external {
        uint256 yieldAssets  = 100_000e6;
        uint256 secondAssets = 550_000e6;
        uint32  duration     = 10 days;

        uint256 expectedShares = 500_000e6;  // secondAssets * INITIAL_LIQUIDITY / (INITIAL_LIQUIDITY + yieldAssets)

        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        address lp2 = makeAddr("lp2");

        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        assertInitialStateWithTrading(tradingStrategyManager, INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund from the first pool at an exchange rate of one                                                                ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManager1, tradingStrategyManager, INITIAL_LIQUIDITY);

        assertPoolState({
            pool:               pool1,
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
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           INITIAL_LIQUIDITY,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(pool1),                     0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY);

        /**********************************************************************************************************************************/
        /*** Step 3: Fully vest yield into the first pool position                                                                      ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        vm.warp(block.timestamp + duration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           INITIAL_LIQUIDITY + yieldAssets,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(pool1),                     0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 4: Create a second pool and add the same strategy manager                                                             ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("poolDelegate2", tradingStrategyManager);

        address queueWM2 = IPoolManager(poolManager2).withdrawalManager();

        allowLender(poolManager2, queueWM2);
        openPool(poolManager2);

        assertPoolState({
            pool:               pool2,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(pool1),                     0);
        assertEq(fundsAsset.balanceOf(pool2),                     0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 5: Deposit liquidity into the second pool                                                                             ***/
        /**********************************************************************************************************************************/

        deposit(pool2, lp2, secondAssets);

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondAssets,
            totalSupply:        secondAssets,
            unrealizedLosses:   0,
            availableLiquidity: secondAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        // The first pool's position is unaffected by the second pool joining.
        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           INITIAL_LIQUIDITY + yieldAssets,
            shares:           INITIAL_LIQUIDITY,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(pool1),                     0);
        assertEq(fundsAsset.balanceOf(pool2),                     secondAssets);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets);

        /**********************************************************************************************************************************/
        /*** Step 6: Fund from the second pool at the higher exchange rate                                                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManager2, tradingStrategyManager, secondAssets);

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            availableToWithdraw:   INITIAL_LIQUIDITY + yieldAssets + secondAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAssets
        });

        assertPoolState({
            pool:               pool1,
            totalAssets:        INITIAL_LIQUIDITY + yieldAssets,
            totalSupply:        INITIAL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           INITIAL_LIQUIDITY + yieldAssets,
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
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           secondAssets,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        // Shares are conserved across pool manager positions.
        assertStrategyManagerShares({
            strategyManager:    tradingStrategyManager,
            totalShares:        INITIAL_LIQUIDITY + expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(pool1),                     0);
        assertEq(fundsAsset.balanceOf(pool2),                     0);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), INITIAL_LIQUIDITY + yieldAssets + secondAssets);
    }

}
