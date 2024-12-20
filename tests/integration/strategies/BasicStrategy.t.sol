// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC4626Like, IMapleBasicStrategy, IMockERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract BasicStrategyTestsBase is StrategyTestBase {

    address lp = makeAddr("lp");

    uint256 poolLiquidity      = 1_000_000e18;
    uint256 amountToFund       = 100e18;
    uint256 secondAmountToFund = 200e18;
    uint256 strategyFeeRate    = 0.01e6;

    IMapleBasicStrategy basicStrategy;
    IERC4626Like        strategyVault;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDS);

        _createAccounts();
        _createGlobals();
        _setTreasury();
        _createFactories();

        address[] memory factories = new address[](3);

        bytes[] memory deploymentData = new bytes[](3);

        factories[0] = (fixedTermLoanManagerFactory);
        factories[1] = (openTermLoanManagerFactory);
        factories[2] = (basicStrategyFactory);

        deploymentData[0] = (abi.encode(new bytes(0)));
        deploymentData[1] = (abi.encode(new bytes(0)));
        deploymentData[2] = (abi.encode(SAVINGS_USDS));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        vm.stopPrank();

        _createPoolWithQueueAndStrategies(address(fundsAsset), factories, deploymentData);

        _configurePool();

        openPool(address(poolManager));
        deposit(lp, poolLiquidity);

        basicStrategy = IMapleBasicStrategy(_getStrategy(address(basicStrategyFactory)));

        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        strategyVault = IERC4626Like(basicStrategy.strategyVault());
    }

}

contract BasicStrategyFundTests is BasicStrategyTestsBase {

    function testFork_basicStrategy_fund_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failWhenDeactivated() external {
        vm.prank(governor);
        basicStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failWhenImpaired() external {
        vm.prank(governor);
        basicStrategy.impairStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failIfInvalidStrategyVault() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS), false);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:FS:INVALID_VAULT");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failIfZeroAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        basicStrategy.fundStrategy(0, 0);
    }

    function testFork_basicStrategy_fund_failIfInvalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", basicStrategyFactory, false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function testFork_basicStrategy_fund_failIfNotEnoughPoolLiquidity() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        basicStrategy.fundStrategy(poolLiquidity + 1, 0);
    }

    function testFork_basicStrategy_fund_failIfNotEnoughSharesOut() external {
        vm.prank(strategyManager);
        vm.expectRevert("MBS:FS:MIN_SHARES");
        basicStrategy.fundStrategy(amountToFund, amountToFund + 1);
    }

    // NOTE: As ERC4626 vaults round down against the user there may be a diff of 1 wei when converting back to assets.
    function testFork_basicStrategy_fund_firstFundWithPoolDelegate() external {
        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertEq(pool.totalAssets(), poolLiquidity);

        // Initial Fund
        vm.prank(poolDelegate);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);
    }

    function testFork_basicStrategy_fund_firstFundWithStrategyManager() external {
        // Change for full amount of pool liquidity
        amountToFund = 1_000_000e6;

        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertEq(pool.totalAssets(), poolLiquidity);

        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);
    }

    // TODO: Explore why wei diff of 2
    function testFork_basicStrategy_fund_secondFundWithGain_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee                = (yield * strategyFeeRate) / 1e6;

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield - fee, 1);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield - fee,
            2
        );

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield - fee, 2);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield - fee, 2);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield - fee,                     2);
    }

    function testFork_basicStrategy_fund_secondFundWithGain_noStrategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield,
            1
        );

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield, 1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield,                     1);
    }

    function testFork_basicStrategy_fund_secondFundWithGain_withFeesRoundedToZero() external {
        // Set Amount to fund lower to ensure fee rounds down
        amountToFund = 5e6;

        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        vm.warp(block.timestamp + 300 seconds);  // 5 minutes

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertTrue(yield > 0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield,
            1
        );

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield, 1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield,                     1);
    }

    function testFork_basicStrategy_fund_secondFundWithLoss_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 loss               = 1e18;
        uint256 lossShares         = strategyVault.convertToShares(loss);
        uint256 yieldShares        = strategyVault.convertToShares(yield);

        // Transfer out shares to simulate a loss
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares + yieldShares);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,         1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity - loss, 1);

        secondAmountToFund = 10e18;

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund - loss + secondAmountToFund,
            1
        );

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity - loss,                     1);
    }

    function testFork_basicStrategy_fund_secondFundAfterTotalLoss_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 sUSDSBalance = strategyVault.balanceOf(address(basicStrategy));

        // Transfer out all shares to simulate a total loss
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), sUSDSBalance);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(pool.totalAssets(),                      poolLiquidity - amountToFund);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            secondAmountToFund,
            1
        );

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), secondAmountToFund,           1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   secondAmountToFund,           1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity - amountToFund, 1);
    }

}

