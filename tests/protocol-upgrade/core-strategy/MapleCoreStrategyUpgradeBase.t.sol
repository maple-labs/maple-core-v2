// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IGlobals,
    IPoolManager,
    IMapleProxyFactory,
    IPoolPermissionManager,
    IStrategy,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";
import { Runner }          from "../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract MapleCoreStrategyUpgradeBaseTest is Runner, UpgradeAddressRegistry, ProtocolActions {

    address strategy;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23211261);

        _deployCoreStrategyFactory();
        _upgradeWithdrawalManagers();
        _addStrategyToSyrupUSDCPool();
    }

    function test_setUp() public view {
        assertEq(IPoolManager(syrupUSDCPoolManager).strategyListLength(), 5);
        assertEq(IPoolManager(syrupUSDCPoolManager).strategyList(4),      strategy);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategy(strategy), true);

        assertEq(IStrategy(strategy).assetsUnderManagement(), 0);

        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_VAULT",   highYieldCorpUSDCPool),    true);
        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_FACTORY", mapleCoreStrategyFactory), true);

        assertEq(IMapleProxyFactory(mapleCoreStrategyFactory).defaultVersion(),                               100);
        assertEq(IMapleProxyFactory(mapleCoreStrategyFactory).versionOf(mapleCoreStrategyV100Implementation), 100);
        assertEq(IMapleProxyFactory(mapleCoreStrategyFactory).isInstance(strategy),                           true);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(),                                    200);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(mapleWithdrawalManagerV200Implementation), 200);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).isInstance(highYieldCorpUSDCWithdrawalManagerQueue), true);
    }

    function _addStrategyToSyrupUSDCPool() internal {
        vm.startPrank(operationalAdmin);

        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", highYieldCorpUSDCPool, true);

        strategy = IPoolManager(syrupUSDCPoolManager).addStrategy(
            mapleCoreStrategyFactory,
            abi.encode(highYieldCorpUSDCPool)
        );

        address[] memory lenders = new address[](1);
        lenders[0]               = strategy;

        bool[] memory allowed = new bool[](1);
        allowed[0]            = true;

        IPoolPermissionManager(poolPermissionManager).setLenderAllowlist(highYieldCorpUSDCPoolManager, lenders, allowed);

        vm.stopPrank();
    }

    function _deployCoreStrategyFactory() internal {
        mapleCoreStrategyFactory            = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(globals));
        mapleCoreStrategyV100Implementation = deployFromFile("Contracts@25", "CoreStrategy");
        mapleCoreStrategyV100Initializer    = deployFromFile("Contracts@25", "CoreStrategyInitializer");

        vm.startPrank(governor);

        IMapleProxyFactory(mapleCoreStrategyFactory).registerImplementation(
            100,
            mapleCoreStrategyV100Implementation,
            mapleCoreStrategyV100Initializer
        );

        IMapleProxyFactory(mapleCoreStrategyFactory).setDefaultVersion(100);

        IGlobals(globals).setValidInstanceOf("STRATEGY_FACTORY", mapleCoreStrategyFactory, true);

        vm.stopPrank();
    }


    function _upgradeWithdrawalManagers() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");

        vm.startPrank(governor);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );
        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);

        vm.stopPrank();

        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManagerQueuesToUpgrade[i]);

            vm.prank(securityAdmin);
            wm.upgrade(200, "");

            assertEq(wm.implementation(), mapleWithdrawalManagerV200Implementation);

            assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(wm.implementation()), 200);
        }
    }

}
