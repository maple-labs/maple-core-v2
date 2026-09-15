// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { FakePoolManager } from "../../mocks/Mocks.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyProcessRedemptionFailureTests is AaveV3StrategyTestBase {

    uint256 assets                = 1_000_000e6;
    uint256 expectedRoundingError = 1;  // Aave reports 1 asset unit below the nominal supply at this fork block.

    function testFork_processRedemption_failWhenManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3StrategyManager, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenNotOperator() external {
        vm.prank(makeAddr("notOperator"));
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLiquidityBotProcessesImpairedStrategy() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);
        impairStrategy(aaveV3UnderlyingStrategy, 1);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLiquidityRouterProcessesImpairedStrategy() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);
        impairStrategy(aaveV3UnderlyingStrategy, 1);

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWithInvalidPoolManagerFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWithNonInstancePoolManager() external {
        address nonInstancePoolManager = address(new FakePoolManager());

        FakePoolManager(nonInstancePoolManager).__setFactory(poolManagerFactory);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:INVALID_PM");
        IStrategyManager(aaveV3StrategyManager).processRedemption(nonInstancePoolManager, 1, "");
    }

    function testFork_processRedemption_failWithZeroShares() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_SHARES");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 0, "");
    }

    function testFork_processRedemption_failWhenExceedingRequestedShares() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);

        uint256 shares          = assets - expectedRoundingError;
        uint256 requestedShares = shares / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, requestedShares);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:EXCEEDS_REQUESTED");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), requestedShares + 1, "");
    }

    function testFork_processRedemption_failWhenExitAssetsAreZero() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);

        uint256 fundedAssets = assets - expectedRoundingError;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(fundedAssets - 1);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenLossIsRecognized() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenReservePaused() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);
        setAaveV3ReservePause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

    function testFork_processRedemption_failWhenAaveLiquidityIsBorrowed() external {
        uint256 shares = 2;

        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        // Make sure 2 shares will convert to 2 units of asset.
        assertEq(IStrategyManager(aaveV3StrategyManager).convertToAssets(shares), 2);

        // Borrow all but one asset unit of the available protocol liquidity.
        borrowOnAave();

        // The redemption requires two asset units, but only one remains available to withdraw.
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).availableToWithdraw(), 1);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), shares, "");
    }

    function testFork_processRedemption_useVirtualUnderlyingBalance_donation() external {
        address donor = makeAddr("donor");

        uint256 shares = 2;

        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertEq(IStrategyManager(aaveV3StrategyManager).convertToAssets(shares), 2);

        borrowOnAave();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).availableToWithdraw(), 1);

        deal(address(fundsAsset), donor, 1);

        vm.prank(donor);
        fundsAsset.transfer(aaveToken, 1);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).availableToWithdraw(), useVirtualUnderlyingBalance ? 1 : 2);

        vm.prank(strategyDelegate);

        if (useVirtualUnderlyingBalance) {
            vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
            IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), shares, "");
        } else {
            IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), shares, "");
        }
    }

    function testFork_processRedemption_failWhenStrategyPaused() external {
        deposit(lp, assets);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, assets);
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, 1);

        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), 1, "");
    }

}

