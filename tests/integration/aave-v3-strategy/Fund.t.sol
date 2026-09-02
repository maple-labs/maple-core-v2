// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    AaveV3StrategyInitializerParams,
    IAavePoolLike,
    IAaveV3Strategy,
    IERC20,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { FakePoolManager } from "../../mocks/Mocks.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyFundFailureTests is AaveV3StrategyTestBase {

    uint256 assets                = 1_000_000e6;
    uint256 expectedRoundingError = 1;

    bytes expectedReserveFrozenError     = abi.encodeWithSignature("ReserveFrozen()");
    bytes expectedReservePausedError     = abi.encodeWithSignature("ReservePaused()");
    bytes expectedSupplyCapExceededError = abi.encodeWithSignature("SupplyCapExceeded()");

    function testFork_fund_failWhenManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3StrategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenNotOperator() external {
        vm.prank(makeAddr("notOperator"));
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenBotFundsImpairedStrategy() external {
        deposit(lp, assets);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets / 2);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(assets / 4);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets / 4, "");
    }

    function testFork_fund_failWhenNotActive() external {
        address inactiveDelegate = makeAddr("inactiveDelegate");

        vm.prank(governor);
        globals.setValidStrategyDelegate(inactiveDelegate, true);

        AaveV3StrategyInitializerParams memory params = AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0,
            strategyProtocolFeeRate:     0,
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance,
            strategyMetadata:           ""
        });

        vm.prank(inactiveDelegate);
        ( address inactiveStrategyManager, ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, abi.encode(params), "");

        vm.prank(inactiveDelegate);
        vm.expectRevert("MSM:FSM:NOT_ACTIVE");
        IStrategyManager(inactiveStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), 0, "");
    }

    function testFork_fund_failWithInvalidPoolManagerFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithNonInstancePoolManager() external {
        address nonInstancePoolManager = address(new FakePoolManager());

        FakePoolManager(nonInstancePoolManager).__setFactory(poolManagerFactory);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(nonInstancePoolManager, assets, "");
    }

    function testFork_fund_failWithInvalidUnderlyingStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", aaveV3StrategyFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_US");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithNonInstanceUnderlyingStrategy() external {
        vm.mockCall(
            aaveV3StrategyFactory,
            abi.encodeWithSignature("isInstance(address)", aaveV3UnderlyingStrategy),
            abi.encode(false)
        );

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_US");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenRequestFundsPaused() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:PAUSED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenTotalSupplyZero() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenStrategyManagerFactoryInvalid() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolStrategyCap() external {
        deposit(lp, assets);

        vm.prank(governor);
        poolManager.setStrategyCap(aaveV3StrategyManager, assets - 1);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithInsufficientLiquidity() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets + 1, "");
    }

    function testFork_fund_failWhenStrategyPaused() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenNotStrategyManager() external {
        vm.prank(makeAddr("notStrategyManager"));
        vm.expectRevert("MAV3S:NOT_STRATEGY_MANAGER");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).fundUnderlyingStrategy(assets, "");
    }

    function testFork_fund_failWhenLossRecognized() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithInvalidStrategyVault() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:FUS:INVALID_STRATEGY_VAULT");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenReservePaused() external {
        deposit(lp, assets);
        setAaveV3ReservePause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert(expectedReservePausedError);
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenReserveFrozen() external {
        deposit(lp, assets);
        setAaveV3ReserveFreeze(true);

        vm.prank(strategyDelegate);
        vm.expectRevert(expectedReserveFrozenError);
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenSupplyCapExceeded() external {
        deposit(lp, assets);
        setAaveV3SupplyCap(1);

        vm.prank(strategyDelegate);
        vm.expectRevert(expectedSupplyCapExceededError);
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithZeroShares() external {
        deposit(lp, assets);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets / 4);

        address aavePool = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        fundsAsset.mint(address(this), assets);
        fundsAsset.approve(aavePool, assets);
        IAavePoolLike(aavePool).supply(address(fundsAsset), assets, address(this), 0);

        IERC20(aaveToken).transfer(aaveV3UnderlyingStrategy, IERC20(aaveToken).balanceOf(address(this)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), 2, "");
    }

    function testFork_fund_failWithBlockedPoolManager() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolManagerCap() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setPoolManagerCap(address(poolManager), assets / 2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolManagerCapAtBoundary() external {
        uint256 fundAmount = assets / 4;

        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setPoolManagerCap(address(poolManager), fundAmount - expectedRoundingError);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");
    }

    function testFork_fund_failWhenExceedingStrategyLiquidityCap() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setStrategyLiquidityCap(assets / 2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingStrategyLiquidityCapAtBoundary() external {
        uint256 fundAmount = assets / 4;

        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setStrategyLiquidityCap(fundAmount - expectedRoundingError);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");
    }

}

contract SparkLendStrategyFundFailureTests is AaveV3StrategyFundFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        expectedRoundingError       = 0;
        useVirtualUnderlyingBalance = false;

        expectedReserveFrozenError     = bytes("28");
        expectedReservePausedError     = bytes("29");
        expectedSupplyCapExceededError = bytes("51");

        super.setUp();
    }

}