contract BasicStrategyWithdrawTests is BasicStrategyTestsBase {

    uint256 amountToWithdraw = 40e18;

    // NOTE: Helper needed to ensure round down test has lower initial deposit
    function _fundStrategy() internal {
        uint256 minSharesOut = strategyVault.convertToShares(amountToFund);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, minSharesOut);
    }

    function testFork_basicStrategy_withdraw_failWhenPaused() external {
        _fundStrategy();

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);
    }

    function testFork_basicStrategy_withdraw_failIfNotStrategyManager() external {
        _fundStrategy();

        vm.expectRevert("MS:NOT_MANAGER");
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);
    }

    function testFork_basicStrategy_withdraw_failIfZeroAmount() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MBS:WFS:ZERO_ASSETS");
        basicStrategy.withdrawFromStrategy(0, type(uint256).max);
    }

    function testFork_basicStrategy_withdraw_failIfLowAssets() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert();
        basicStrategy.withdrawFromStrategy(amountToFund + 1, type(uint256).max);
    }

    function testFork_basicStrategy_withdraw_failIfSlippage() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MBS:WFS:SLIPPAGE");
        basicStrategy.withdrawFromStrategy(amountToFund / 2, 0);
    }

    function testFork_basicStrategy_withdraw_failWithFullLoss() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 sUSDSBalance = strategyVault.balanceOf(address(basicStrategy));

        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), sUSDSBalance);  // Also remove yield to round the accounting

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(pool.totalAssets(),                    poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        vm.expectRevert("MBS:WFS:LOW_ASSETS");
        basicStrategy.withdrawFromStrategy(1, type(uint256).max);
    }

    function testFork_basicStrategy_withdraw_withPoolDelegate_noFeesSameBlock() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        _fundStrategy();

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund - amountToWithdraw,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund - amountToWithdraw, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    // TODO: Explore why wei diff of 2
    function testFork_basicStrategy_withdraw_noFeesWithYield() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            2
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw, 2);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw, 2);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 2);
    }

    function testFork_basicStrategy_withdraw_noFeesWithYieldFullWithdrawal() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        amountToWithdraw = basicStrategy.assetsUnderManagement();  // Full Withdrawal

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    // TODO: Explore why wei diff of 2
    function testFork_basicStrategy_withdraw_withFeesAndYield() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertGt(yield, 0);
        assertGt(fee,   0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield - fee, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - fee - amountToWithdraw,
            2
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw - fee, 2);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw - fee, 2);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fee, 2);
    }

    function testFork_basicStrategy_withdraw_withFeesAndYieldFullWithdrawal() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertGt(yield, 0);
        assertGt(fee,   0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield - fee, 1);

        amountToWithdraw = basicStrategy.assetsUnderManagement();  // Full Withdrawal

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fee, 1);
    }

    function testFork_basicStrategy_withdraw_withFeesRoundedToZeroAndYield() external {
        amountToFund     = 5e6;
        amountToWithdraw = 1e6;

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 300 seconds);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        assertGt(yield, 0);
        assertEq(fee,   0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    function testFork_basicStrategy_withdraw_withLoss() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 loss               = 20e18;
        uint256 lossShares         = strategyVault.convertToShares(loss);
        uint256 yieldShares        = strategyVault.convertToShares(yield);

        assertGt(yield, 0);

        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares + yieldShares);  // Also remove yield to round the accounting

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,         1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity - loss, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(strategyVault.convertToAssets(
            strategyVault.balanceOf(address(basicStrategy))),
            amountToFund - amountToWithdraw - loss,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund - amountToWithdraw - loss, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - amountToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);
    }

    // TODO: Explore why wei diff of 2
    function testFork_basicStrategy_withdraw_whileImpaired() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        // Both Yield and Fees should be greater than 0
        assertGt(yield, 0);
        assertGt(fee,   0);

        vm.prank(governor);
        basicStrategy.impairStrategy();

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fee,  1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield - fee, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            2
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees taken when impaired

        // While impaired, the lastRecordedTotalAssets should not be updated
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                            1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw, 2);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - amountToWithdraw, 2);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 2);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Strategy remains Impaired
    }

    // TODO: Explore why wei diff of 2
    function testFork_basicStrategy_withdraw_whileDeactivated() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee   = (yield * strategyFeeRate) / 1e6;

        // Both Yield and Fees should be greater than 0
        assertGt(yield, 0);
        assertGt(fee,   0);

        vm.prank(governor);
        basicStrategy.deactivateStrategy();

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(pool.totalAssets(),                      poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw, type(uint256).max);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            2
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees taken when deactivated

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(),   0);

        // In this scenario, the pool books a loss for the full amount, but adds what was withdrawn
        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Strategy remains Deactivated
    }

}

