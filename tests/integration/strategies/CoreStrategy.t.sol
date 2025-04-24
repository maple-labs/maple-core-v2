// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC4626Like,
    IMockERC20,
    IERC20Like,
    IMapleCoreStrategy,
    IGlobals,
    IWithdrawalManagerQueue,
    IERC4626Like,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { StrategyState } from "../../../modules/strategies/contracts/interfaces/IMapleStrategy.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract CoreStrategyTestsBase is StrategyTestBase {

    address lp                 = makeAddr("lp");
    address secondPoolDelegate = makeAddr("secondPoolDelegate");

    uint256 poolLiquidity      = 1_000_000_000_000e6;
    uint256 amountToFund       = 100_000_000e6;
    uint256 secondAmountToFund = 200_000_000e6;

    IMapleCoreStrategy      coreStrategy;
    IERC4626Like            secondMaplePool;
    IPoolManager            secondMaplePoolManager;
    IWithdrawalManagerQueue secondMapleWithdrawalManager;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _createFactories();

        address[] memory strategyFactories    = new address[](1);
        bytes[] memory strategyDeploymentData = new bytes[](1);

        strategyFactories[0]      = openTermLoanManagerFactory;
        strategyDeploymentData[0] = abi.encode(new bytes(0));

        vm.prank(globals.governor());
        globals.setValidPoolDelegate(secondPoolDelegate, true);

        (address pool_, address pm_, ) = _createAdditionalPoolWithQueueAndStrategies(
            address(fundsAsset), secondPoolDelegate, strategyFactories, strategyDeploymentData
        );

        activatePool(address(pm_), HUNDRED_PERCENT);
        openPool(address(pm_));

        secondMaplePoolManager  = IPoolManager(address(pm_));

        address[] memory factories = new address[](5);

        bytes[] memory deploymentData = new bytes[](5);

        // Add both aave and sky strategy factories
        factories[0] = (fixedTermLoanManagerFactory);
        factories[1] = (openTermLoanManagerFactory);
        factories[2] = (aaveStrategyFactory);
        factories[3] = (skyStrategyFactory);
        factories[4] = (coreStrategyFactory);

        deploymentData[0] = (abi.encode(new bytes(0)));
        deploymentData[1] = (abi.encode(new bytes(0)));
        deploymentData[2] = (abi.encode(AAVE_USDC));
        deploymentData[3] = (abi.encode(SAVINGS_USDS, USDS_LITE_PSM));
        deploymentData[4] = (abi.encode(pool_));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(pool_),         true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        vm.stopPrank();

        _createPoolWithQueueAndStrategies(address(fundsAsset), factories, deploymentData);

        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), address(queueWM));

        deposit(lp, poolLiquidity);

        coreStrategy    = IMapleCoreStrategy(_getStrategy(coreStrategyFactory));
        secondMaplePool = IERC4626Like(coreStrategy.strategyVault());

        assertEq(address(secondMaplePool), pool_);

        secondMapleWithdrawalManager = IWithdrawalManagerQueue(
            coreStrategy.mapleWithdrawalManager()
        );

        vm.label(address(fundsAsset),      "USDC");
        vm.label(pool_,                    "AdditionalPool");
        vm.label(pm_,                      "AdditionalPoolManager");
        vm.label(address(coreStrategy),    "CoreStrategy");
        vm.label(address(secondMaplePool), "secondMaplePool");
    }

    function _fundStrategy() internal {
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);
    }

}