contract SparkLendStrategyProcessRedemptionFailureTests is AaveV3StrategyProcessRedemptionFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        expectedRoundingError       = 0;  // Spark reports the full nominal supply at this fork block.
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract AaveV3StrategyProcessRedemptionTests is AaveV3StrategyTestBase {

    uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
    uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

    uint256 expectedRoundingError           = 1;  // Base unit used for Aave supply-rounding adjustments at this fork block.
    uint256 expectedWithdrawalRoundingError = 0;  // Aave requires no post-withdrawal AUM adjustment at this fork block.
    uint256 firstPoolFunding                = 300_000e6;
    uint256 impairmentAmount                = 100_000e6;
    uint256 poolLiquidity                   = 1_000_000e6;
    uint256 secondPoolFunding               = 400_000e6;

    uint256 expectedFirstAssets;
    uint256 expectedFirstUnrealizedLosses;
    uint256 expectedSecondAssets;
    uint256 expectedSecondUnrealizedLosses;
    uint256 expectedTotalShares;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_processRedemption_partial_asStrategyDelegate() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingError;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 2;
        uint256 expectedAssets = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundAmount / 2 + expectedWithdrawalRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_partial_asLiquidityBot() external {
        uint256 fundAmount = 500_000e6;

        vm.prank(governor);
        globals.setValidInstanceOf("LIQUIDITY_BOT", liquidityBot, true);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingError;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 2;
        uint256 expectedAssets = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        vm.prank(liquidityBot);
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), shares, "");

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundAmount / 2 + expectedWithdrawalRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_partial_asLiquidityRouter() external {
        uint256 fundAmount = 500_000e6;

        vm.prank(governor);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", liquidityRouterBot, true);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets   = fundAmount - expectedRoundingError;
        uint256 totalShares    = fundedAssets;
        uint256 shares         = totalShares / 2;
        uint256 expectedAssets = fundedAssets / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        vm.prank(liquidityRouterBot);
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), shares, "");

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundAmount / 2 + expectedWithdrawalRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_full_maxWithdrawal() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 shares       = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 expectedAssets      = fundedAssets;
        uint256 poolBalanceBefore   = fundsAsset.balanceOf(address(pool));
        uint256 aTokenBalanceBefore = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        shares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 poolBalanceAfter   = fundsAsset.balanceOf(address(pool));
        uint256 aTokenBalanceAfter = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertEq(poolBalanceAfter - poolBalanceBefore,     expectedAssets);
        assertEq(aTokenBalanceBefore - aTokenBalanceAfter, expectedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolBalanceAfter,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolBalanceAfter
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
    }

    function testFork_processRedemption_multipleSequentialRedemptions() external {
        uint256 fundAmount = 600_000e6;

        /**********************************************************************************************************************************/
        /*** Fund the strategy and request a redemption of all shares                                                                   ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        // Aave reports 2 asset units below this nominal supply, while Spark reports the full amount.
        uint256 fundedAssets = fundAmount - 2 * expectedRoundingError;
        uint256 totalShares  = fundedAssets;
        uint256 firstAssets  = fundedAssets / 3;
        uint256 firstShares  = totalShares / 3;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, totalShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: totalShares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    totalShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the first third of the requested shares                                                                            ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, firstShares);

        uint256 remainingAssets = fundedAssets - firstAssets;
        uint256 remainingShares = totalShares - firstShares;
        uint256 secondAssets    = firstAssets;
        uint256 secondShares    = firstShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + firstAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: remainingShares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    remainingShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the second third of the requested shares                                                                           ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, secondShares);

        remainingAssets -= secondAssets;
        remainingShares -= secondShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + fundedAssets - remainingAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: remainingShares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    remainingShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process all remaining requested shares                                                                                     ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, remainingShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + fundedAssets
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
    }

    function testFork_processRedemption_accruesFeesAndUsesPostYieldSharePrice() external {
        uint256 fundAmount = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Set fee rates, fund the strategy and request a partial redemption                                                          ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm fees reduce the strategy's net AUM                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        // The aToken balance is gross, while strategy AUM is reduced by accrued fees before they are collected.
        uint256 grossAum            = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 expectedDelegateFee = (grossAum - fundedAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - fundedAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;
        uint256 expectedAssets      = shares * netAum / totalShares;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process the redemption and collect the accrued fees                                                                        ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum - expectedWithdrawalRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        uint256 remainingAssets = netAum - expectedAssets - expectedWithdrawalRoundingError;
        uint256 remainingShares = totalShares - shares;

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedProtocolFee);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_full_collectsFeesAndWithdrawsAllAssets() external {
        uint256 fundAmount = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Set fee rates, fund the strategy and request redemption of all shares                                                      ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 shares       = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm fees reduce the strategy's net AUM                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum            = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 expectedDelegateFee = (grossAum - fundedAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - fundedAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        shares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Process the full redemption, collect fees and exhaust the Aave position                                                    ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + netAum
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate),                expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                        expectedProtocolFee);
        assertEq(IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy), 0);

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
    }

    function testFork_processRedemption_impairedStrategyUsesNetExitAssets() external {
        uint256 fundAmount = 500_000e6;
        uint256 impairment = 100_000e6;

        /**********************************************************************************************************************************/
        /*** Fund the strategy, request redemption of half the shares and then impair the strategy                                      ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        // The redemption receives half of the net exit assets, adjusted for the initial supply rounding.
        uint256 expectedAssets = (fundAmount - impairment) / 2 - expectedRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Process redemptions for half the shares and crystallize losses from the impairment                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

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

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
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
        expectedAssets = fundAmount - impairment - expectedRoundingError;

        // Redeem the remaining shares to show impaired amount remains in the strategy and is not distributed to the pool.
        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, remainingShares);
        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, remainingShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     impairment - expectedRoundingError + expectedWithdrawalRoundingError,
            aTokenBalance:           impairment - expectedRoundingError + expectedWithdrawalRoundingError,
            lastRecordedTotalAssets: impairment - expectedRoundingError + expectedWithdrawalRoundingError,
            unrealizedLosses:        impairment - expectedRoundingError  // Can be rounded down due to clamping but not increased
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
    }

    function testFork_processRedemption_impairedBeforeFundingUsesNetExitAssets() external {
        uint256 fundAmount = 500_000e6;
        uint256 impairment = 100_000e6;

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 expectedAssets = (fundAmount - impairment) / 2 - expectedRoundingError;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: impairment
        });

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 remainingAssets = fundAmount / 2 + impairment / 2;
        uint256 remainingShares = totalShares - shares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
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
        IStrategyManager(aaveV3StrategyManager).setPoolManagerCap(address(poolManager), fundAmount);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 totalShares  = fundedAssets;
        uint256 shares       = totalShares / 2;

        vm.prank(strategyDelegate);
        IStrategyManager(aaveV3StrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 expectedAssets = fundedAssets / 2;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           totalShares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        uint256 remainingShares = totalShares - shares;
        uint256 remainingAssets = fundAmount / 2 + expectedWithdrawalRoundingError;

        assertEq(IStrategyManager(aaveV3StrategyManager).poolManagerCapOf(address(poolManager)), type(uint256).max);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_processRedemption_successWhenReserveFrozen() external {
        uint256 fundAmount = 500_000e6;

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 shares       = fundedAssets;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        setAaveV3ReserveFreeze(true);

        uint256 expectedAssets = fundedAssets;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + fundedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundedAssets,
            aTokenBalance:           fundedAssets,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        shares,
            totalPendingShares: shares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           shares,
            pendingShares:    shares,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + expectedAssets
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
    }

    function testFork_processRedemption_multiplePoolManagersWithImpairment() external {
        /**********************************************************************************************************************************/
        /*** Fund two pool-manager positions, impair the shared strategy and request partial redemptions                                ***/
        /**********************************************************************************************************************************/

        ( , address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  aaveV3StrategyManager);
        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(IPoolManager(firstPoolManager).pool(),  lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        fundStrategyManager(firstPoolManager,  aaveV3StrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        uint256 firstShares  = firstPoolFunding - 2 * expectedRoundingError;
        uint256 secondShares = secondPoolFunding;
        uint256 totalAum     = firstShares + secondShares;

        expectedTotalShares = totalAum;

        requestRedeemFromStrategyManager(firstPoolManager,  aaveV3StrategyManager, firstShares / 2);
        requestRedeemFromStrategyManager(secondPoolManager, aaveV3StrategyManager, secondShares / 2);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairmentAmount);

        expectedFirstAssets           = firstShares;
        expectedFirstUnrealizedLosses = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);

        expectedSecondAssets           = secondShares;
        expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

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

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalAum,
            aTokenBalance:           totalAum,
            lastRecordedTotalAssets: totalAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedTotalShares,
            totalPendingShares: firstShares / 2 + secondShares / 2
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    firstShares / 2,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
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
        uint256 exitAssets      = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(sharesToProcess);

        processRedemptionFromStrategyManager(firstPoolManager, aaveV3StrategyManager, sharesToProcess);

        firstShares         -= sharesToProcess;
        expectedTotalShares -= sharesToProcess;
        totalAum             = totalAum - exitAssets + expectedWithdrawalRoundingError;

        uint256 firstExitAssets = exitAssets;

        expectedFirstAssets           = firstShares  * totalAum / expectedTotalShares;
        expectedFirstUnrealizedLosses = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);

        expectedSecondAssets           = secondShares * totalAum / expectedTotalShares;
        expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

        assertEq(fundsAsset.balanceOf(IPoolManager(firstPoolManager).pool()), poolLiquidity - firstPoolFunding + exitAssets);

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

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalAum,
            aTokenBalance:           totalAum,
            lastRecordedTotalAssets: totalAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedTotalShares,
            totalPendingShares: secondShares / 2
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
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
        exitAssets      = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(sharesToProcess);

        processRedemptionFromStrategyManager(secondPoolManager, aaveV3StrategyManager, sharesToProcess);

        secondShares        -= sharesToProcess;
        expectedTotalShares -= sharesToProcess;
        totalAum             = totalAum - exitAssets - expectedRoundingError;

        expectedFirstAssets           = firstShares  * totalAum / expectedTotalShares;
        expectedFirstUnrealizedLosses = divRoundUp(firstShares * impairmentAmount, expectedTotalShares);

        expectedSecondAssets           = secondShares * totalAum / expectedTotalShares;
        expectedSecondUnrealizedLosses = divRoundUp(secondShares * impairmentAmount, expectedTotalShares);

        assertEq(fundsAsset.balanceOf(IPoolManager(secondPoolManager).pool()), poolLiquidity - secondPoolFunding + exitAssets);

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

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalAum,
            aTokenBalance:           totalAum,
            lastRecordedTotalAssets: totalAum,
            unrealizedLosses:        impairmentAmount
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        expectedTotalShares,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           expectedFirstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: expectedFirstUnrealizedLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
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

        ( , address firstPoolManager  ) = _createPoolSharingStrategy("firstPoolDelegate",  aaveV3StrategyManager);
        ( , address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(IPoolManager(firstPoolManager).pool(),  lp, poolLiquidity);
        deposit(IPoolManager(secondPoolManager).pool(), lp, poolLiquidity);

        /**********************************************************************************************************************************/
        /*** Fund the strategy from both pools and request redemption of all shares                                                     ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(firstPoolManager,  aaveV3StrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        // Aave's first supply mints 2 fewer shares and its second supply mints the full amount. Spark mints both in full.
        uint256 firstShares  = firstPoolFunding - 2 * expectedRoundingError;
        uint256 secondShares = secondPoolFunding;

        requestRedeemFromStrategyManager(firstPoolManager,  aaveV3StrategyManager, firstShares);
        requestRedeemFromStrategyManager(secondPoolManager, aaveV3StrategyManager, secondShares);

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm it is split between the pool managers in proportion to their shares                               ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        uint256 firstAssets  = firstShares  * grossAum / (firstShares + secondShares);
        uint256 secondAssets = secondShares * grossAum / (firstShares + secondShares);

        assertGt(firstAssets,  firstShares);
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

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     grossAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: firstPoolFunding + secondPoolFunding - 2 * expectedRoundingError,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        firstShares + secondShares,
            totalPendingShares: firstShares + secondShares
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    firstShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the first pool manager's redemption                                                                                ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, aaveV3StrategyManager, firstShares);

        assertPoolState({
            pool:               IPoolManager(firstPoolManager).pool(),
            totalAssets:        poolLiquidity - firstPoolFunding + firstAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding + firstAssets
        });

        uint256 remainingAssets = secondAssets + expectedWithdrawalRoundingError;

        assertPoolState({
            pool:               IPoolManager(secondPoolManager).pool(),
            totalAssets:        poolLiquidity - secondPoolFunding + remainingAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        secondShares,
            totalPendingShares: secondShares
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
            assets:           remainingAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the second pool manager's redemption                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(secondPoolManager, aaveV3StrategyManager, secondShares);

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

    }

}

contract SparkLendStrategyProcessRedemptionTests is AaveV3StrategyProcessRedemptionTests {

    function setUp() public override {
        aaveToken                       = SPARK_USDC;
        expectedRoundingError           = 0;  // Spark reports the full nominal supply at this fork block.
        expectedWithdrawalRoundingError = 1;  // Spark requires a 1-unit post-withdrawal AUM adjustment at this fork block.
        useVirtualUnderlyingBalance     = false;

        super.setUp();
    }

}
