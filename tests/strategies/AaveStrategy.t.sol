// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAaveStrategy, IMockERC20 } from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Runner.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract AaveStrategyTestsBase is StrategyTestBase {

    address lp = makeAddr("lp");

    uint256 poolLiquidity   = 1_000_000e6;
    uint256 amountToFund    = 100e6;
    uint256 strategyFeeRate = 0.01e6;

    IAaveStrategy aaveStrategy;
    IMockERC20    aaveToken;

    function setUp() public override virtual {
        super.setUp();

        openPool(address(poolManager));
        deposit(lp, poolLiquidity);

        aaveStrategy = IAaveStrategy(_getStrategy(address(aaveStrategyFactory)));

        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        aaveToken = IMockERC20(address(aaveStrategy.aaveToken()));
    }

}

contract AaveStrategyFundTests is AaveStrategyTestsBase {

    function test_aaveStrategy_fund_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failWhenDeactivated() external {
        vm.prank(governor);
        aaveStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failWhenImpaired() external {
        vm.prank(governor);
        aaveStrategy.impairStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failIfInvalidAaveToken() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC), false);

        vm.prank(strategyManager);
        vm.expectRevert("MAS:FS:INVALID_AAVE_TOKEN");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failIfZeroAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        aaveStrategy.fundStrategy(0);
    }

    function test_aaveStrategy_fund_failIfInvalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", aaveStrategyFactory, false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_fund_failIfNotEnoughPoolLiquidity() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        aaveStrategy.fundStrategy(poolLiquidity + 1);
    }

    function test_aaveStrategy_fund_withPoolDelegate() external {
        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);

        assertEq(pool.totalAssets(), poolLiquidity);

        vm.prank(poolDelegate);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(pool.totalAssets(), poolLiquidity);
    }

    function test_aaveStrategy_fund_withStrategyManager() external {
        // Change for full amount of pool liquidity
        amountToFund = 1_000_000e6;

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);

        assertEq(pool.totalAssets(), poolLiquidity);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(pool.totalAssets(), poolLiquidity);
    }

    function test_aaveStrategy_fund_secondTimeWithFeesAndYield() external {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), amountToFund + yield - fee);
        assertEq(pool.totalAssets(),                   poolLiquidity + yield - fee);

        uint256 secondAmountToFund = 200e6;

        // Fund a second time
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield - fee);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield - fee);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield - fee);

        assertEq(fundsAsset.balanceOf(treasury), fee);
    }

    function test_aaveStrategy_fund_secondTimeWithNoFeesAndYield() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(0);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), amountToFund + yield);
        assertEq(pool.totalAssets(),                   poolLiquidity + yield);

        uint256 secondAmountToFund = 200e6;

        // Fund a second time
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        assertEq(fundsAsset.balanceOf(treasury), 0);
    }

    function test_aaveStrategy_fund_secondTimeWithFeesRoundedToZeroAndYield() external {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.warp(block.timestamp + 300 seconds);  // 5 minutes

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;

        assertTrue(yield > 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), amountToFund + yield);
        assertEq(pool.totalAssets(),                   poolLiquidity + yield);

        uint256 secondAmountToFund = 200e6;

        // Fund a second time
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        assertEq(fundsAsset.balanceOf(treasury), 0);  // No fees were taken by the treasury
    }

    function test_aaveStrategy_fund_secondTimeWithLoss() external {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 loss  = 20e6;

        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0), loss + yield);  // Also remove yield to round the accounting

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), amountToFund - loss);
        assertEq(pool.totalAssets(),                   poolLiquidity - loss);

        uint256 secondAmountToFund = 10e6;

        // Fund a second time
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(pool.totalAssets(),                     poolLiquidity - loss,                     1);

        assertEq(fundsAsset.balanceOf(treasury), 0);  // No fees were taken by the treasury
    }

}