contract CoreStrategyFundTests is CoreStrategyTestsBase {

    function testFork_coreStrategy_fund_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failWhenDeactivated() external {
        vm.prank(governor);
        coreStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failWhenImpaired() external {
        vm.prank(governor);
        coreStrategy.impairStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failIfInvalidStrategyVault() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(secondMaplePool), false);

        vm.prank(strategyManager);
        vm.expectRevert("MCS:FS:INVALID_VAULT");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failIfZeroAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        coreStrategy.fundStrategy(0);
    }

    function testFork_coreStrategy_fund_failIfInvalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", coreStrategyFactory, false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        coreStrategy.fundStrategy(amountToFund);
    }

    function testFork_coreStrategy_fund_failIfNotEnoughPoolLiquidity() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        coreStrategy.fundStrategy(poolLiquidity + 1);
    }

    // NOTE: As ERC4626 vaults round down against the user there may be a diff of 1 wei when converting back to assets.
    function testFork_coreStrategy_fund_firstFundWithPoolDelegate() external {
        assertEq(secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), 0);
        assertEq(coreStrategy.assetsUnderManagement(),           0);
        assertEq(pool.totalAssets(),                             poolLiquidity);
        assertEq(secondMaplePool.totalAssets(),                  0);

        vm.prank(poolDelegate);
        coreStrategy.fundStrategy(amountToFund);

        assertApproxEqAbs(
            secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))),
            amountToFund,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund);

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(),  amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity, 1);
        assertApproxEqAbs(secondMaplePool.totalAssets(),         amountToFund,  1);
    }

    function testFork_coreStrategy_fund_firstFundWithStrategyManager() external {
        // Change for full amount of pool liquidity
        amountToFund = 1_000_000e6;

        assertEq(secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), 0);
        assertEq(coreStrategy.assetsUnderManagement(),           0);
        assertEq(pool.totalAssets(),                             poolLiquidity);
        assertEq(secondMaplePool.totalAssets(),                  0);

        // Initial Fund
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);

        assertApproxEqAbs(
            secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))),
            amountToFund,
            1
        );

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund);

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(),  amountToFund,  1);
        assertApproxEqAbs(pool.totalAssets(),                    poolLiquidity, 1);
        assertApproxEqAbs(secondMaplePool.totalAssets(),         amountToFund,  1);
    }

    function testFork_coreStrategy_fund_secondFundWithGain() external {
        // Initial Fund
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),           amountToFund);
        assertEq(secondMaplePool.totalAssets(),                  amountToFund);

        uint256 amountToGain = 1_000_000e6;
        uint256 shares       = secondMaplePool.balanceOf(address(coreStrategy));

        uint256 assetsBefore = secondMaplePool.convertToAssets(shares);

        fundsAsset.mint(address(secondMaplePool), amountToGain);

        // Confirm share value of the secondMaplePool has increased
        assertGt(secondMaplePool.convertToAssets(shares), assetsBefore);

        // Second Fund
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(secondAmountToFund);

        assertEq(coreStrategy.assetsUnderManagement(),           amountToFund + secondAmountToFund + amountToGain);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund + secondAmountToFund + amountToGain);

        assertApproxEqAbs(secondMaplePool.totalAssets(), amountToFund + amountToGain + secondAmountToFund, 1);
    }

    function testFork_coreStrategy_fund_secondFundWithLoss() external {
        // Initial Fund
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund);
        assertEq(secondMaplePool.totalAssets(),                  amountToFund);

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(), amountToFund, 1);

        uint256 loss       = 1_000_000e6;
        uint256 lossShares = secondMaplePool.convertToShares(loss);

        // Transfer out shares to simulate a loss
        vm.prank(address(coreStrategy));
        secondMaplePool.transfer(address(0xdead), lossShares);

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(), amountToFund - loss,  1);
        assertApproxEqAbs(pool.totalAssets(),                   poolLiquidity - loss, 1);

        secondAmountToFund = 10_000_000e6;

        // Fund a second time
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund + secondAmountToFund);

        assertApproxEqAbs(
            secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))),
            amountToFund - loss + secondAmountToFund,
            1
        );

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(), amountToFund - loss + secondAmountToFund, 1);
        assertApproxEqAbs(pool.totalAssets(),                   poolLiquidity - loss,                     1);
        assertApproxEqAbs(secondMaplePool.totalAssets(),        amountToFund + secondAmountToFund,        1);
    }

    function testFork_coreStrategy_fund_secondFundAfterTotalLoss() external {
        // Initial Fund
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund);
        assertEq(secondMaplePool.totalAssets(),                  amountToFund);

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(), amountToFund, 1);

        uint256 shareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        // Transfer out all shares to simulate a total loss
        vm.prank(address(coreStrategy));
        secondMaplePool.transfer(address(0xdead), shareBalance);

        assertEq(coreStrategy.assetsUnderManagement(), 0);
        assertEq(pool.totalAssets(),                   poolLiquidity - amountToFund);

        // Fund a second time
        vm.prank(strategyManager);
        coreStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(pool)),            poolLiquidity - amountToFund - secondAmountToFund);
        assertEq(fundsAsset.balanceOf(address(coreStrategy)),    0);
        assertEq(fundsAsset.balanceOf(address(secondMaplePool)), amountToFund + secondAmountToFund);

        assertApproxEqAbs(
            secondMaplePool.convertToAssets(secondMaplePool.balanceOf(address(coreStrategy))),
            secondAmountToFund,
            1
        );

        assertApproxEqAbs(coreStrategy.assetsUnderManagement(), secondAmountToFund,                1);
        assertApproxEqAbs(pool.totalAssets(),                   poolLiquidity - amountToFund,      1);
        assertApproxEqAbs(secondMaplePool.totalAssets(),        amountToFund + secondAmountToFund, 1);
    }

}

