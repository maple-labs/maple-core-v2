// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20Like,
    IERC4626Like,
    IPoolManager,
    IPSMLike,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { FakePoolManager } from "../../mocks/Mocks.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyProcessRedemptionFailureTests is SkyStrategyTestBase {

    uint256 assets = 1_000_000e6;

    function testFork_processRedemption_failWhenManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyStrategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenNotOperator() external {
        vm.prank(makeAddr("notOperator"));
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLiquidityBotProcessesImpairedStrategy() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);
        impairStrategy(skyUnderlyingStrategy, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLiquidityRouterProcessesImpairedStrategy() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);
        impairStrategy(skyUnderlyingStrategy, 1);

        vm.prank(address(liquidityRouter));
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWithInvalidPoolManagerFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWithNonInstancePoolManager() external {
        address nonInstancePoolManager = address(new FakePoolManager());

        FakePoolManager(nonInstancePoolManager).__setFactory(poolManagerFactory);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(skyStrategyManager).processRedemption(nonInstancePoolManager, 1, "");
    }

    function testFork_processRedemption_failWithZeroShares() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_SHARES");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 0, "");
    }

    function testFork_processRedemption_failWhenExceedingRequestedShares() external {
        uint256 requestedShares = assets / 2;

        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, requestedShares);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:EXCEEDS_REQUESTED");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), requestedShares + 1, "");
    }

    function testFork_processRedemption_failWhenExitAssetsAreZero() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(assets);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLossIsRecognized() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenPsmBuyGemHalted() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);

        setSkyTout(type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenPsmPocketHasInsufficientLiquidity() external {
        uint256 shares = 2;

        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertEq(IStrategyManager(skyStrategyManager).convertToAssets(shares), 2);

        address pocket = IPSMLike(USDS_LITE_PSM).pocket();

        assertGe(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), shares);

        deal(address(fundsAsset), pocket, 1);

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), 1);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), shares, "");
    }

    function testFork_processRedemption_failWhenStrategyPaused() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), skyStrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, 1);

        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), 1, "");
    }

}