contract AaveStrategyWithdrawTests is AaveStrategyTestsBase {

    uint256 amountToWithdraw = 50e6;

    function setUp() public override {
        super.setUp();

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);
    }

    function test_aaveStrategy_withdraw_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);
    }

    function test_aaveStrategy_withdraw_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);
    }

    function test_aaveStrategy_withdraw_failIfZeroAmount() external {
        // The strategy contract accepts 0 as a valid amount to withdraw, but it will revert on aave side.
        vm.prank(strategyManager);
        vm.expectRevert();
        aaveStrategy.withdrawFromStrategy(0);
    }

    function test_aaveStrategy_withdraw_failIfLowAssets() external {
        vm.prank(strategyManager);
        vm.expectRevert();
        aaveStrategy.withdrawFromStrategy(amountToFund + 1);
    }

    function test_aaveStrategy_withdraw_failWithFullLoss() external {
        vm.warp(block.timestamp + 30 days);

        uint256 loss = aaveToken.balanceOf(address(aaveStrategy));

        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0), loss);  // Also remove yield to round the accounting

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), 0);
        assertEq(pool.totalAssets(),                   poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        vm.expectRevert("MAS:WFS:LOW_ASSETS");
        aaveStrategy.withdrawFromStrategy(1);
    }

    function test_aaveStrategy_withdraw_withPoolDelegate_noFeesSameBlock() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(0);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund - amountToWithdraw,                 1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - amountToWithdraw, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    function test_aaveStrategy_withdraw_noFeesWithYield() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(0);

        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund + yield - amountToWithdraw,         1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - amountToWithdraw + yield, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - amountToWithdraw + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    function test_aaveStrategy_withdraw_withFeesAndYield() external {
        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertGt(yield, 0);
        assertGt(fee, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fee);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield - fee);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund + yield - fee - amountToWithdraw,   1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              fee);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw - fee, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw - fee, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fee, 1);
    }

    function test_aaveStrategy_withdraw_withFeesRoundedToZeroAndYield() external {
        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 300);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertGt(yield, 0);

        assertEq(fee, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund + yield - amountToWithdraw,         1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    function test_aaveStrategy_withdraw_withLoss() external {
        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 loss  = 20e6;

        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0), loss + yield);  // Also remove yield to round the accounting

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(), amountToFund - loss);
        assertEq(pool.totalAssets(),                   poolLiquidity - loss);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund - amountToWithdraw - loss,          1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - amountToWithdraw - loss, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - amountToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);
    }

    function test_aaveStrategy_withdraw_whileImpaired() external {
        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        // Both Yield and Fees should be greater than 0
        assertGt(yield, 0);
        assertGt(fee,   0);

        vm.prank(governor);
        aaveStrategy.impairStrategy();

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fee);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fee);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield - fee);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund + yield - amountToWithdraw,         1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);  // No fees taken when impaired

        // While impaired, the lastRecordedTotalAssets should not be updated
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw, 1);
        assertApproxEqAbs(aaveStrategy.unrealizedLosses(),        amountToFund + yield - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Strategy remains Impaired
    }

    function test_aaveStrategy_withdraw_whileDeactivated() external {
        uint256 initialAmount = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - initialAmount;
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        // Both Yield and Fees should be greater than 0
        assertGt(yield, 0);
        assertGt(fee,   0);

        vm.prank(governor);
        aaveStrategy.deactivateStrategy();

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(pool.totalAssets(),                     poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        aaveStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)), amountToFund + yield - amountToWithdraw,         1);
        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),        poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);  // No fees taken when deactivated

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);

        // In this scenario, the pool books a loss for the full amount, but adds what was withdrawn
        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Strategy remains Deactivated
    }

}