contract CoreStrategyRequestWithdrawFromStrategyTests is CoreStrategyTestsBase {

    uint256 amountToWithdraw = 40_000_000e6;

    function testFork_coreStrategy_requestWithdrawFromStrategy_failWhenPaused() external {
        _fundStrategy();

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("MS:PAUSED");
        coreStrategy.requestWithdrawFromStrategy(amountToWithdraw);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failIfNotStrategyManager() external {
        _fundStrategy();

        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.requestWithdrawFromStrategy(amountToWithdraw);

        vm.prank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(amountToWithdraw);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failIfNotPoolDelegate() external {
        _fundStrategy();

        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.requestWithdrawFromStrategy(amountToWithdraw);

        vm.prank(poolDelegate);
        coreStrategy.requestWithdrawFromStrategy(amountToWithdraw);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failIfZeroAmount() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MCS:RWFS:ZERO_ASSETS");
        coreStrategy.requestWithdrawFromStrategy(0);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failIfLowAssets() external {
        _fundStrategy();

        vm.prank(strategyManager);
        vm.expectRevert(arithmeticError);
        coreStrategy.requestWithdrawFromStrategy(amountToFund + 1);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failWithFullLoss() external {
        _fundStrategy();

        uint256 shareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        vm.prank(address(coreStrategy));
        secondMaplePool.transfer(address(0xdead), shareBalance);  // Remove assets to simulate a full loss

        assertEq(coreStrategy.assetsUnderManagement(), 0);
        assertEq(pool.totalAssets(),                   poolLiquidity - amountToFund);

        vm.prank(poolDelegate);
        vm.expectRevert(arithmeticError);
        coreStrategy.requestWithdrawFromStrategy(1);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_failWithNoAssets() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertNotEq(aum, 0);

        vm.startPrank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(aum);

        vm.expectRevert(arithmeticError);
        coreStrategy.requestWithdrawFromStrategy(1);
        vm.stopPrank();
    }


    function testFork_coreStrategy_requestWithdrawFromStrategy_failWithMultipleWithdrawals() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertNotEq(aum, 0);

        vm.startPrank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(aum - 1);

        vm.expectRevert("WM:AS:IN_QUEUE");
        coreStrategy.requestWithdrawFromStrategy(1);

        vm.stopPrank();
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_success() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertNotEq(aum, 0);

        assertEq(secondMapleWithdrawalManager.requestIds(address(coreStrategy)), 0);

        vm.startPrank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(aum);
        vm.stopPrank();

        assertEq(coreStrategy.assetsUnderManagement(), aum);
        assertEq(pool.totalAssets(),                   poolLiquidity);

        assertNotEq(secondMapleWithdrawalManager.requestIds(address(coreStrategy)), 0);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_successWithPartialWithdrawal() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertNotEq(aum, 0);

        assertEq(secondMapleWithdrawalManager.requestIds(address(coreStrategy)), 0);

        vm.startPrank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(aum - 1);
        vm.stopPrank();

        assertEq(coreStrategy.assetsUnderManagement(), aum);
        assertEq(pool.totalAssets(),                   poolLiquidity);

        uint128 requestId = secondMapleWithdrawalManager.requestIds(address(coreStrategy));

        ( address owner, uint256 shares ) = secondMapleWithdrawalManager.requests(requestId);

        assertNotEq(requestId, 0);
        assertEq(owner,        address(coreStrategy));

        assertApproxEqAbs(aum, shares, 1);
    }

    function testFork_coreStrategy_requestWithdrawFromStrategy_successAfterPartialLoss() external {
        _fundStrategy();

        uint256 loss         = 1000;
        uint256 aumAfterLoss = coreStrategy.assetsUnderManagement() - loss;

        vm.prank(address(coreStrategy));
        secondMaplePool.transfer(address(0xdead), loss);

        assertNotEq(aumAfterLoss, 0);

        assertEq(secondMapleWithdrawalManager.requestIds(address(coreStrategy)), 0);

        vm.startPrank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(aumAfterLoss);
        vm.stopPrank();

        assertEq(coreStrategy.assetsUnderManagement(), aumAfterLoss);
        assertEq(pool.totalAssets(),                   poolLiquidity - loss);

        assertNotEq(secondMapleWithdrawalManager.requestIds(address(coreStrategy)), 0);
    }

}

contract CoreStrategyDeactivateStrategyTests is CoreStrategyTestsBase {

    function testFork_deactivateStrategy_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        coreStrategy.deactivateStrategy();
        assertEq(coreStrategy.assetsUnderManagement(), 0);
    }

    function testFork_deactivateStrategy_failWhenNotPoolDelegate() external {
        vm.expectRevert("MS:NOT_ADMIN");
        coreStrategy.deactivateStrategy();

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.assetsUnderManagement(),  0);
    }

    function testFork_deactivateStrategy_failWhenNotGovernor() external {
        vm.expectRevert("MS:NOT_ADMIN");
        coreStrategy.deactivateStrategy();

        vm.prank(governor);
        coreStrategy.deactivateStrategy();
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.assetsUnderManagement(),  0);
    }

    function testFork_deactivateStrategy_failWhenNotOperationalAdmin() external {
        address operationalAdmin = IGlobals(globals).operationalAdmin();

        vm.expectRevert("MS:NOT_ADMIN");
        coreStrategy.deactivateStrategy();

        vm.prank(operationalAdmin);
        coreStrategy.deactivateStrategy();
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.assetsUnderManagement(),  0);
    }

    function testFork_deactivateStrategy_failWhenAlreadyDeactivated() external {
        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MCS:DS:ALREADY_INACTIVE");
        coreStrategy.deactivateStrategy();

        assertEq(coreStrategy.assetsUnderManagement(), 0);
    }

    function testFork_deactivateStrategy_success() external {
        _fundStrategy();

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.assetsUnderManagement(),  0);
    }

    function testFork_deactivateStrategy_successWhenAlreadyImpaired() external {
        _fundStrategy();

        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();

        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Impaired));
        assertEq(coreStrategy.unrealizedLosses(),       coreStrategy.assetsUnderManagement());

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.assetsUnderManagement(),  0);
        assertEq(coreStrategy.unrealizedLosses(),       0);
    }

    function testFork_deactivateStrategy_correctAumAfterDeactivation() external {
        _fundStrategy();

        assertNotEq(coreStrategy.assetsUnderManagement(), 0);

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        assertEq(coreStrategy.assetsUnderManagement(), 0);
    }

}

