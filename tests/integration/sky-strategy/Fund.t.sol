// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IPoolManager,
    IPSMLike,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyInitializerParams } from "../../../contracts/interfaces/Interfaces.sol";

import { MockPoolManager } from "../../mocks/Mocks.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyFundFailureTests is SkyStrategyTestBase {

    uint256 assets = 1_000e6;

    function testFork_fund_failWhenManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyStrategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenNotOperator() external {
        vm.prank(makeAddr("notOperator"));
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenBotFundsImpairedStrategy() external {
        deposit(lp, assets);

        fundStrategyManager(address(poolManager), skyStrategyManager, assets / 2);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(assets / 4);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets / 4, "");
    }

    function testFork_fund_failWhenNotActive() external {
        address inactiveDelegate = makeAddr("inactiveDelegate");

        vm.prank(governor);
        globals.setValidStrategyDelegate(inactiveDelegate, true);

        SkyStrategyInitializerParams memory params = SkyStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            referralCode:            0,
            strategyMetadata:        ""
        });

        vm.prank(inactiveDelegate);
        ( address inactiveStrategyManager, ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, abi.encode(params), "");

        vm.prank(inactiveDelegate);
        vm.expectRevert("MSM:FSM:NOT_ACTIVE");
        IStrategyManager(inactiveStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_ASSETS");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), 0, "");
    }

    function testFork_fund_failWithInvalidPoolManagerFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithNonInstancePoolManager() external {
        address nonInstancePoolManager = address(new MockPoolManager(poolManagerFactory, address(0)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:INVALID_PM");
        IStrategyManager(skyStrategyManager).fundStrategyManager(nonInstancePoolManager, assets, "");
    }

    function testFork_fund_failWhenRequestFundsPaused() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:PAUSED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenTotalSupplyZero() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenStrategyManagerFactoryInvalid() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolStrategyCap() external {
        deposit(lp, assets);

        vm.prank(governor);
        poolManager.setStrategyCap(skyStrategyManager, assets - 1);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithInsufficientLiquidity() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets + 1, "");
    }

    function testFork_fund_failWhenStrategyPaused() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenNotStrategyManager() external {
        vm.prank(makeAddr("notStrategyManager"));
        vm.expectRevert("MSS:NOT_STRATEGY_MANAGER");
        ISkyStrategy(skyUnderlyingStrategy).fundUnderlyingStrategy(assets, "");
    }

    function testFork_fund_failWhenLossRecognized() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithInvalidStrategyVault() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:FUS:INVALID_STRATEGY_VAULT");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithInvalidPsm() external {
        deposit(lp, assets);

        vm.prank(governor);
        globals.setValidInstanceOf("PSM", USDS_LITE_PSM, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:FUS:INVALID_PSM");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenPsmHalted() external {
        deposit(lp, assets);
        setSkyTout(type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:FUS:PSM_HALTED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenSellGemHalted() external {
        deposit(lp, assets);
        setSkyTin(type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("DssLitePsm/sell-gem-halted");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWithZeroShares() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), 1, "");
    }

    function testFork_fund_failWithBlockedPoolManager() external {
        deposit(lp, assets);

        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolManagerCap() external {
        deposit(lp, assets);

        // The funded position lands at assets - 1 (the 1 wei sUSDS round-trip loss), so a cap of assets - 2 is exceeded.
        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setPoolManagerCap(address(poolManager), assets - 2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingPoolManagerCapAtBoundary() external {
        deposit(lp, assets);

        uint256 fundAmount = assets / 3;

        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setPoolManagerCap(address(poolManager), fundAmount - 1);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");
    }

    function testFork_fund_failWhenExceedingStrategyLiquidityCap() external {
        deposit(lp, assets);

        // The funded position lands at assets - 1 (the 1 wei sUSDS round-trip loss), so a cap of assets - 2 is exceeded.
        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setStrategyLiquidityCap(assets - 2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), assets, "");
    }

    function testFork_fund_failWhenExceedingStrategyLiquidityCapAtBoundary() external {
        deposit(lp, assets);

        uint256 fundAmount = assets / 3;

        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setStrategyLiquidityCap(fundAmount - 1);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:STRATEGY_LIQUIDITY_CAP");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");
    }

}

contract SkyStrategyFundTests is SkyStrategyTestBase {

    uint256 poolLiquidity        = 1_000e6;
    uint256 expectedRoundingLoss = 1;  // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_fund_partial() external {
        uint256 fundAmount = poolLiquidity / 4;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_partial_asLiquidityBot() external {
        uint256 fundAmount   = poolLiquidity / 4;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(liquidityBot);
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), fundAmount, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_full() external {
        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, poolLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              poolLiquidity - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolLiquidity - expectedRoundingLoss,
            shares:           poolLiquidity - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_multipleFundsAcrossPoolManagers() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy and configure two pools that share the same strategy manager                                                ***/
        /**********************************************************************************************************************************/

        uint256 firstPoolInitialFunding  = poolLiquidity / 3;
        uint256 firstPoolFollowUpFunding = poolLiquidity / 4;
        uint256 secondPoolFunding        = poolLiquidity / 5;

        ( address firstPool,  address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  skyStrategyManager);
        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

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

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
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

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund the strategy from the first pool                                                                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(firstPoolManager, skyStrategyManager, firstPoolInitialFunding);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolInitialFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstPoolInitialFunding - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolInitialFunding - expectedRoundingLoss,
            shares:           firstPoolInitialFunding - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 4: Fund the strategy again from the first pool                                                                        ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(firstPoolManager, skyStrategyManager, firstPoolFollowUpFunding);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolInitialFunding - firstPoolFollowUpFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingLoss,
            shares:           firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 5: Fund the strategy from the second pool                                                                             ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolInitialFunding - firstPoolFollowUpFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstPoolInitialFunding + firstPoolFollowUpFunding + secondPoolFunding - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingLoss,
            shares:           firstPoolInitialFunding + firstPoolFollowUpFunding - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolFunding,
            shares:           secondPoolFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_accruesFeesAndMintsFewerSharesAfterYield() external {
        uint256 fundAmount       = poolLiquidity / 4;
        uint256 secondFundAmount = poolLiquidity / 5;
        uint32  delegateFeeRate  = 0.1e6;              // 10% of accrued yield.
        uint32  protocolFeeRate  = 0.05e6;             // 5% of accrued yield.

        /**********************************************************************************************************************************/
        /*** Step 1: Set the delegate and protocol strategy fee rates                                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyDelegateFeeRate(delegateFeeRate);

        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyProtocolFeeRate(protocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
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

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Step 3: Let the sUSDS position accrue yield                                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedGrossYield  = fundAmount         * SKY_ANNUAL_APY  / HUNDRED_PERCENT;
        uint256 expectedDelegateFee = expectedGrossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = expectedGrossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 expectedNetYield    = expectedGrossYield - expectedDelegateFee - expectedProtocolFee;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity + expectedNetYield - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss + expectedNetYield,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss + expectedNetYield,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Step 4: Fund again — the accrued fees are skimmed to the delegate and treasury                                             ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, secondFundAmount);

        uint256 expectedSkyAum = fundAmount - expectedRoundingLoss + expectedNetYield + secondFundAmount;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity + expectedNetYield - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - secondFundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedSkyAum,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        uint256 sharesMintedInFirstFund  = fundAmount - expectedRoundingLoss;
        uint256 expectedSecondFundShares = secondFundAmount * sharesMintedInFirstFund / (sharesMintedInFirstFund + expectedNetYield);

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedSkyAum,
            shares:           sharesMintedInFirstFund + expectedSecondFundShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_yieldSplitsAcrossPoolManagers() external {
        uint256 firstPoolFunding  = poolLiquidity / 4;
        uint256 secondPoolFunding = poolLiquidity / 2;

        address firstPoolManager;
        address secondPoolManager;

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy two pools that share the same strategy manager and deposit liquidity into both                              ***/
        /**********************************************************************************************************************************/

        {
            address firstPool;
            address secondPool;

            ( firstPool,  firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  skyStrategyManager);
            ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

            deposit(firstPool,  lp, poolLiquidity);
            deposit(secondPool, lp, poolLiquidity);
        }

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy from both pools before any yield accrues                                                         ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(firstPoolManager,  skyStrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        uint256 firstPoolShares  = firstPoolFunding - expectedRoundingLoss;  // First funding overall absorbs the 1 wei rounding loss.
        uint256 secondPoolShares = secondPoolFunding;

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

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstPoolShares + secondPoolShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolShares,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolShares,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Accrue yield and confirm it is split between the pool managers in proportion to their shares                       ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedPositionValue =
            (firstPoolFunding + secondPoolFunding) * (HUNDRED_PERCENT + SKY_ANNUAL_APY) / HUNDRED_PERCENT - expectedRoundingLoss;

        uint256 expectedFirstPoolYield  = firstPoolShares  * expectedPositionValue / (firstPoolShares + secondPoolShares) - firstPoolShares;
        uint256 expectedSecondPoolYield =
            secondPoolShares * expectedPositionValue / (firstPoolShares + secondPoolShares) - secondPoolShares;

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstPoolShares + expectedFirstPoolYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + secondPoolShares + expectedSecondPoolYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedPositionValue,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolShares + expectedFirstPoolYield,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolShares + expectedSecondPoolYield,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_appliesPsmExitFee() external {
        uint256 tout        = 0.01e18;                       // tout is WAD-scaled (1e18 = 100%), so 0.01e18 is a 1% PSM exit fee.
        uint256 fundAmount  = 101e6;                         // Chosen so that funding valued net of the 1% exit fee lands on a round 100e6.
        uint256 expectedAum = 100e6 - expectedRoundingLoss;  // 101e6 / (1 + tout), less the sUSDS round-trip rounding.

        /**********************************************************************************************************************************/
        /*** Step 1: Sky governance turns on the PSM exit fee                                                                           ***/
        /**********************************************************************************************************************************/

        setSkyTout(tout);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(), tout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy — the position is valued net of the exit fee it would incur to exit                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           expectedAum,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_appliesPsmExitFeeAcrossFundingsWithYield() external {
        uint256 tout             = 0.01e18;  // tout is WAD-scaled (1e18 = 100%), so 0.01e18 is a 1% PSM exit fee.
        uint256 fundAmount       = 101e6;    // Nets a round 100e6 after the 1% exit fee.
        uint256 secondFundAmount = 202e6;    // Nets a round 200e6 after the 1% exit fee.
        uint256 toutLoss         = 1e6;      // 1% exit fee on the first funding.
        uint256 secondToutLoss   = 2e6;      // 1% exit fee on the second funding.

        /**********************************************************************************************************************************/
        /*** Step 1: Sky governance turns on the PSM exit fee, then fund the strategy for the first time                                ***/
        /**********************************************************************************************************************************/

        setSkyTout(tout);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(), tout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - toutLoss - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - toutLoss - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - toutLoss - expectedRoundingLoss,
            shares:           fundAmount - toutLoss - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Accrue yield — the position appreciates, still valued net of the exit fee                                          ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedYield = (fundAmount - toutLoss) * SKY_ANNUAL_APY / HUNDRED_PERCENT;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - toutLoss - expectedRoundingLoss + expectedYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - toutLoss - expectedRoundingLoss + expectedYield,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - toutLoss - expectedRoundingLoss + expectedYield,
            shares:           fundAmount - toutLoss - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund again — the second funding is also valued net of the exit fee and mints fewer shares                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, secondFundAmount);

        uint256 expectedSkyAum = fundAmount - toutLoss - expectedRoundingLoss + expectedYield + secondFundAmount - secondToutLoss;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount - secondFundAmount + expectedSkyAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - secondFundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedSkyAum,
            unrealizedLosses: 0
        });

        uint256 sharesMintedInFirstFund  = fundAmount - toutLoss - expectedRoundingLoss;
        uint256 expectedSecondFundShares = (secondFundAmount - secondToutLoss) * sharesMintedInFirstFund / (sharesMintedInFirstFund + expectedYield);

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedSkyAum,
            shares:           sharesMintedInFirstFund + expectedSecondFundShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_withEntryFee() external {
        uint256 tin        = 0.01e18;  // tin is WAD-scaled (1e18 = 100%), so 0.01e18 is a 1% PSM entry fee.
        uint256 fundAmount = 100e6;
        uint256 tinLoss    = 1e6;      // 1% entry fee charged on the 100e6 funded.

        /**********************************************************************************************************************************/
        /*** Step 1: Sky governance turns on the PSM entry fee                                                                          ***/
        /**********************************************************************************************************************************/

        setSkyTin(tin);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy — fewer USDS are acquired, so the position is smaller than the amount funded                     ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - tinLoss - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - tinLoss - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - tinLoss - expectedRoundingLoss,
            shares:           fundAmount - tinLoss - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_withEntryAndExitFee() external {
        uint256 tin              = 0.01e18;  // 1% PSM entry fee (sellGem).
        uint256 tout             = 0.01e18;  // 1% PSM exit fee (buyGem).
        uint256 fundAmount       = 101e6;
        uint256 expectedToutLoss = 1e6;
        uint256 expectedTinLoss  = 1e6;

        /**********************************************************************************************************************************/
        /*** Step 1: Sky governance turns on both the entry and exit fees                                                               ***/
        /**********************************************************************************************************************************/

        setSkyTin(tin);
        setSkyTout(tout);

        assertEq(IPSMLike(USDS_LITE_PSM).tin(),  tin);
        assertEq(IPSMLike(USDS_LITE_PSM).tout(), tout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Fund the strategy — the entry fee shrinks the deposit and the exit fee marks the position down                     ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedTinLoss - expectedToutLoss - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedTinLoss - expectedToutLoss - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedTinLoss - expectedToutLoss - expectedRoundingLoss,
            shares:           fundAmount - expectedTinLoss - expectedToutLoss - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_fund_fundingUnaffectedByImpairment() external {
        uint256 firstFund  = poolLiquidity / 4;
        uint256 secondFund = poolLiquidity / 5;
        uint256 impairment = poolLiquidity / 10;

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

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, firstFund);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstFund - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstFund - expectedRoundingLoss,
            shares:           firstFund - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Impair part of the position — the AUM is unchanged, but the loss is now reported as unrealized                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - firstFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstFund - expectedRoundingLoss,  // Impairment does not reduce the reported AUM.
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstFund - expectedRoundingLoss,
            shares:           firstFund - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Fund again — the outstanding impairment does not block funding, and it stays reported as unrealized loss           ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, secondFund);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - firstFund - secondFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstFund - expectedRoundingLoss + secondFund,
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           firstFund - expectedRoundingLoss + secondFund,
            shares:           firstFund - expectedRoundingLoss + secondFund,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

}
