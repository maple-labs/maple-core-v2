// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAaveStrategy, IMockERC20 } from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Runner.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract AaveStrategyTests is StrategyTestBase {

    address lp = makeAddr("lp");

    uint256 poolLiquidity   = 1_000_000e6;
    uint256 amountToFund    = 100e6;
    uint256 strategyFeeRate = 0.01e6;

    IAaveStrategy aaveStrategy;
    IMockERC20    aaveToken;

    function setUp() public override {
        super.setUp();

        openPool(address(poolManager));
        deposit(lp, poolLiquidity);

        aaveStrategy = IAaveStrategy(_getStrategy(address(aaveStrategyFactory)));

        vm.prank(governor);
        aaveStrategy.setStrategyFeeRate(strategyFeeRate);

        aaveToken = IMockERC20(address(aaveStrategy.aaveToken()));
    }

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

    function test_aaveStrategy_fund_successWithPoolDelegate() external {
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

    function test_aaveStrategy_fund_successWithStrategyManager() external {
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

    function test_aaveStrategy_fund_successSecondTime() external {
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

    function test_aaveStrategy_fund_successSecondTimeWithNoFees() external {
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

    function test_aaveStrategy_fund_successSecondTimeWithFeesRoundedToZero() external {
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

    function test_aaveStrategy_fund_successSecondTimeWithLoss() external {
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