contract CoreStrategyImpairedStrategyTests is CoreStrategyTestsBase {

    function testFork_impairedStrategy_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        coreStrategy.impairStrategy();
    }

    function testFork_impairedStrategy_failWhenNotAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        coreStrategy.impairStrategy();

        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();
    }

    function testFork_impairedStrategy_failWhenAlreadyImpaired() external {
        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MCS:IS:ALREADY_IMPAIRED");
        coreStrategy.impairStrategy();
    }

    function testFork_impairedStrategy_success() external {
        assertEq(coreStrategy.assetsUnderManagement(), 0);

        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertEq(coreStrategy.assetsUnderManagement(), amountToFund);
        assertEq(coreStrategy.unrealizedLosses(),      0);

        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();

        assertEq(coreStrategy.unrealizedLosses(),       aum);
        assertEq(coreStrategy.assetsUnderManagement(),  aum);
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Impaired));
    }

    function testFork_impairedStrategy_successWhenAlreadyDeactivated() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Inactive));
        assertEq(coreStrategy.unrealizedLosses(),       0);
        assertEq(coreStrategy.assetsUnderManagement(),  0);

        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();

        assertEq(coreStrategy.assetsUnderManagement(),  aum);
        assertEq(coreStrategy.unrealizedLosses(),       aum);
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Impaired));
    }

    function testFork_impairedStrategy_correctAumAfterImpairment() external {
        _fundStrategy();

        uint256 aum = coreStrategy.assetsUnderManagement();

        assertNotEq(aum, 0);
        assertEq(coreStrategy.unrealizedLosses(), 0);

        vm.prank(poolDelegate);
        coreStrategy.impairStrategy();

        uint256 newAum = coreStrategy.assetsUnderManagement();

        assertEq(aum,                                  newAum);
        assertEq(coreStrategy.unrealizedLosses(),      aum);
        assertEq(coreStrategy.assetsUnderManagement(), coreStrategy.unrealizedLosses());
    }

}