contract BasicSetStrategyFeeTests is BasicStrategyTestsBase {

    function setUp() public override virtual {
        super.setUp();

        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);
    }

    function testFork_basicStrategy_setStrategyFeeRate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        basicStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function testFork_basicStrategy_setStrategyFeeRate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        basicStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function testFork_basicStrategy_setStrategyFeeRate_failIfBiggerThanHundredPercent() external {
        vm.prank(governor);
        vm.expectRevert("MBS:SSFR:INVALID_FEE_RATE");
        basicStrategy.setStrategyFeeRate(1e6 + 1);
    }

    function testFork_basicStrategy_setStrategyFeeRate_failIfDeactivated() external {
        vm.prank(governor);
        basicStrategy.deactivateStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function testFork_basicStrategy_setStrategyFeeRate_failIfImpaired() external {
        vm.prank(governor);
        basicStrategy.impairStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function testFork_basicStrategy_setStrategyFeeRate_withGovernor_unfundedStrategy() external {
        assertEq(basicStrategy.strategyFeeRate(),         0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(pool.totalAssets(),                      poolLiquidity);

        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(basicStrategy.strategyFeeRate(),         strategyFeeRate);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(pool.totalAssets(),                      poolLiquidity);
    }

    function testFork_basicStrategy_setStrategyFeeRate_withGovernor_fromNonZeroToZeroFeeRate() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(poolDelegate);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(basicStrategy.strategyFeeRate(), strategyFeeRate);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 initialYield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 initialFee   = (initialYield * strategyFeeRate) / 1e6;

        assertGt(initialYield, 0);
        assertGt(initialFee,   0);

        assertEq(basicStrategy.strategyFeeRate(), strategyFeeRate);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee,  1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                              1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + initialYield - initialFee, 1);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        assertEq(basicStrategy.strategyFeeRate(), 0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + initialYield - initialFee, 1);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);

        uint256 intermediaryBalance = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))) - intermediaryBalance;
        uint256 fee             = (additionalYield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(additionalYield, 0);
        assertEq(fee,             0);  // No fees taken when fee rate is 0

        assertEq(basicStrategy.strategyFeeRate(), 0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee,                    1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + initialYield + additionalYield - initialFee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + initialYield + additionalYield - initialFee, 1);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);
    }

    function testFork_basicStrategy_setStrategyFeeRate_withPoolDelegate_fundedStrategy() external {
        vm.prank(poolDelegate);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertEq(basicStrategy.strategyFeeRate(), 0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield      = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 currentFee = (yield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield,      0);
        assertEq(currentFee, 0);

        assertEq(basicStrategy.strategyFeeRate(), 0);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,          1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        vm.prank(poolDelegate);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(basicStrategy.strategyFeeRate(), strategyFeeRate);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield,  1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield, 1);

        assertEq(fundsAsset.balanceOf(treasury), 0);

        uint256 intermediaryBalance = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))) - intermediaryBalance;
        uint256 fee             = (additionalYield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(additionalYield, 0);
        assertGt(fee,             0);

        assertEq(basicStrategy.strategyFeeRate(), strategyFeeRate);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield + additionalYield - fee,  1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield,                          1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + yield + additionalYield - fee, 1);
    }

    function testFork_basicStrategy_setStrategyFeeRate_withOperationalAdmin_withWithdrawal() external {
        // Set a non-zero fee rate
        assertEq(basicStrategy.strategyFeeRate(), 0);

        vm.prank(operationalAdmin);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        assertEq(basicStrategy.strategyFeeRate(), strategyFeeRate);

        // Fund the strategy
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 initialYield = currentTotalAssets - amountToFund;
        uint256 initialFee   = (initialYield * basicStrategy.strategyFeeRate()) / 1e6;

        // Update the fee
        uint256 newFeeRate = 0.02e6;

        vm.prank(operationalAdmin);
        basicStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(basicStrategy.strategyFeeRate(), newFeeRate);
        assertEq(fundsAsset.balanceOf(treasury), initialFee);  // Treasury should have received the initial fee

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee,  1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + initialYield - initialFee,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity + initialYield - initialFee, 1);

        uint256 intermediaryBalance = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        vm.warp(block.timestamp + 30 days);

        uint256 additionalYield = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))) - intermediaryBalance;
        uint256 additionalFee   = (additionalYield * newFeeRate) / 1e6;

        assertGt(additionalYield, 0);
        assertGt(additionalFee,   0);

        assertEq(fundsAsset.balanceOf(treasury), initialFee);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + initialYield - initialFee, 1);

        assertApproxEqAbs(
            basicStrategy.assetsUnderManagement(),
            amountToFund + initialYield + additionalYield - initialFee - additionalFee,
            1
        );
        assertApproxEqAbs(
            pool.totalAssets(),
            poolLiquidity + initialYield + additionalYield - initialFee - additionalFee,
            1
        );

        uint256 withdrawalAmount = amountToFund / 3;

        // Withdraw from the strategy
        vm.prank(strategyManager);
        basicStrategy.withdrawFromStrategy(withdrawalAmount, type(uint256).max);

        assertEq(fundsAsset.balanceOf(treasury), initialFee + additionalFee);

        uint256 aum = (amountToFund - withdrawalAmount) + initialYield + additionalYield - initialFee - additionalFee;

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   aum, 1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), aum, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + initialYield + additionalYield - initialFee - additionalFee, 1);
    }

}