contract AaveSetStrategyFeeTests is AaveStrategyTestsBase {

    function setUp() public override virtual {
        StrategyTestBase.setUp();

        openPool(address(poolManager));
        deposit(lp, poolLiquidity);

        aaveStrategy = IAaveStrategy(_getStrategy(address(aaveStrategyFactory)));

        aaveToken = IMockERC20(address(aaveStrategy.aaveToken()));
    }

    function test_aaveStrategy_setStrategyFeeRate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_aaveStrategy_setStrategyFeeRate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_aaveStrategy_setStrategyFeeRate_failIfBiggerThanHundredPercent() external {
        vm.prank(governor);
        vm.expectRevert("MAS:SSFR:INVALID_FEE_RATE");
        aaveStrategy.setStrategyFeeRate(1e6 + 1);
    }

    function test_aaveStrategy_setStrategyFeeRate_failIfDeactivated() external {
        vm.prank(governor);
        aaveStrategy.deactivateStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_aaveStrategy_setStrategyFeeRate_failIfImpaired() external {
        vm.prank(governor);
        aaveStrategy.impairStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_aaveStrategy_setStrategyFeeRate_withGovernor_unfundedStrategy() external {
        assertEq(aaveStrategy.strategyFeeRate(),         0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(pool.totalAssets(),                     poolLiquidity);

        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(aaveStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(pool.totalAssets(),                     poolLiquidity);
    }

    function test_aaveStrategy_setStrategyFeeRate_withGovernor_fromNonZeroToZeroFeeRate() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(poolDelegate);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity);

        vm.warp(block.timestamp + 30 days);

        uint256 initialYield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 initialFee   = (initialYield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(initialYield, 0);
        assertGt(initialFee,   0);

        assertEq(aaveStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity + initialYield - initialFee);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(0);

        assertEq(aaveStrategy.strategyFeeRate(),         0);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee);
        assertEq(pool.totalAssets(),                     poolLiquidity + initialYield - initialFee);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);

        uint256 intermediaryBalance = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = aaveToken.balanceOf(address(aaveStrategy)) - intermediaryBalance;
        uint256 fee             = (additionalYield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(additionalYield, 0);
        assertEq(fee,             0);  // No fees taken when fee rate is 0

        assertEq(aaveStrategy.strategyFeeRate(),         0);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + initialYield + additionalYield - initialFee);
        assertEq(pool.totalAssets(),                     poolLiquidity + initialYield + additionalYield - initialFee);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);
    }

    function test_aaveStrategy_setStrategyFeeRate_withPoolDelegate_fundedStrategy() external {
        vm.prank(poolDelegate);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveStrategy.strategyFeeRate(),         0);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity);

        vm.warp(block.timestamp + 30 days);

        uint256 yield      = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 currentFee = (yield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield,      0);
        assertEq(currentFee, 0);

        assertEq(aaveStrategy.strategyFeeRate(),         0);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.prank(poolDelegate);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(aaveStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        uint256 intermediaryBalance = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = aaveToken.balanceOf(address(aaveStrategy)) - intermediaryBalance;
        uint256 fee             = (additionalYield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(additionalYield, 0);
        assertGt(fee,             0);

        assertEq(aaveStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield + additionalYield - fee);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield);
        assertEq(pool.totalAssets(),                     poolLiquidity + yield + additionalYield - fee);
    }

    function test_aaveStrategy_setStrategyFeeRate_withOperationalAdmin_withWithdrawal() external {
        // Set a non-zero fee rate
        assertEq(aaveStrategy.strategyFeeRate(), 0);

        vm.prank(operationalAdmin);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(aaveStrategy.strategyFeeRate(), strategyFeeRate);

        // Fund the strategy
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(pool.totalAssets(),                     poolLiquidity);

        vm.warp(block.timestamp + 30 days);

        uint256 initialYield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 initialFee   = (initialYield * aaveStrategy.strategyFeeRate()) / 1e6;

        // Update the fee
        uint256 newFeeRate = 0.02e6;

        vm.prank(operationalAdmin);
        aaveStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(aaveStrategy.strategyFeeRate(), newFeeRate);
        assertEq(fundsAsset.balanceOf(treasury), initialFee);  // Treasury should have received the initial fee

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee);
        assertEq(pool.totalAssets(),                     poolLiquidity + initialYield - initialFee);

        uint256 intermediaryBalance = aaveToken.balanceOf(address(aaveStrategy));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = aaveToken.balanceOf(address(aaveStrategy)) - intermediaryBalance;
        uint256 additionalFee   = (additionalYield * newFeeRate) / 1e6;

        assertGt(additionalYield, 0);
        assertGt(additionalFee,   0);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + initialYield + additionalYield - initialFee - additionalFee);
        assertEq(pool.totalAssets(),                     poolLiquidity + initialYield + additionalYield - initialFee - additionalFee);

        uint256 withdrawalAmount = amountToFund / 3;

        // Withdraw from the strategy
        vm.prank(strategyManager);
        aaveStrategy.withdrawFromStrategy(withdrawalAmount);

        assertEq(fundsAsset.balanceOf(treasury), initialFee + additionalFee);

        uint256 aum = (amountToFund - withdrawalAmount) + initialYield + additionalYield - initialFee - additionalFee;

        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   aum, 1);
        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), aum, 1);
    }

}

contract AaveStrategyImpairTests is AaveStrategyTestsBase {

    function test_aaveStrategy_impair_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        aaveStrategy.impairStrategy();
    }

    function test_aaveStrategy_impair_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        aaveStrategy.impairStrategy();
    }

    function test_aaveStrategy_impair_failIfAlreadyImpaired() external {
        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:IS:ALREADY_IMPAIRED");
        aaveStrategy.impairStrategy();
    }

    function test_aaveStrategy_impair_unfundedStrategy() external {
        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

    function test_aaveStrategy_impair_stagnant_noFees() external {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

    function test_aaveStrategy_impair_withGain_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fees);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

    function test_aaveStrategy_impair_withLoss_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;
        uint256 loss  = (amountToFund / 2) - yield;

        // Simulate a loss by transferring funds out
        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield - loss);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - loss);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - loss);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield - loss);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - loss);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - loss);

        assertEq(pool.totalAssets(), poolLiquidity + yield - loss);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

    function test_aaveStrategy_impair_withFullLoss_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;
        uint256 loss  = aaveToken.balanceOf(address(aaveStrategy));

        // Simulate a loss by transferring funds out
        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

    function test_aaveStrategy_impair_withGain_inactive_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        // Deactivate the strategy first
        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);  // Deactivated should set AUM to 0
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);  // AUM should return after impairment
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fees);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired
    }

}