contract CoreStrategyReactivateStrategyTests is CoreStrategyTestsBase {

    function testFork_reactivateStrategy_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        coreStrategy.reactivateStrategy();
    }

    function testFork_reactivateStrategy_failWhenNotAdmin() external {
        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        vm.expectRevert("MS:NOT_ADMIN");
        coreStrategy.reactivateStrategy();

        vm.prank(governor);
        coreStrategy.reactivateStrategy();
    }

    function testFork_reactivateStrategy_failWhenAlreadyActive() external {
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Active));

        vm.prank(poolDelegate);
        vm.expectRevert("MCS:RS:ALREADY_ACTIVE");
        coreStrategy.reactivateStrategy();
    }

    function testFork_reactivateStrategy_aumCorrectAfterReactivation() external {
        assertEq(uint256(coreStrategy.strategyState()), uint256(StrategyState.Active));

        _fundStrategy();

        uint256 aumBefore = coreStrategy.assetsUnderManagement();

        assertNotEq(aumBefore, 0);

        vm.prank(poolDelegate);
        coreStrategy.deactivateStrategy();

        assertEq(coreStrategy.assetsUnderManagement(), 0);

        vm.prank(governor);
        coreStrategy.reactivateStrategy();

        assertEq(coreStrategy.assetsUnderManagement(), aumBefore);
    }

}

