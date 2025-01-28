// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    IMapleProxyFactory,
    INonTransparentProxy,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

import { Runner } from "../../contracts/Runner.sol";

contract ProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    IMapleProxyFactory basicStrategyFactory_;
    IMapleProxyFactory aaveStrategyFactory_;
    IMapleProxyFactory skyStrategyFactory_;

    /**************************************************************************************************************************************/
    /*** Upgrade Procedure                                                                                                              ***/
    /**************************************************************************************************************************************/

    function upgradeProtocol() internal {
        setupStrategies();
        setupPoolManagers();
        setupGlobals();
        addStrategies();
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function setupPoolManagers() internal {
        // Deploy the new PoolManager implementation and initializer.
        address poolManagerImplementation = deployFromFile("Contracts@25", "PoolManager");
        address poolManagerInitializer    = deployFromFile("Contracts@25", "PoolManagerInitializer");

        // Register the new version with the factory.
        IMapleProxyFactory poolManagerFactory_ = IMapleProxyFactory(poolManagerFactory);

        vm.startPrank(governor);
        poolManagerFactory_.registerImplementation(400, poolManagerImplementation, poolManagerInitializer);
        poolManagerFactory_.enableUpgradePath(300, 400, address(0));
        poolManagerFactory_.enableUpgradePath(301, 400, address(0));
        poolManagerFactory_.setDefaultVersion(400);
        vm.stopPrank();

        assertEq(poolManagerFactory_.migratorForPath(400, 400), poolManagerInitializer);
        assertEq(poolManagerFactory_.migratorForPath(300, 400), address(0));
        assertEq(poolManagerFactory_.defaultVersion(), 400);

        // Upgrade all pools.
        for (uint256 i; i < poolManagers.length; i++) {
            IPoolManager poolManager = IPoolManager(poolManagers[i]);

            vm.prank(securityAdmin);
            poolManager.upgrade(400, "");

            assertEq(poolManager.implementation(), poolManagerImplementation);
            assertEq(poolManagerFactory_.versionOf(poolManager.implementation()), 400);
        }
    }

    function setupGlobals() internal {
        // Deploy the new MapleGlobals implementation.
        newGlobalsImplementation = deployFromFile("Contracts@25", "Globals");

        // Set the new implementation.
        vm.prank(governor);
        INonTransparentProxy(globals).setImplementation(newGlobalsImplementation);

        IGlobals globals_ = IGlobals(globals);

        // Configure MapleGlobals.
        vm.startPrank(governor);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(fixedTermLoanManagerFactory), true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(openTermLoanManagerFactory),  true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(basicStrategyFactory_),       true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(aaveStrategyFactory_),        true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(skyStrategyFactory_),         true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(aUsdc),                       true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(aUsdt),                       true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(savingsUsds),                 true);
        globals_.setValidInstanceOf("PSM",              address(usdsLitePSM),                 true);
        vm.stopPrank();
    }

    function setupStrategies() internal {
        // Deploy the strategy factories.
        bytes memory data = abi.encode(address(globals));

        basicStrategyFactory_ = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));
        aaveStrategyFactory_  = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));
        skyStrategyFactory_   = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));

        // Deploy strategy implementations and initializers.
        address basicStrategyImplementation = deployFromFile("Contracts@25", "BasicStrategy");
        address aaveStrategyImplementation  = deployFromFile("Contracts@25", "AaveStrategy");
        address skyStrategyImplementation   = deployFromFile("Contracts@25", "SkyStrategy");

        address basicStrategyInitializer = deployFromFile("Contracts@25", "BasicStrategyInitializer");
        address aaveStrategyInitializer  = deployFromFile("Contracts@25", "AaveStrategyInitializer");
        address skyStrategyInitializer   = deployFromFile("Contracts@25", "SkyStrategyInitializer");

        // Configure the strategy factories.
        vm.startPrank(governor);
        basicStrategyFactory_.registerImplementation(100, basicStrategyImplementation, basicStrategyInitializer);
        aaveStrategyFactory_.registerImplementation(100,  aaveStrategyImplementation,  aaveStrategyInitializer);
        skyStrategyFactory_.registerImplementation(100,   skyStrategyImplementation,   skyStrategyInitializer);

        basicStrategyFactory_.setDefaultVersion(100);
        aaveStrategyFactory_.setDefaultVersion(100);
        skyStrategyFactory_.setDefaultVersion(100);
        vm.stopPrank();

        // Assert factory configurations.
        assertEq(basicStrategyFactory_.migratorForPath(100, 100), basicStrategyInitializer);
        assertEq(aaveStrategyFactory_.migratorForPath(100, 100),  aaveStrategyInitializer);
        assertEq(skyStrategyFactory_.migratorForPath(100, 100),   skyStrategyInitializer);

        assertEq(basicStrategyFactory_.defaultVersion(), 100);
        assertEq(aaveStrategyFactory_.defaultVersion(),  100);
        assertEq(skyStrategyFactory_.defaultVersion(),   100);
    }

    function addStrategies() internal {
        // Add all strategies to correct pools.
        vm.startPrank(governor);
        IPoolManager(securedLendingUSDCPoolManager).addStrategy(address(aaveStrategyFactory_), abi.encode(aUsdc));

        IPoolManager(syrupUSDCPoolManager).addStrategy(address(aaveStrategyFactory_), abi.encode(aUsdc));
        IPoolManager(syrupUSDCPoolManager).addStrategy(address(skyStrategyFactory_),  abi.encode(savingsUsds, usdsLitePSM));

        IPoolManager(syrupUSDTPoolManager).addStrategy(address(aaveStrategyFactory_), abi.encode(aUsdt));
        vm.stopPrank();
    }

}
