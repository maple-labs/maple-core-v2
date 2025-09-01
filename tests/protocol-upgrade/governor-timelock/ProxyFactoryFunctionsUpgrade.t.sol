// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMG as IMapleGlobals, IMapleProxyFactory } from "../../../contracts/interfaces/Interfaces.sol";

import { MockGlobals } from "../../mocks/Mocks.sol";

import { GovernorTimelockUpgradeTestsBase } from "./GovernorTimelockUpgradeTestsBase.t.sol";

contract MapleProxyFactoryFunctionsUpgradeTests is GovernorTimelockUpgradeTestsBase {

    address[] public proxyFactories;

    function setUp() public override {
        super.setUp();

        proxyFactories.push(fixedTermLoanFactoryV2);
        proxyFactories.push(fixedTermLoanManagerFactory);
        proxyFactories.push(poolManagerFactory);
        proxyFactories.push(withdrawalManagerCyclicalFactory);
        proxyFactories.push(liquidatorFactory);
        proxyFactories.push(openTermLoanFactory);
        proxyFactories.push(openTermLoanManagerFactory);
        proxyFactories.push(withdrawalManagerQueueFactory);
        proxyFactories.push(aaveStrategyFactory);
        proxyFactories.push(skyStrategyFactory);
        proxyFactories.push(basicStrategyFactory);
    }

    function test_disableUpgradePath() public {
        uint256 fromVersion = 100;
        uint256 toVersion   = 101;

        for (uint256 i = 0; i < proxyFactories.length; i++) {
            address proxyFactory = proxyFactories[i];

            _executeThroughTimelock(
                proxyFactory,
                IMapleProxyFactory.enableUpgradePath.selector,
                abi.encode(fromVersion, toVersion, address(0))
            );

            assertEq(IMapleProxyFactory(proxyFactory).upgradeEnabledForPath(fromVersion, toVersion), true);

            _executeThroughTimelock(
                proxyFactory, IMapleProxyFactory.disableUpgradePath.selector, abi.encode(fromVersion, toVersion)
            );

            assertEq(IMapleProxyFactory(proxyFactory).upgradeEnabledForPath(fromVersion, toVersion), false);
        }
    }

    function test_enabledUpgradePath() public {
        uint256 fromVersion = 100;
        uint256 toVersion   = 101;

        for (uint256 i = 0; i < proxyFactories.length; i++) {
            address proxyFactory = proxyFactories[i];

            assertEq(IMapleProxyFactory(proxyFactory).upgradeEnabledForPath(fromVersion, toVersion), false);

            _executeThroughTimelock(
                proxyFactory,
                IMapleProxyFactory.enableUpgradePath.selector,
                abi.encode(fromVersion, toVersion, address(0))
            );

            assertEq(IMapleProxyFactory(proxyFactory).upgradeEnabledForPath(fromVersion, toVersion), true);
        }
    }


    function test_registerImplementation() public {
        // Implementation can be any contract it is important to have size > 0
        address newImplementation = address(timelock);
        uint256 version           = 12345;

        for (uint256 i = 0; i < proxyFactories.length; i++) {
            address proxyFactory = proxyFactories[i];

            assertEq(IMapleProxyFactory(proxyFactory).versionOf(newImplementation), 0);
            assertEq(IMapleProxyFactory(proxyFactory).implementationOf(version),    address(0));

            _executeThroughTimelock(
                proxyFactory,
                IMapleProxyFactory.registerImplementation.selector,
                abi.encode(version, newImplementation, address(0))
            );

            assertEq(IMapleProxyFactory(proxyFactory).versionOf(newImplementation), version);
            assertEq(IMapleProxyFactory(proxyFactory).implementationOf(version),    newImplementation);
        }
    }

    function test_setDefaultVersion() public {
        // Implementation can be any contract it is important to have size > 0
        address newImplementation = address(timelock);
        uint256 version           = 12345;

        for (uint256 i = 0; i < proxyFactories.length; i++) {
            address proxyFactory = proxyFactories[i];

            _executeThroughTimelock(
                proxyFactory,
                IMapleProxyFactory.registerImplementation.selector,
                abi.encode(version, newImplementation, address(0))
            );

            assertNotEq(IMapleProxyFactory(proxyFactory).defaultVersion(), version);

            _executeThroughTimelock(proxyFactory, IMapleProxyFactory.setDefaultVersion.selector, abi.encode(version));

            assertEq(IMapleProxyFactory(proxyFactory).defaultVersion(), version);
        }
    }

    function test_setGlobals() public {
        address newGlobalsGovernor = makeAddr("newGlobalsGovernor");
        address newGlobals = address(new MockGlobals(newGlobalsGovernor));

        for (uint256 i = 0; i < proxyFactories.length; i++) {
            address proxyFactory = proxyFactories[i];

            address globals_ = IMapleProxyFactory(proxyFactory).mapleGlobals();

            assertEq(globals_, address(globals));

            assertNotEq(globals_,                           newGlobals);
            assertNotEq(IMapleGlobals(globals_).governor(), newGlobalsGovernor);

            _executeThroughTimelock(proxyFactory, IMapleProxyFactory.setGlobals.selector, abi.encode(newGlobals));

            globals_ = IMapleProxyFactory(proxyFactory).mapleGlobals();

            assertEq(globals_,                           newGlobals);
            assertEq(IMapleGlobals(globals_).governor(), newGlobalsGovernor);
        }
    }

}