contract CoreStrategyPushAssetsTests is CoreStrategyTestsBase {

    function _requestWithdrawalFromStrategy(uint256 amount) internal {
        vm.prank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(amount);
    }

    function _processAllWithdrawalsByOwnerShares(IWithdrawalManagerQueue withdrawalManager, address owner) internal {
        uint128 requestId = withdrawalManager.requestIds(owner);
        ( , uint256 shares ) = withdrawalManager.requests(requestId);

        _processWithdrawalRequests(withdrawalManager, shares);
    }

    function _processWithdrawalRequests(IWithdrawalManagerQueue withdrawalManager, uint256 sharesToProcess) internal {
        vm.prank(secondPoolDelegate);
        withdrawalManager.processRedemptions(sharesToProcess);
    }

    function testFork_coreStrategy_pushAssetsToPool_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyManager);
        vm.expectRevert("MS:PAUSED");

        coreStrategy.pushAssetsToPool();
    }

    function testFork_coreStrategy_pushAssetsToPool_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.pushAssetsToPool();

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();
    }

    function testFork_coreStrategy_pushAssetsToPool_failIfNotPoolDelegate() external {
        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.pushAssetsToPool();

        vm.prank(poolDelegate);
        coreStrategy.pushAssetsToPool();
    }

    function testFork_coreStrategy_pushAssetsToPool_failTransfer() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);
        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        vm.mockCall(
            address(fundsAsset),
            abi.encodeWithSelector(IERC20Like.transfer.selector, address(pool), amountToFund),
            abi.encode(false)
        );
        vm.expectRevert("MCS:PATP:TRANSFER_FAILED");

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenZeroBalance() external {
        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);

        uint256 poolBalanceBefore = fundsAsset.balanceOf(address(pool));

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolBalanceBefore);
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenPositiveBalance() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);
        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        uint256 poolBalanceBefore = fundsAsset.balanceOf(address(pool));

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund);

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolBalanceBefore + amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        0);
    }

    function testFork_coreStrategy_pushAssetsToPool_successAfterAdditionalFunding() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);
        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        vm.prank(strategyManager);
        coreStrategy.fundStrategy(secondAmountToFund);

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - (amountToFund + secondAmountToFund));
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund + secondAmountToFund);

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - secondAmountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        secondAmountToFund);
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenPartialWithdrawalProcessed() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);

        uint256 tenthOfStrategyShares = secondMaplePool.convertToAssets(amountToFund / 10);

        _processWithdrawalRequests(secondMapleWithdrawalManager, tenthOfStrategyShares);

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), tenthOfStrategyShares);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund);

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund + tenthOfStrategyShares);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund - tenthOfStrategyShares);
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenPartialWithdrawalRequested() external {
        uint256 amountToWithdraw = amountToFund / 2;

        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToWithdraw);

        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), amountToWithdraw);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund);

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToWithdraw);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund - amountToWithdraw);
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenImpaired() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);
        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund);

        vm.prank(governor);
        coreStrategy.impairStrategy();

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(coreStrategy.assetsUnderManagement(),        0);
    }

    function testFork_coreStrategy_pushAssetsToPool_successWhenDeactivated() external {
        _fundStrategy();
        _requestWithdrawalFromStrategy(amountToFund);
        _processAllWithdrawalsByOwnerShares(secondMapleWithdrawalManager, address(coreStrategy));

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), amountToFund);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - amountToFund);
        assertEq(coreStrategy.assetsUnderManagement(),        amountToFund);

        vm.prank(governor);
        coreStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        coreStrategy.pushAssetsToPool();

        assertEq(fundsAsset.balanceOf(address(coreStrategy)), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity);
        assertEq(coreStrategy.assetsUnderManagement(),        0);
    }

}