contract AaveStrategyDeactivateTests is AaveStrategyTestsBase {

    function test_aaveStrategy_deactivate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        aaveStrategy.deactivateStrategy();
    }

    function test_aaveStrategy_deactivate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        aaveStrategy.deactivateStrategy();
    }

    function test_aaveStrategy_deactivate_failIfAlreadyInactive() external {
        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:DS:ALREADY_INACTIVE");
        aaveStrategy.deactivateStrategy();
    }

    function test_aaveStrategy_deactivate_unfundedStrategy() external {
        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

    function test_aaveStrategy_deactivate_stagnant_noFees() external {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

    function test_aaveStrategy_deactivate_withGain_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

    function test_aaveStrategy_deactivate_withLoss_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;
        uint256 loss  = (amountToFund / 2) - yield;

        // Simulate a loss by transferring funds out
        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield - loss);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - loss);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - loss);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield - loss);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

    function test_aaveStrategy_deactivate_withFullLoss_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;
        uint256 loss  = aaveToken.balanceOf(address(aaveStrategy));

        // Simulate a loss by transferring funds out
        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

    function test_aaveStrategy_deactivate_withGain_impaired_strategyFees() external {
        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
        uint256 fees  = (yield * aaveStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active

        // Impair the strategy first
        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fees);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated
    }

}

contract AaveReactivateTests is AaveStrategyTestsBase {

    function setUp() public override {
        super.setUp();

        // All tests done with fees, as it's a more realistic scenario and to reduce the possible combinations.
        vm.prank(poolDelegate);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_aaveStrategy_reactivate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        aaveStrategy.reactivateStrategy(false);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        aaveStrategy.reactivateStrategy(true);
    }

    function test_aaveStrategy_reactivate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        aaveStrategy.reactivateStrategy(false);

        vm.expectRevert("MS:NOT_ADMIN");
        aaveStrategy.reactivateStrategy(true);
    }

    function test_aaveStrategy_reactivate_failIfAlreadyActive() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:RS:ALREADY_ACTIVE");
        aaveStrategy.reactivateStrategy(false);

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:RS:ALREADY_ACTIVE");
        aaveStrategy.reactivateStrategy(true);
    }

    function test_aaveStrategy_reactivate_unfunded_fromImpaired_withAccountingUpdate() external {
        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_unfunded_fromImpaired_withoutAccountingUpdate() external {
        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_unfunded_fromInactive_withAccountingUpdate() external {
        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_unfunded_fromInactive_withoutAccountingUpdate() external {
        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_stagnant_fromImpaired_withAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_stagnant_fromImpaired_withoutAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_stagnant_fromInactive_withAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_stagnant_fromInactive_withoutAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)), amountToFund);
        assertEq(aaveStrategy.lastRecordedTotalAssets(),     amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),       amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),            0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withGain_fromImpaired_withAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fees);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        // Fees are not charged retroactively with accounting updates.
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withGain_fromImpaired_withoutAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        amountToFund + yield - fees);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);  // No change as the contract was not touched apart from reactivation.

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withGain_fromInactive_withAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        // Fees are not charged retroactively with accounting updates.
        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund + yield);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withGain_fromInactive_withoutAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertEq(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund + yield);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);  // No change as the contract was not touched apart from reactivation.

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   amountToFund + yield - fees);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withLoss_fromImpaired_withAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund,        1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.unrealizedLosses(),        amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.unrealizedLosses(),        0,                   1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withLoss_fromImpaired_withoutAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        aaveStrategy.impairStrategy();

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund,        1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.unrealizedLosses(),        amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withLoss_fromInactive_withAccountingUpdate() external {
        (, uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(true);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertApproxEqAbs(aaveStrategy.lastRecordedTotalAssets(), amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(aaveStrategy.unrealizedLosses(),        0,                   1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    function test_aaveStrategy_reactivate_withLoss_fromInactive_withoutAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        aaveStrategy.deactivateStrategy();

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(aaveStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        aaveStrategy.reactivateStrategy(false);

        assertApproxEqAbs(aaveToken.balanceOf(address(aaveStrategy)),  amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(aaveStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(aaveStrategy.unrealizedLosses(),        0);

        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(aaveStrategy.strategyState()), 0);  // Active
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _setupStagnantStrategy() internal {
        vm.prank(strategyManager);
        aaveStrategy.fundStrategy(amountToFund);
    }

    function _setupStrategyWithGain() internal returns (uint256 yield) {
        _setupStagnantStrategy();

        vm.warp(block.timestamp + 30 days);

        yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;
    }

    function _setupStrategyWithLoss() internal returns (uint256 yield, uint256 loss) {
        _setupStagnantStrategy();

        vm.warp(block.timestamp + 30 days);

        yield = aaveToken.balanceOf(address(aaveStrategy)) - amountToFund;

        loss = amountToFund / 2;

        // Simulate a loss by transferring funds out
        vm.prank(address(aaveStrategy));
        aaveToken.transfer(address(0xdead), loss + yield);
    }

}
