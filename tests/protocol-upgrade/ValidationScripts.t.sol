// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Test } from "../../contracts/Runner.sol";

import {
    IGlobals,
    IMapleRouter,
    IMapleProxyFactory,
    INonTransparentProxied,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPoolManager,
    IPoolPermissionManager
} from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ValidateMapleRouterSetup is UpgradeAddressRegistry, Test {

    address router0x;
    address router1inch;

    bytes4 selector0x;
    bytes4 selector1inch;

    function run() external {
        assertEq(IMapleRouter(mapleRouterProxy).globals(), globals);
        assertEq(IMapleRouter(mapleRouterProxy).ppm(),     poolPermissionManager);

        assertEq(INonTransparentProxied(mapleRouterProxy).admin(),          operationalAdmin);
        assertEq(INonTransparentProxied(mapleRouterProxy).implementation(), mapleRouterImplementation);

        assertEq(IMapleRouter(mapleRouterProxy).allowedRouterFunctions(router0x,    selector0x),    true);
        assertEq(IMapleRouter(mapleRouterProxy).allowedRouterFunctions(router1inch, selector1inch), true);

        assertEq(IPoolPermissionManager(poolPermissionManager).permissionAdmins(mapleRouterProxy), true);
    }

}

contract ValidateCoreStrategySetup is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(IMapleProxyFactory(poolManagerFactory).defaultVersion(),          401);
        assertEq(IMapleProxyFactory(poolManagerFactory).migratorForPath(400, 401), address(0));
        assertEq(IMapleProxyFactory(poolManagerFactory).migratorForPath(401, 401), poolManagerV401Implementation);
        assertEq(IMapleProxyFactory(poolManagerFactory).implementationOf(401),     poolManagerV401Initializer);

        for (uint256 i; i < poolManagers.length; i++) {
            address implementation = IPoolManager(poolManagers[i]).implementation();

            assertEq(implementation, poolManagerV401Implementation);
            assertEq(IMapleProxyFactory(poolManagerFactory).versionOf(implementation), 401);
        }

        assertEq(IMapleProxyFactory(coreStrategyFactory).defaultVersion(),          100);
        assertEq(IMapleProxyFactory(coreStrategyFactory).migratorForPath(100, 100), coreStrategyV100Implementation);
        assertEq(IMapleProxyFactory(coreStrategyFactory).implementationOf(100),     coreStrategyV100Initializer);

        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_FACTORY", coreStrategyFactory), true);
    }

}

contract ValidateOpenTermLoanSetup is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(IMapleProxyFactory(openTermLoanFactory).defaultVersion(),          202);
        assertEq(IMapleProxyFactory(openTermLoanFactory).implementationOf(202),     openTermLoanV202Implementation);
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(202, 202), openTermLoanV202Initializer);
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(101, 202), openTermLoanV202Migrator);
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(201, 202), address(0));
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(200, 202), address(0));

        for (uint256 i; i < allOpenTermLoans.length; i++) {
            address implementation = IOpenTermLoan(allOpenTermLoans[i]).implementation();

            assertEq(implementation, openTermLoanV202Implementation);
            assertEq(IMapleProxyFactory(openTermLoanFactory).versionOf(implementation), 202);
            assertEq(IOpenTermLoan(allOpenTermLoans[i]).loanTermsAccepted(), true);
        }

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).defaultVersion(),          101);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).implementationOf(101),     openTermLoanManagerV101Implementation);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).migratorForPath(101, 101), openTermLoanManagerV101Initializer);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).migratorForPath(100, 101), address(0));

        for (uint256 i; i < openTermLoanManagers.length; i++) {
            address implementation = IOpenTermLoanManager(openTermLoanManagers[i]).implementation();

            assertEq(implementation, openTermLoanManagerV101Implementation);
            assertEq(IMapleProxyFactory(openTermLoanManagerFactory).versionOf(implementation), 101);
        }
    }
}