contract CoreStrategyRemoveSharesIntegrationTests is CoreStrategyTestsBase {

    uint256 sharesToRemove = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(strategyManager);
        coreStrategy.fundStrategy(amountToFund);

        vm.prank(strategyManager);
        coreStrategy.requestWithdrawFromStrategy(amountToFund);
    }

    function testFork_coreStrategy_removeShares_failWhenPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyManager);
        vm.expectRevert("MS:PAUSED");
        coreStrategy.removeShares(sharesToRemove);
    }

    function testFork_coreStrategy_removeShares_failIfNotStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        coreStrategy.removeShares(sharesToRemove);

        vm.prank(strategyManager);
        coreStrategy.removeShares(sharesToRemove);

        vm.prank(poolDelegate);
        coreStrategy.removeShares(sharesToRemove);
    }

    function testFork_coreStrategy_removeShares_failIfZeroShares() external {
        vm.prank(strategyManager);
        vm.expectRevert("MCS:RS:ZERO_SHARES");
        coreStrategy.removeShares(0);
    }

    function testFork_coreStrategy_removeShares_failInsufficientShares() external {
        ( , uint256 sharesBefore) = secondMapleWithdrawalManager.requests(1);

        vm.prank(strategyManager);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
        coreStrategy.removeShares(sharesBefore + 1);
    }

    function testFork_coreStrategy_removeShares_removeAllSharesSuccess() external {
        uint256 strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerBefore, uint256 sharesBefore ) = secondMapleWithdrawalManager.requests(1);

        assertNotEq(sharesBefore,      0);
        assertEq(ownerBefore,          address(coreStrategy));
        assertEq(strategyShareBalance, 0);

        vm.prank(strategyManager);
        coreStrategy.removeShares(sharesBefore);

        strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerAfter, uint256 sharesAfter ) = secondMapleWithdrawalManager.requests(1);

        assertEq(sharesAfter,          0);
        assertEq(ownerAfter,           address(0));
        assertEq(strategyShareBalance, amountToFund);
    }

    function testFork_coreStrategy_removeShares_removePartialSharesSuccess() external {
        uint256 strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerBefore, uint256 sharesBefore ) = secondMapleWithdrawalManager.requests(1);

        assertNotEq(sharesBefore,      0);
        assertEq(ownerBefore,          address(coreStrategy));
        assertEq(strategyShareBalance, 0);

        sharesToRemove = sharesBefore - 1_000_000e6;

        vm.prank(strategyManager);
        coreStrategy.removeShares(sharesToRemove);

        strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerAfter, uint256 sharesAfter ) = secondMapleWithdrawalManager.requests(1);

        assertEq(sharesAfter,          sharesBefore - sharesToRemove);
        assertEq(ownerAfter,           address(coreStrategy));
        assertEq(strategyShareBalance, sharesToRemove);
    }

    function testFork_coreStrategy_removeShares_successWhenImpaired() external {
        uint256 strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerBefore, uint256 sharesBefore ) = secondMapleWithdrawalManager.requests(1);

        assertNotEq(sharesBefore,      0);
        assertEq(ownerBefore,          address(coreStrategy));
        assertEq(strategyShareBalance, 0);

        vm.prank(governor);
        coreStrategy.impairStrategy();

        vm.prank(strategyManager);
        coreStrategy.removeShares(sharesBefore);

        strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerAfter, uint256 sharesAfter ) = secondMapleWithdrawalManager.requests(1);

        assertEq(sharesAfter,          0);
        assertEq(ownerAfter,           address(0));
        assertEq(strategyShareBalance, amountToFund);
    }

    function testFork_coreStrategy_removeShares_successWhenDeactivated() external {
        uint256 strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerBefore, uint256 sharesBefore ) = secondMapleWithdrawalManager.requests(1);

        assertNotEq(sharesBefore,      0);
        assertEq(ownerBefore,          address(coreStrategy));
        assertEq(strategyShareBalance, 0);

        vm.prank(governor);
        coreStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        coreStrategy.removeShares(sharesBefore);

        strategyShareBalance = secondMaplePool.balanceOf(address(coreStrategy));

        ( address ownerAfter, uint256 sharesAfter ) = secondMapleWithdrawalManager.requests(1);

        assertEq(sharesAfter,          0);
        assertEq(ownerAfter,           address(0));
        assertEq(strategyShareBalance, amountToFund);
    }

}