contract BasicStrategyImpairTests is BasicStrategyTestsBase {

    function testFork_basicStrategy_impair_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        basicStrategy.impairStrategy();
    }

    function testFork_basicStrategy_impair_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        basicStrategy.impairStrategy();
    }

    function testFork_basicStrategy_impair_failIfAlreadyImpaired() external {
        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        vm.prank(operationalAdmin);
        vm.expectRevert("MBS:IS:ALREADY_IMPAIRED");
        basicStrategy.impairStrategy();
    }

    function testFork_basicStrategy_impair_unfundedStrategy() external {
        assertEq(strategyVault.balanceOf(address (basicStrategy)),  0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertEq(strategyVault.balanceOf(address (basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),              poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),     0);
        assertEq(fundsAsset.balanceOf(treasury),                   0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

    function testFork_basicStrategy_impair_stagnant_noFees() external {
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

    function testFork_basicStrategy_impair_withGain_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees  = (yield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

    function testFork_basicStrategy_impair_withLoss_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 loss               = amountToFund / 3;
        uint256 lossShares         = strategyVault.convertToShares(loss);

        // Simulate a loss by transferring funds out
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares);

        assertGt(yield, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - loss, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - loss, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

    function testFork_basicStrategy_impair_withFullLoss_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees               = (yield * basicStrategy.strategyFeeRate()) / 1e6;
        uint256 loss               = strategyVault.balanceOf(address(basicStrategy));

        // Simulate a loss by transferring funds out
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(strategyVault.balanceOf(address (basicStrategy)),  0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertEq(strategyVault.balanceOf(address (basicStrategy)),  0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

    function testFork_basicStrategy_impair_withGain_inactive_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees  = (yield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        // Deactivate the strategy first
        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);  // Deactivated should set AUM to 0
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);  // AUM should return after impairment
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired
    }

}

contract BasicStrategyDeactivateTests is BasicStrategyTestsBase {

    function testFork_basicStrategy_deactivate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        basicStrategy.deactivateStrategy();
    }

    function testFork_basicStrategy_deactivate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        basicStrategy.deactivateStrategy();
    }

    function testFork_basicStrategy_deactivate_failIfAlreadyInactive() external {
        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        vm.prank(operationalAdmin);
        vm.expectRevert("MBS:DS:ALREADY_INACTIVE");
        basicStrategy.deactivateStrategy();
    }

    function testFork_basicStrategy_deactivate_unfundedStrategy() external {
        assertEq(strategyVault.balanceOf(address (basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),              poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),     0);
        assertEq(fundsAsset.balanceOf(treasury),                   0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertEq(strategyVault.balanceOf(address (basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),              poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),     0);
        assertEq(fundsAsset.balanceOf(treasury),                   0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

    function testFork_basicStrategy_deactivate_stagnant_noFees() external {
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   0,            1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

    function testFork_basicStrategy_deactivate_withGain_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees  = (yield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

    function testFork_basicStrategy_deactivate_withLoss_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 loss               = amountToFund / 3;
        uint256 lossShares         = strategyVault.convertToShares(loss);

        // Simulate a loss by transferring funds out
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares);

        assertGt(yield, 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - loss, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

    function testFork_basicStrategy_deactivate_withFullLoss_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees               = (yield * basicStrategy.strategyFeeRate()) / 1e6;
        uint256 loss               = strategyVault.balanceOf(address(basicStrategy));

        // Simulate a loss by transferring funds out
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), loss);

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertEq(strategyVault.balanceOf(address (basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),              poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),     0);
        assertEq(fundsAsset.balanceOf(treasury),                   0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertEq(strategyVault.balanceOf(address (basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),              poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),     0);
        assertEq(fundsAsset.balanceOf(treasury),                   0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

    function testFork_basicStrategy_deactivate_withGain_impaired_strategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        uint256 yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fees  = (yield * basicStrategy.strategyFeeRate()) / 1e6;

        assertGt(yield, 0);
        assertGt(fees , 0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active

        // Impair the strategy first
        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,                1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated
    }

}

contract BasicReactivateTests is BasicStrategyTestsBase {

    function setUp() public override {
        super.setUp();

        // All tests done with fees, as it's a more realistic scenario and to reduce the possible combinations.
        vm.prank(poolDelegate);
        basicStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function testFork_basicStrategy_reactivate_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        basicStrategy.reactivateStrategy(false);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        basicStrategy.reactivateStrategy(true);
    }

    function testFork_basicStrategy_reactivate_failIfNotProtocolAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        basicStrategy.reactivateStrategy(false);

        vm.expectRevert("MS:NOT_ADMIN");
        basicStrategy.reactivateStrategy(true);
    }

    function testFork_basicStrategy_reactivate_failIfAlreadyActive() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MBS:RS:ALREADY_ACTIVE");
        basicStrategy.reactivateStrategy(false);

        vm.prank(operationalAdmin);
        vm.expectRevert("MBS:RS:ALREADY_ACTIVE");
        basicStrategy.reactivateStrategy(true);
    }

    function testFork_basicStrategy_reactivate_unfunded_fromImpaired_withAccountingUpdate() external {
        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_unfunded_fromImpaired_withoutAccountingUpdate() external {
        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_unfunded_fromInactive_withAccountingUpdate() external {
        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),             poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),    0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),             poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),    0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_unfunded_fromInactive_withoutAccountingUpdate() external {
        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),             poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),    0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertEq(strategyVault.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),             poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)),    0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(basicStrategy.unrealizedLosses(),        0);

        assertEq(pool.totalAssets(), poolLiquidity);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_stagnant_fromImpaired_withAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_stagnant_fromImpaired_withoutAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_stagnant_fromInactive_withAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_stagnant_fromInactive_withoutAccountingUpdate() external {
        _setupStagnantStrategy();

        vm.prank(poolDelegate);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertEq(pool.totalAssets(), poolLiquidity - amountToFund);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withGain_fromImpaired_withAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        // Fees are not charged retroactively with accounting updates.
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withGain_fromImpaired_withoutAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No change as the contract was not touched apart from reactivation.

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withGain_fromInactive_withAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withGain_fromInactive_withoutAccountingUpdate() external {
        uint256 yield = _setupStrategyWithGain();
        uint256 fees = yield * strategyFeeRate / 1e6;

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund + yield, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No change as the contract was not touched apart from reactivation.

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fees, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withLoss_fromImpaired_withAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,        1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        0,                   1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withLoss_fromImpaired_withoutAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        basicStrategy.impairStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund,        1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),        amountToFund - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Impaired

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withLoss_fromInactive_withAccountingUpdate() external {
        (, uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(true);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund - loss, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    function testFork_basicStrategy_reactivate_withLoss_fromInactive_withoutAccountingUpdate() external {
        ( , uint256 loss) = _setupStrategyWithLoss();

        vm.prank(operationalAdmin);
        basicStrategy.deactivateStrategy();

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(basicStrategy.unrealizedLosses(),      0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Deactivated

        vm.prank(operationalAdmin);
        basicStrategy.reactivateStrategy(false);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund - loss, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss, 1);

        assertEq(basicStrategy.unrealizedLosses(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertEq(uint256(basicStrategy.strategyState()), 0);  // Active
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _setupStagnantStrategy() internal {
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund, 0);
    }

    function _setupStrategyWithGain() internal returns (uint256 yield) {
        _setupStagnantStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
    }

    function _setupStrategyWithLoss() internal returns (uint256 yield, uint256 loss) {
        _setupStagnantStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));

        yield = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        loss  = amountToFund / 3;

        uint256 lossShares = strategyVault.convertToShares(loss);
        uint256 yieldShares = strategyVault.convertToShares(yield);

        // Simulate a loss by transferring funds out
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares + yieldShares);
    }

}
