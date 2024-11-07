// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC4626Like, IMapleBasicStrategy, IMockERC20 } from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Runner.sol";

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

        ( address poolManager_, address pool_, , , ) =
            deployer.getDeploymentAddresses({
                poolDelegate_:             address(poolDelegate),
                poolManagerFactory_:       address(poolManagerFactory),
                withdrawalManagerFactory_: address(queueWMFactory),
                strategyFactories_:        new address[](0),
                strategyDeploymentData_:   new bytes[](0),
                asset_:                    address(fundsAsset),
                name_:                     POOL_NAME,
                symbol_:                   POOL_SYMBOL,
                configParams_:             [type(uint256).max, 0, 0, 0]
            });

        address[] memory factories = new address[](3);

        bytes[] memory deploymentData = new bytes[](3);

        factories[0] = (fixedTermLoanManagerFactory);
        factories[1] = (openTermLoanManagerFactory);
        factories[2] = (basicStrategyFactory);

        deploymentData[0] = (abi.encode(poolManager_));
        deploymentData[1] = (abi.encode(poolManager_));
        deploymentData[2] = (abi.encode(pool_, SAVINGS_USDS));

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

    function test_basicStrategy_fund_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failWhenDeactivated() external {
        vm.prank(governor);
        basicStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failWhenImpaired() external {
        vm.prank(governor);
        basicStrategy.impairStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failIfInvalidStrategyVault() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS), false);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:FS:INVALID_STRATEGY_VAULT");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failIfZeroAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        basicStrategy.fundStrategy(0);
    }

    function test_basicStrategy_fund_failIfInvalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", basicStrategyFactory, false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_fund_failIfNotEnoughPoolLiquidity() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        basicStrategy.fundStrategy(poolLiquidity + 1);
    }

    // NOTE: As ERC4626 vaults round down against the user there may be a diff of 1 wei when converting back to assets.
    function test_basicStrategy_fund_firstFundWithPoolDelegate() external {
        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertEq(pool.totalAssets(), poolLiquidity);

        // Initial Fund
        vm.prank(poolDelegate);
        basicStrategy.fundStrategy(amountToFund);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity, 1);
    }

    function test_basicStrategy_fund_firstFundWithStrategyManager() external {
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
        basicStrategy.fundStrategy(amountToFund);

        assertApproxEqAbs(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), amountToFund, 1);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity, 1);
    }

    function test_basicStrategy_fund_secondFundWithGain_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 fee                = (yield * strategyFeeRate) / 1e6;

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund + yield - fee,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity + yield - fee, 1);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield - fee,
            1
        );

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield - fee);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund + secondAmountToFund + yield - fee, 1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity + yield - fee,                     1);
    }

    function test_basicStrategy_fund_secondFundWithGain_noStrategyFees() external {
        vm.prank(governor);
        basicStrategy.setStrategyFeeRate(0);

        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(pool.totalAssets(),                      poolLiquidity + yield);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield,
            1
        );

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield);
        assertEq(basicStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield);
        assertEq(pool.totalAssets(),                      poolLiquidity + yield);
    }

    function test_basicStrategy_fund_secondFundWithGain_withFeesRoundedToZero() external {
        // Set Amount to fund lower to ensure fee rounds down
        amountToFund = 5e6;

        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund, 1);

        vm.warp(block.timestamp + 300 seconds);  // 5 minutes

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();

        assertTrue(yield > 0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   amountToFund + yield);
        assertEq(pool.totalAssets(),                      poolLiquidity + yield);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees were taken by the treasury

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + secondAmountToFund + yield,
            1
        );

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund + secondAmountToFund + yield);
        assertEq(basicStrategy.assetsUnderManagement(),   amountToFund + secondAmountToFund + yield);
        assertEq(pool.totalAssets(),                      poolLiquidity + yield);
    }

    function test_basicStrategy_fund_secondFundWithLoss_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 currentTotalAssets = strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy)));
        uint256 yield              = currentTotalAssets - basicStrategy.lastRecordedTotalAssets();
        uint256 loss               = 1e18;
        uint256 lossShares         = strategyVault.convertToShares(loss);
        uint256 yieldShares        = strategyVault.convertToShares(yield);

        // Transfer out shares to simulate a loss
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), lossShares + yieldShares);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund - loss,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity - loss, 1);

        secondAmountToFund = 10e18;

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund);

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

    function test_basicStrategy_fund_secondFundAfterTotalLoss_withStrategyFees() external {
        // Initial Fund
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund, 1);

        vm.warp(block.timestamp + 30 days);

        uint256 sUSDSBalance = strategyVault.balanceOf(address(basicStrategy));

        // Transfer out all shares to simulate a total loss
        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), sUSDSBalance);

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(pool.totalAssets(),                      poolLiquidity - amountToFund);

        // Fund a second time
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(secondAmountToFund);

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
        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);
    }

    function test_basicStrategy_withdraw_failWhenPaused() external {
        _fundStrategy();

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        basicStrategy.withdrawFromStrategy(amountToWithdraw);
    }

    function test_basicStrategy_withdraw_failIfNotStrategyManager() external {
        _fundStrategy();

        vm.expectRevert("MS:NOT_MANAGER");
        basicStrategy.withdrawFromStrategy(amountToWithdraw);
    }

    function test_basicStrategy_withdraw_failIfZeroAmount() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MBS:WFS:ZERO_ASSETS");
        basicStrategy.withdrawFromStrategy(0);
    }

    function test_basicStrategy_withdraw_failIfLowAssets() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert();
        basicStrategy.withdrawFromStrategy(amountToFund + 1);
    }

    function test_basicStrategy_withdraw_failWithFullLoss() external {
        _fundStrategy();

        vm.warp(block.timestamp + 30 days);

        uint256 sUSDSBalance = strategyVault.balanceOf(address(basicStrategy));

        vm.prank(address(basicStrategy));
        strategyVault.transfer(address(0xdead), sUSDSBalance);  // Also remove yield to round the accounting

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertEq(basicStrategy.assetsUnderManagement(), 0);
        assertEq(pool.totalAssets(),                    poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        vm.expectRevert("MBS:WFS:LOW_ASSETS");
        basicStrategy.withdrawFromStrategy(1);
    }

    function test_basicStrategy_withdraw_withPoolDelegate_noFeesSameBlock() external {
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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

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

    function test_basicStrategy_withdraw_noFeesWithYield() external {
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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

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

    function test_basicStrategy_withdraw_noFeesWithYieldFullWithdrawal() external {
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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    function test_basicStrategy_withdraw_withFeesAndYield() external {
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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - fee - amountToWithdraw,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertApproxEqAbs(basicStrategy.lastRecordedTotalAssets(), amountToFund + yield - amountToWithdraw - fee, 1);
        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund + yield - amountToWithdraw - fee, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fee, 1);
    }

    function test_basicStrategy_withdraw_withFeesAndYieldFullWithdrawal() external {
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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

        assertEq(strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               fee);

        assertEq(basicStrategy.lastRecordedTotalAssets(), 0);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fee, 1);
    }

    function test_basicStrategy_withdraw_withFeesRoundedToZeroAndYield() external {
        amountToFund     = 5e6;
        amountToWithdraw = 1e6;

        vm.prank(strategyManager);
        basicStrategy.fundStrategy(amountToFund);

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
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

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

    function test_basicStrategy_withdraw_withLoss() external {
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

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(),   amountToFund - loss,  1);
        assertApproxEqAbs(pool.totalAssets(),                      poolLiquidity - loss, 1);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

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

    function test_basicStrategy_withdraw_whileImpaired() external {
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

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   amountToFund + yield - fee);
        assertEq(basicStrategy.unrealizedLosses(),        amountToFund + yield - fee);
        assertEq(pool.totalAssets(),                      poolLiquidity + yield - fee);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees taken when impaired

        // While impaired, the lastRecordedTotalAssets should not be updated
        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);

        assertApproxEqAbs(basicStrategy.assetsUnderManagement(), amountToFund + yield - amountToWithdraw, 1);
        assertApproxEqAbs(basicStrategy.unrealizedLosses(),      amountToFund + yield - amountToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertEq(uint256(basicStrategy.strategyState()), 1);  // Strategy remains Impaired
    }

    function test_basicStrategy_withdraw_whileDeactivated() external {
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

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   0);
        assertEq(pool.totalAssets(),                      poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        basicStrategy.withdrawFromStrategy(amountToWithdraw);

        assertApproxEqAbs(
            strategyVault.convertToAssets(strategyVault.balanceOf(address(basicStrategy))),
            amountToFund + yield - amountToWithdraw,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),          poolLiquidity - amountToFund + amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(basicStrategy)), 0);
        assertEq(fundsAsset.balanceOf(treasury),               0);  // No fees taken when deactivated

        assertEq(basicStrategy.lastRecordedTotalAssets(), amountToFund);
        assertEq(basicStrategy.assetsUnderManagement(),   0);

        // In this scenario, the pool books a loss for the full amount, but adds what was withdrawn
        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - amountToFund + amountToWithdraw, 1);

        assertEq(uint256(basicStrategy.strategyState()), 2);  // Strategy remains Deactivated
    }

}