contract AaveV3StrategyFundTests is AaveV3StrategyTestBase {

    uint256 expectedRoundingError = 1;  // Aave's initial supply is reported 1 asset unit below nominal at this fork block.
    uint256 poolLiquidity         = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_fund_partial_asStrategyDelegate() external {
        uint256 fundAmount                 = 250_000e6;
        uint256 expectedAum                = fundAmount - expectedRoundingError;
        uint256 expectedShares             = expectedAum;
        uint256 expectedAvailableLiquidity = poolLiquidity - fundAmount;

        // 750_000e6 available liquidity + 250_000e6 nominal strategy AUM - the protocol-specific rounding adjustment.
        uint256 expectedTotalAssets = 1_000_000e6 - expectedRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAum,
            aTokenBalance:           expectedAum,
            lastRecordedTotalAssets: expectedAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_partial_asLiquidityBot() external {
        uint256 fundAmount                 = 250_000e6;
        uint256 expectedAum                = fundAmount - expectedRoundingError;
        uint256 expectedShares             = expectedAum;
        uint256 expectedAvailableLiquidity = poolLiquidity - fundAmount;

        // 750_000e6 available liquidity + 250_000e6 nominal strategy AUM - the protocol-specific rounding adjustment.
        uint256 expectedTotalAssets = 1_000_000e6 - expectedRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        vm.prank(liquidityBot);
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAum,
            aTokenBalance:           expectedAum,
            lastRecordedTotalAssets: expectedAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_full() external {
        uint256 expectedAum    = poolLiquidity - expectedRoundingError;
        uint256 expectedShares = expectedAum;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, poolLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAum,
            aTokenBalance:           expectedAum,
            lastRecordedTotalAssets: expectedAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_multipleFundsAcrossPoolManagers() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy and configure two pools that share the same strategy manager                                                ***/
        /**********************************************************************************************************************************/

        uint256 firstPoolInitialFunding  = 200_000e6;
        uint256 firstPoolFollowUpFunding = 300_000e6;
        uint256 secondPoolFunding        = 400_000e6;

        ( , address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  aaveV3StrategyManager);
        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        address firstPool  = IPoolManager(firstPoolManager).pool();
        address secondPool = IPoolManager(secondPoolManager).pool();

        assertPoolState({
            pool:               firstPool,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deposit liquidity into both pools                                                                                  ***/
        /**********************************************************************************************************************************/

        deposit(firstPool,  lp, poolLiquidity);
        deposit(secondPool, lp, poolLiquidity);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund the strategy from the first pool                                                                              ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(firstPoolManager, aaveV3StrategyManager, firstPoolInitialFunding);

        uint256 expectedFirstPoolAum                = 200_000e6 - expectedRoundingError;
        uint256 expectedFirstPoolShares             = expectedFirstPoolAum;
        uint256 expectedFirstPoolAvailableLiquidity = 800_000e6;  // 1_000_000e6 initial liquidity - 200_000e6 funded.

        // 800_000e6 available liquidity + 200_000e6 nominal strategy AUM - the protocol-specific rounding adjustment.
        uint256 expectedFirstPoolTotalAssets = 1_000_000e6 - expectedRoundingError;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        expectedFirstPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAvailableLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedFirstPoolAum,
            aTokenBalance:           expectedFirstPoolAum,
            lastRecordedTotalAssets: expectedFirstPoolAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedFirstPoolShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedFirstPoolAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstPoolAum,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Fund the strategy again from the first pool                                                                        ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedFirstPoolAum);

        fundStrategyManager(firstPoolManager, aaveV3StrategyManager, firstPoolFollowUpFunding);

        expectedFirstPoolAum                = firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingError * 2;
        expectedFirstPoolShares             = expectedFirstPoolAum;
        expectedFirstPoolAvailableLiquidity = firstPoolInitialFunding + firstPoolFollowUpFunding;

        // 500_000e6 available liquidity + 500_000e6 nominal strategy AUM - the cumulative protocol-specific rounding adjustment.
        expectedFirstPoolTotalAssets = 1_000_000e6 - expectedRoundingError * 2;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        expectedFirstPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAvailableLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedFirstPoolAum,
            aTokenBalance:           expectedFirstPoolAum,
            lastRecordedTotalAssets: expectedFirstPoolAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedFirstPoolShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedFirstPoolAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstPoolAum,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Fund the strategy from the second pool                                                                             ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedFirstPoolAum);

        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        uint256 expectedSecondPoolAum                = 400_000e6 - expectedRoundingError;
        uint256 expectedSecondPoolShares             = expectedSecondPoolAum;
        uint256 expectedSecondPoolAvailableLiquidity = 600_000e6;  // 1_000_000e6 initial liquidity - 400_000e6 funded.
        uint256 expectedSecondPoolTotalAssets        = expectedSecondPoolAvailableLiquidity + expectedSecondPoolAum;
        uint256 expectedAum                          = expectedFirstPoolAum + expectedSecondPoolAum;
        uint256 expectedShares                       = expectedAum;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        expectedFirstPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAvailableLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        expectedSecondPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedSecondPoolAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAum,
            aTokenBalance:           expectedAum,
            lastRecordedTotalAssets: expectedAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstPoolAum,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAum,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_accruesFeesAndMintsFewerSharesAfterYield() external {
        uint256 fundAmount      = 250_000e6;
        uint32  delegateFeeRate = 0.1e6;   // 10% of accrued yield.
        uint32  protocolFeeRate = 0.05e6;  // 5% of accrued yield.

        /**********************************************************************************************************************************/
        /*** Step 1: Set the delegate and protocol strategy fee rates                                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(delegateFeeRate);

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(protocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy for the first time                                                                               ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 firstAum                   = fundAmount - expectedRoundingError;
        uint256 firstShares                = firstAum;
        uint256 expectedAvailableLiquidity = poolLiquidity - fundAmount;
        uint256 expectedTotalAssets        = expectedAvailableLiquidity + firstAum;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstAum,
            aTokenBalance:           firstAum,
            lastRecordedTotalAssets: firstAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), firstAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAum,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Step 3: Let the underlying position accrue yield                                                                           ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedGrossYield  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - firstAum;
        uint256 expectedDelegateFee = expectedGrossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = expectedGrossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 expectedNetYield    = expectedGrossYield - expectedDelegateFee - expectedProtocolFee;

        expectedTotalAssets = expectedAvailableLiquidity + firstAum + expectedNetYield;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).assetsUnderManagement(),   firstAum + expectedNetYield);
        assertEq(IStrategyManager(aaveV3StrategyManager).assetsUnderManagement(),     firstAum + expectedNetYield);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).lastRecordedTotalAssets(), firstAum);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).unrealizedLosses(),        0);

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           firstAum + expectedNetYield,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund again and transfer the accrued fees to the delegate and treasury                                              ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), firstAum + expectedGrossYield);

        uint256 expectedSecondFundShares = fundAmount * firstShares / (firstAum + expectedNetYield);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        // After fee collection and the second fund, Aave reports 1 asset unit less than the nominal post-fund AUM.
        // Spark reports the nominal post-fund AUM in full.
        uint256 expectedAumAfter = firstAum + expectedNetYield + fundAmount - expectedRoundingError;

        expectedAvailableLiquidity = 500_000e6;  // 1_000_000e6 initial liquidity - two 250_000e6 funds.
        expectedTotalAssets        = expectedAvailableLiquidity + expectedAumAfter;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAumAfter,
            aTokenBalance:           expectedAumAfter,
            lastRecordedTotalAssets: expectedAumAfter,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstShares + expectedSecondFundShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAumAfter);

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAumAfter,
            shares:           firstShares + expectedSecondFundShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_yieldSplitsAcrossPoolManagers() external {
        ( , address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  aaveV3StrategyManager);
        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        uint256 firstPoolFunding   = 250_000e6;
        uint256 secondPoolFunding  = 500_000e6;
        uint256 firstPoolShares    = firstPoolFunding - expectedRoundingError;
        uint256 secondPoolShares   = secondPoolFunding - expectedRoundingError;
        uint256 expectedInitialAum = firstPoolShares + secondPoolShares;

        deposit(IPoolManager(firstPoolManager).pool(),  lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(firstPoolManager, aaveV3StrategyManager, firstPoolFunding);

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), firstPoolShares);

        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstPoolShares,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + secondPoolShares,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedInitialAum,
            aTokenBalance:           expectedInitialAum,
            lastRecordedTotalAssets: expectedInitialAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstPoolShares + secondPoolShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedInitialAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolShares,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolShares,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.warp(block.timestamp + 365 days);

        uint256 totalShares                   = firstPoolShares + secondPoolShares;
        uint256 positionValue                 = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 expectedFirstPoolAssets       = firstPoolShares  * positionValue / totalShares;
        uint256 expectedSecondPoolAssets      = secondPoolShares * positionValue / totalShares;
        uint256 expectedFirstPoolTotalAssets  = (poolLiquidity - firstPoolFunding)  + expectedFirstPoolAssets;
        uint256 expectedSecondPoolTotalAssets = (poolLiquidity - secondPoolFunding) + expectedSecondPoolAssets;

        assertGt(expectedFirstPoolAssets,  firstPoolShares);
        assertGt(expectedSecondPoolAssets, secondPoolShares);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: expectedInitialAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: 0
        });

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        expectedFirstPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        expectedSecondPoolTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstPoolAssets,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAssets,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_forwardsReferralCode() external {
        uint16  referralCode = 42;
        uint256 fundAmount   = 250_000e6;
        address aavePool     = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        uint256 expectedAum                = fundAmount - expectedRoundingError;
        uint256 expectedShares             = expectedAum;
        uint256 expectedAvailableLiquidity = poolLiquidity - fundAmount;

        // 750_000e6 available liquidity + 250_000e6 nominal strategy AUM - the protocol-specific rounding adjustment.
        uint256 expectedTotalAssets = 1_000_000e6 - expectedRoundingError;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setReferralCode(referralCode);

        vm.expectCall(
            aavePool,
            abi.encodeWithSignature(
                "supply(address,uint256,address,uint16)",
                address(fundsAsset),
                fundAmount,
                aaveV3UnderlyingStrategy,
                referralCode
            )
        );

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAum,
            aTokenBalance:           expectedAum,
            lastRecordedTotalAssets: expectedAum,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_fundingUnaffectedByImpairment() external {
        uint256 firstFund  = 250_000e6;
        uint256 secondFund = 300_000e6;
        uint256 impairment = 100_000e6;

        uint256 expectedAumAfterFirstFund         = 250_000e6 - expectedRoundingError;
        uint256 expectedSharesAfterFirstFund      = expectedAumAfterFirstFund;
        uint256 expectedAvailableAfterFirstFund   = poolLiquidity - firstFund;

        // 750_000e6 available liquidity + 250_000e6 nominal strategy AUM - the protocol-specific rounding adjustment.
        uint256 expectedTotalAssetsAfterFirstFund = 1_000_000e6 - expectedRoundingError;

        /**********************************************************************************************************************************/
        /*** Step 1: Fund the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, firstFund);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssetsAfterFirstFund,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableAfterFirstFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAumAfterFirstFund,
            aTokenBalance:           expectedAumAfterFirstFund,
            lastRecordedTotalAssets: expectedAumAfterFirstFund,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedSharesAfterFirstFund,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAumAfterFirstFund);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAumAfterFirstFund,
            shares:           expectedSharesAfterFirstFund,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Impair part of the position — the AUM is unchanged, but the loss is now reported as unrealized                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssetsAfterFirstFund,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: expectedAvailableAfterFirstFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAumAfterFirstFund,  // Impairment does not reduce the reported AUM.
            aTokenBalance:           expectedAumAfterFirstFund,
            lastRecordedTotalAssets: expectedAumAfterFirstFund,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedSharesAfterFirstFund,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAumAfterFirstFund,
            shares:           expectedSharesAfterFirstFund,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund again — the outstanding impairment does not block funding, and it stays reported as unrealized loss           ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAumAfterFirstFund);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, secondFund);

        // At this fork block, Aave reports 1 asset unit less after the first fund and 2 additional units less after the second.
        // Spark reports the full nominal AUM.
        uint256 expectedCumulativeRoundingError  = expectedRoundingError * 3;
        uint256 expectedAumAfterSecondFund       = 550_000e6 - expectedCumulativeRoundingError;
        uint256 expectedAvailableAfterSecondFund = 450_000e6;  // 1_000_000e6 initial liquidity - 250_000e6 - 300_000e6.

        // Before protocol-specific rounding, the second fund brings both nominal AUM and total shares to 550_000e6.
        uint256 expectedTotalAssetsAfterSecondFund = 1_000_000e6 - expectedCumulativeRoundingError;
        uint256 expectedTotalSharesAfterSecondFund = expectedAumAfterSecondFund;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedTotalAssetsAfterSecondFund,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: expectedAvailableAfterSecondFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedAumAfterSecondFund,
            aTokenBalance:           expectedAumAfterSecondFund,
            lastRecordedTotalAssets: expectedAumAfterSecondFund,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedTotalSharesAfterSecondFund,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedAumAfterSecondFund);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAumAfterSecondFund,
            shares:           expectedTotalSharesAfterSecondFund,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_fund_fundingFromSecondPoolManagerUnaffectedByImpairment() external {
        uint256 fundAmount                 = 250_000e6;
        uint256 firstPoolPosition          = fundAmount - expectedRoundingError;
        uint256 firstPoolShares            = firstPoolPosition;
        uint256 impairment                 = 100_000e6;
        uint256 expectedAvailableLiquidity = 750_000e6;  // 1_000_000e6 pool liquidity - 250_000e6 funded.

        ( , address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  aaveV3StrategyManager);
        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(IPoolManager(firstPoolManager).pool(),  lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 1: Fund the strategy from the first pool manager                                                                      ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

        fundStrategyManager(firstPoolManager, aaveV3StrategyManager, fundAmount);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        expectedAvailableLiquidity + firstPoolPosition,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstPoolPosition,
            aTokenBalance:           firstPoolPosition,
            lastRecordedTotalAssets: firstPoolPosition,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstPoolShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), firstPoolPosition);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolPosition,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Impair the strategy                                                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        expectedAvailableLiquidity + firstPoolPosition,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstPoolPosition,
            aTokenBalance:           firstPoolPosition,
            lastRecordedTotalAssets: firstPoolPosition,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstPoolShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolPosition,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund the impaired strategy from the second pool manager                                                            ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), firstPoolPosition);

        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, fundAmount);

        uint256 secondPoolPosition = fundAmount - 1;  // Both protocols report the follow-up fund 1 asset unit below nominal.
        uint256 secondPoolShares   = secondPoolPosition;

        // Total nominal funding less the initial Aave-only adjustment and the shared one-unit follow-up adjustment.
        uint256 expectedTotalAum    = 500_000e6 - expectedRoundingError - 1;
        uint256 expectedTotalShares = expectedTotalAum;

        // Aave assigns 50_000e6 of impairment to the first pool; Spark's pro rata rounding assigns 1 additional asset unit.
        uint256 expectedFirstPoolLoss  = 50_000e6 + 1 - expectedRoundingError;
        uint256 expectedSecondPoolLoss = 50_000e6;  // Rounded-up pro rata share of the 100_000e6 impairment.

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        expectedAvailableLiquidity + firstPoolPosition,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedFirstPoolLoss,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        expectedAvailableLiquidity + secondPoolPosition,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedSecondPoolLoss,
            availableLiquidity: expectedAvailableLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedTotalAum,
            aTokenBalance:           expectedTotalAum,
            lastRecordedTotalAssets: expectedTotalAum,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedTotalShares,
            totalPendingShares: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),        0);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), expectedTotalAum);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolPosition,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: expectedFirstPoolLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolPosition,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: expectedSecondPoolLoss
        });
    }

}

contract SparkLendStrategyFundTests is AaveV3StrategyFundTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        expectedRoundingError       = 0;  // Spark reports the full nominal amount after the initial supply at this fork block.
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}