contract SkyStrategyProcessRedemptionTests is SkyStrategyTestBase {

    uint32 delegateFeeRate = 0.1e6; // 10% of accrued yield.
    uint32 protocolFeeRate = 0.05e6; // 5% of accrued yield.

    uint256 expectedRoundingLoss = 1; // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.
    uint256 firstPoolFunding     = 300_000e6;
    uint256 impairmentAmount     = 100_000e6;
    uint256 poolLiquidity        = 1_000_000e6;
    uint256 secondPoolFunding    = 400_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_processRedemption_partial_asStrategyDelegate() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingLoss;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 4;
        uint256 expectedAssets = fundedAssets / 4;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundedAssets - expectedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_partial_asLiquidityBot() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingLoss;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 4;
        uint256 expectedAssets = fundedAssets / 4;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        vm.prank(liquidityBot);
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), shares, "");

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundedAssets - expectedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_partial_asLiquidityRouter() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingLoss;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 4;
        uint256 expectedAssets = fundedAssets / 4;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        vm.prank(address(liquidityRouter));
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), shares, "");

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundedAssets - expectedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_full_maxWithdrawal() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingLoss;
        uint256 shares         = fundedAssets;
        uint256 expectedAssets = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           shares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

    function testFork_processRedemption_multipleSequentialRedemptions() external {
        uint256 fundAmount = 600_000e6;

        /**********************************************************************************************************************************/
        /*** Fund the strategy and request a redemption of all shares                                                                   ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 totalShares  = fundedAssets;
        uint256 firstAssets  = fundedAssets / 3;
        uint256 firstShares  = totalShares / 3;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, totalShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    totalShares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    totalShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the first third of the requested shares                                                                            ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, firstShares);

        uint256 remainingAssets = fundedAssets - firstAssets;
        uint256 remainingShares = totalShares - firstShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + firstAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    remainingShares,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    remainingShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the second third of the requested shares                                                                           ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, firstShares);

        remainingAssets -= firstAssets;
        remainingShares -= firstShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + fundedAssets - remainingAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    remainingShares,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    remainingShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process all remaining requested shares                                                                                     ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, remainingShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + fundedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

    function testFork_processRedemption_accruesFeesAndUsesPostYieldSharePrice() external {
        uint256 fundAmount = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Set fee rates, fund the strategy and request a partial redemption                                                          ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 shares       = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm fees reduce the strategy's net AUM                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum = fundAmount * (HUNDRED_PERCENT + SKY_ANNUAL_APY) / HUNDRED_PERCENT - expectedRoundingLoss;

        uint256 expectedDelegateFee = (grossAum - fundedAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - fundedAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;
        uint256 expectedAssets      = shares * netAum / fundedAssets;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    shares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process the redemption and collect the accrued fees                                                                        ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        uint256 remainingAssets = netAum - expectedAssets;
        uint256 remainingShares = fundedAssets - shares;

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_withFeesYieldAndPsmExitFee() external {
        uint256 fundAmount = 505_000e6;
        uint256 tout       = 0.01e18; // 1% PSM exit fee.

        /**********************************************************************************************************************************/
        /*** Set fees, enable the PSM exit fee and fund the strategy                                                                    ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);
        setSkyTout(tout);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        // 505,000 USDC is worth 500,000 USDC net of the 1% PSM exit fee.
        uint256 fundedAssets = 500_000e6 - expectedRoundingLoss;
        uint256 shares       = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm the strategy is valued net of fees and the PSM exit fee                                           ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedGrossYield = (fundedAssets + expectedRoundingLoss) * SKY_ANNUAL_APY / HUNDRED_PERCENT;

        uint256 expectedDelegateFee = expectedGrossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = expectedGrossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = fundedAssets + expectedGrossYield - expectedDelegateFee - expectedProtocolFee;
        uint256 expectedAssets      = shares * netAum / fundedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    shares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process a partial redemption and collect the accrued fees                                                                  ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        uint256 remainingAssets = netAum - expectedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets - shares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           fundedAssets - shares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_withFeesYieldPsmExitFeeAndImpairment() external {
        uint256 fundAmount = 505_000e6;
        uint256 tout       = 0.01e18; // 1% PSM exit fee.

        /**********************************************************************************************************************************/
        /*** Set fees, enable the PSM exit fee and fund the strategy                                                                    ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);
        setSkyTout(tout);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        // 505,000 USDC is worth 500,000 USDC net of the 1% PSM exit fee.
        uint256 fundedAssets = 500_000e6 - expectedRoundingLoss;
        uint256 shares       = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield, impair the strategy and confirm the position is valued net of fees and losses                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 expectedGrossYield = (fundedAssets + expectedRoundingLoss) * SKY_ANNUAL_APY / HUNDRED_PERCENT;

        uint256 expectedDelegateFee = expectedGrossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = expectedGrossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = fundedAssets + expectedGrossYield - expectedDelegateFee - expectedProtocolFee;
        uint256 expectedAssets      = shares * (netAum - impairmentAmount) / fundedAssets;

        impairStrategy(skyUnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    shares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    shares,
            unrealizedLosses: impairmentAmount
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process a partial redemption, collect the fees and retain the impairment on the remaining position                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        uint256 remainingAssets = netAum - expectedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets - shares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           fundedAssets - shares,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });
    }

    function testFork_processRedemption_full_collectsFeesAndWithdrawsAllAssets() external {
        uint256 fundAmount = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Set fee rates, fund the strategy and request redemption of all shares                                                      ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 shares       = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm fees reduce the strategy's net AUM                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum = fundAmount * (HUNDRED_PERCENT + SKY_ANNUAL_APY) / HUNDRED_PERCENT - expectedRoundingLoss;

        uint256 expectedGrossYield  = grossAum - fundedAssets;
        uint256 expectedDelegateFee = expectedGrossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = expectedGrossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           shares,
            totalPendingShares:    shares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process the full redemption, collect fees and exhaust the Sky position                                                     ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + netAum
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

    function testFork_processRedemption_impairedStrategyUsesNetExitAssets() external {
        uint256 fundAmount = 500_000e6;
        uint256 impairment = 100_000e6;

        /**********************************************************************************************************************************/
        /*** Fund the strategy, request redemption of half the shares and then impair the strategy                                      ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);

        // The redemption receives half of the net exit assets, adjusted for the initial supply rounding.
        uint256 expectedAssets = (fundAmount - impairment) / 2 - expectedRoundingLoss;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Process redemptions for half the shares and crystallize losses from the impairment                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 remainingShares = totalShares - shares;

        // The remaining gross assets equal the remaining net assets plus the full impairment.
        uint256 remainingAssets = fundAmount / 2 + impairment / 2;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Process redemptions for the remaining half of the shares and crystallize losses from the impairment                        ***/
        /**********************************************************************************************************************************/

        // The remaining assets are net of the impairment
        uint256 expectedRemainingExitAssets = remainingAssets - impairment;

        expectedAssets += expectedRemainingExitAssets;

        // Redeem the remaining shares to show impaired amount remains in the strategy and is not distributed to the pool.
        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, remainingShares);
        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, remainingShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              impairment,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_impairedBeforeFundingUsesNetExitAssets() external {
        uint256 fundAmount = 500_000e6;
        uint256 impairment = 100_000e6;

        impairStrategy(skyUnderlyingStrategy, impairment);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 expectedAssets = (fundAmount - impairment) / 2 - expectedRoundingLoss;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: impairment
        });

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 remainingAssets = fundAmount / 2 + impairment / 2;
        uint256 remainingShares = totalShares - shares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_processRedemption_successAfterPoolManagerCapRevoked() external {
        uint256 fundAmount = 500_000e6;

        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setPoolManagerCap(address(poolManager), fundAmount);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        vm.prank(strategyDelegate);
        IStrategyManager(skyStrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 expectedAssets = fundedAssets / 2;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundAmount / 2;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_successWhenPsmSellGemHalted() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 shares       = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        setSkyTin(type(uint256).max);

        uint256 expectedAssets = fundedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           shares,
            totalPendingShares:    shares,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   fundedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

    function testFork_processRedemption_partialWithPsmExitFee() external {
        uint256 fundAmount = 500_000e6;
        uint256 tout       = 0.01e18; // 1% PSM exit fee.

        setSkyTout(tout);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount * 1e18 / (1e18 + tout);
        uint256 totalShares    = fundedAssets;
        uint256 sharesToRedeem = totalShares / 2;
        uint256 expectedAssets = sharesToRedeem * fundedAssets / totalShares;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, sharesToRedeem);
        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, sharesToRedeem);

        uint256 remainingAssets = fundedAssets - expectedAssets;
        uint256 remainingShares = totalShares - sharesToRedeem;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_fullWithPsmExitFee() external {
        uint256 fundAmount = 500_000e6;
        uint256 tout       = 0.01e18; // 1% PSM exit fee.

        setSkyTout(tout);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount * 1e18 / (1e18 + tout);
        uint256 totalShares  = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, totalShares);
        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, totalShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + fundedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

    function testFork_processRedemption_multiplePoolManagersWithImpairment() external {
        /**********************************************************************************************************************************/
        /*** Fund two pool-manager positions, impair the shared strategy and request partial redemptions                                ***/
        /**********************************************************************************************************************************/

        (, address firstPoolManager)  = _createPoolSharingStrategy("firstPoolDelegate", skyStrategyManager);
        (, address secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(IPoolManager(firstPoolManager).pool(), lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        fundStrategyManager(firstPoolManager, skyStrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        uint256 expectedTotalShares = firstPoolFunding + secondPoolFunding - expectedRoundingLoss;
        uint256 firstShares         = firstPoolFunding - expectedRoundingLoss;
        uint256 secondShares        = secondPoolFunding;
        uint256 totalAum            = expectedTotalShares;

        uint256 expectedFirstAssets            = firstShares;
        uint256 expectedFirstUnrealizedLosses  = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);
        uint256 expectedSecondAssets           = secondShares;
        uint256 expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares / 2);
        requestRedeemFromStrategyManager(secondPoolManager, skyStrategyManager, secondShares / 2);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(impairmentAmount);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + expectedFirstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedFirstUnrealizedLosses,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + expectedSecondAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedSecondUnrealizedLosses,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAum,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           expectedTotalShares,
            totalPendingShares:    firstShares / 2 + secondShares / 2,
            assetsUnderManagement: totalAum,
            availableToWithdraw:   totalAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    firstShares / 2,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondAssets,
            shares:           secondShares,
            pendingShares:    secondShares / 2,
            unrealizedLosses: expectedSecondUnrealizedLosses
        });

        /**********************************************************************************************************************************/
        /*** Partially process the first position and assert the impairment is redistributed                                            ***/
        /**********************************************************************************************************************************/

        uint256 sharesToProcess = firstShares / 2;
        uint256 exitAssets      = sharesToProcess * (totalAum - impairmentAmount) / expectedTotalShares;

        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, sharesToProcess);

        firstShares         -= sharesToProcess;
        totalAum            -= exitAssets;
        expectedTotalShares -= sharesToProcess;

        uint256 firstExitAssets = exitAssets;

        expectedFirstAssets           = firstShares * totalAum / expectedTotalShares;
        expectedFirstUnrealizedLosses = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);

        expectedSecondAssets           = secondShares * totalAum / expectedTotalShares;
        expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + exitAssets + expectedFirstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedFirstUnrealizedLosses,
            availableLiquidity: poolLiquidity - firstPoolFunding + exitAssets
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + expectedSecondAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedSecondUnrealizedLosses,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAum,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           expectedTotalShares,
            totalPendingShares:    secondShares / 2,
            assetsUnderManagement: totalAum,
            availableToWithdraw:   totalAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondAssets,
            shares:           secondShares,
            pendingShares:    secondShares / 2,
            unrealizedLosses: expectedSecondUnrealizedLosses
        });

        /**********************************************************************************************************************************/
        /*** Partially process the second position and assert the impairment is redistributed again                                     ***/
        /**********************************************************************************************************************************/

        sharesToProcess = secondShares / 2;
        exitAssets      = sharesToProcess * (totalAum - impairmentAmount) / expectedTotalShares;

        processRedemptionFromStrategyManager(secondPoolManager, skyStrategyManager, sharesToProcess);

        secondShares        -= sharesToProcess;
        totalAum            -= exitAssets;
        expectedTotalShares -= sharesToProcess;

        expectedFirstAssets           = firstShares * totalAum / expectedTotalShares;
        expectedFirstUnrealizedLosses = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);

        expectedSecondAssets           = secondShares * totalAum / expectedTotalShares;
        expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstExitAssets + expectedFirstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedFirstUnrealizedLosses,
            availableLiquidity: poolLiquidity - firstPoolFunding + firstExitAssets
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + exitAssets + expectedSecondAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedSecondUnrealizedLosses,
            availableLiquidity: poolLiquidity - secondPoolFunding + exitAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAum,
            unrealizedLosses: impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           expectedTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAum,
            availableToWithdraw:   totalAum,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: expectedSecondUnrealizedLosses
        });
    }

    function testFork_processRedemption_multiplePoolManagersWithYield() external {
        /**********************************************************************************************************************************/
        /*** Deploy two pools that share the same strategy manager and deposit liquidity into both                                      ***/
        /**********************************************************************************************************************************/

        (, address firstPoolManager)  = _createPoolSharingStrategy("firstPoolDelegate", skyStrategyManager);
        (, address secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(IPoolManager(firstPoolManager).pool(), lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Fund the strategy from both pools and request redemption of all shares                                                     ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(firstPoolManager, skyStrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        uint256 firstShares  = firstPoolFunding - expectedRoundingLoss;
        uint256 secondShares = secondPoolFunding;

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares);
        requestRedeemFromStrategyManager(secondPoolManager, skyStrategyManager, secondShares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm it is split between the pool managers in proportion to their shares                               ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum =
            (firstPoolFunding + secondPoolFunding) * (HUNDRED_PERCENT + SKY_ANNUAL_APY) / HUNDRED_PERCENT - expectedRoundingLoss;

        uint256 firstAssets  = firstShares * grossAum / (firstShares + secondShares);
        uint256 secondAssets = secondShares * grossAum / (firstShares + secondShares);

        assertGt(firstAssets, firstShares);
        assertGt(secondAssets, secondShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + secondAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              grossAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           firstShares + secondShares,
            totalPendingShares:    firstShares + secondShares,
            assetsUnderManagement: grossAum,
            availableToWithdraw:   grossAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    firstShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the first pool manager's redemption                                                                                ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding + firstAssets
        });

        uint256 remainingAssets = grossAum - firstAssets;

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           secondShares,
            totalPendingShares:    secondShares,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
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
            assets:           remainingAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the second pool manager's redemption                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, skyStrategyManager, secondShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding + firstAssets
        });

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding + remainingAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
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

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),       0);
        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

}
