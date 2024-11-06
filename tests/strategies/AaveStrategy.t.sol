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

        assertEq(aaveStrategy.lastRecordedTotalAssets(), amountToFund - loss + secondAmountToFund);

        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(pool.totalAssets(),                   poolLiquidity - loss,                     1);

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
