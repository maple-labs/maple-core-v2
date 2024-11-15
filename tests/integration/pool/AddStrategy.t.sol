// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 } from "../../../modules/forge-std/src/console2.sol";

import { IMapleProxyFactory, IMockERC20, IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract AddStrategyTests is TestBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _setTreasury();
        _createFactories();

        // Create a pool with no strategies.
        poolManager = IPoolManager(deployPoolWithQueue({
            poolDelegate_:           address(poolDelegate),
            deployer_:               address(deployer),
            poolManagerFactory_:     address(poolManagerFactory),
            queueWMFactory_:         address(queueWMFactory),
            strategyFactories_:      new address[](0),
            strategyDeploymentData_: new bytes[](0),
            fundsAsset_:             address(fundsAsset),
            poolPermissionManager_:  address(poolPermissionManager),
            name_:                   "Pool",
            symbol_:                 "MP",
            configParams_:           [type(uint256).max, 0, 0, 0]
        }));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        vm.stopPrank();
    }

    function test_addStrategy_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategy(openTermLoanManagerFactory, new bytes(0));
    }

    function test_addStrategy_notAuthorized() external {
        vm.expectRevert("PM:NOT_PA_OR_NOT_CONFIGURED");
        poolManager.addStrategy(openTermLoanManagerFactory, new bytes(0));
    }

    function test_addStrategy_invalidFactory() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:AS:INVALID_FACTORY");
        poolManager.addStrategy(address(1), new bytes(0));
    }

    function test_addStrategy_invalidStrategy() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolManager.addStrategy(aaveStrategyFactory, abi.encode(address(AAVE_USDC)));
    }

    function test_addStrategy_invalidAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolManager.addStrategy(basicStrategyFactory, abi.encode(address(SAVINGS_USDS)));
    }

    function test_addStrategy_noExtraArguments_withPoolDelegate() external {
        assertEq(poolManager.strategyListLength(), 0);

        vm.prank(poolDelegate);
        poolManager.addStrategy(openTermLoanManagerFactory, new bytes(0));

        assertEq(poolManager.strategyListLength(), 1);

        address strategy = poolManager.strategyList(0);

        assertEq(poolManager.isStrategy(strategy),                                    true);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(strategy), true);
    }

    function test_addStrategy_withExtraArguments_withOperationalAdmin() external {
        assertEq(poolManager.strategyListLength(), 0);

        vm.prank(operationalAdmin);
        poolManager.addStrategy(aaveStrategyFactory, abi.encode(AAVE_USDC));

        assertEq(poolManager.strategyListLength(), 1);

        address strategy = poolManager.strategyList(0);

        assertEq(poolManager.isStrategy(strategy),                             true);
        assertEq(IMapleProxyFactory(aaveStrategyFactory).isInstance(strategy), true);
    }

    function test_addStrategy_withExtraArguments_withGovernor() external {
        assertEq(poolManager.strategyListLength(), 0);

        vm.prank(governor);
        poolManager.addStrategy(skyStrategyFactory, abi.encode(SAVINGS_USDS, USDS_LITE_PSM));

        assertEq(poolManager.strategyListLength(), 1);

        address strategy = poolManager.strategyList(0);

        assertEq(poolManager.isStrategy(strategy),                            true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(strategy), true);
    }

    function test_addStrategy_multipleStrategies() external {
        // Add a open term loan manager
        assertEq(poolManager.strategyListLength(), 0);

        vm.prank(poolDelegate);
        poolManager.addStrategy(openTermLoanManagerFactory, new bytes(0));

        assertEq(poolManager.strategyListLength(), 1);

        address lmStrategy = poolManager.strategyList(0);

        assertEq(poolManager.isStrategy(lmStrategy),                                    true);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(lmStrategy), true);

        // Add an Aave strategy
        vm.prank(operationalAdmin);
        poolManager.addStrategy(aaveStrategyFactory, abi.encode(AAVE_USDC));

        assertEq(poolManager.strategyListLength(), 2);

        address aaveStrategy = poolManager.strategyList(1);

        assertEq(poolManager.isStrategy(aaveStrategy),                             true);
        assertEq(IMapleProxyFactory(aaveStrategyFactory).isInstance(aaveStrategy), true);

        // Add a sky strategy
        vm.prank(governor);
        poolManager.addStrategy(skyStrategyFactory, abi.encode(SAVINGS_USDS, USDS_LITE_PSM));

        assertEq(poolManager.strategyListLength(), 3);

        address skyStrategy = poolManager.strategyList(2);

        assertEq(poolManager.isStrategy(skyStrategy),                            true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyStrategy), true);

        // Add a Fixed term loan manager
        vm.prank(poolDelegate);
        poolManager.addStrategy(fixedTermLoanManagerFactory, new bytes(0));

        assertEq(poolManager.strategyListLength(), 4);

        address ftmStrategy = poolManager.strategyList(3);

        assertEq(poolManager.isStrategy(ftmStrategy),                                     true);
        assertEq(IMapleProxyFactory(fixedTermLoanManagerFactory).isInstance(ftmStrategy), true);
    }

}
