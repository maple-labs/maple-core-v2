// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import {
    IGlobals,
    IMapleProxyFactory,
    INonTransparentProxy,
    IPool,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

import { Runner } from "../../contracts/Runner.sol";

contract StrategyTestBase is Runner, AddressRegistry {

    address syrupUSDCPoolDelegate;

    uint256 start;

    IPool        syrupUsdcPool;
    IPoolManager syrupUsdcPoolManager;

    IMapleProxyFactory basicStrategyFactory;
    IMapleProxyFactory aaveStrategyFactory;
    IMapleProxyFactory skyStrategyFactory;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21185932);

        syrupUsdcPool         = IPool(syrupUSDCPool);                // NOTE: Address registry address is uppercase USDC
        syrupUsdcPoolManager  = IPoolManager(syrupUSDCPoolManager);  // NOTE: Address registry address is uppercase USDC
        syrupUSDCPoolDelegate = syrupUsdcPoolManager.poolDelegate();

        setupStrategies();
        setupPoolManager();
        setupGlobals();

        start  = block.timestamp;
    }

    function setupPoolManager() internal {
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
        assertEq(poolManagerFactory_.migratorForPath(301, 400), address(0));

        assertEq(poolManagerFactory_.defaultVersion(), 400);

        // Upgrade the PoolManager.
        vm.prank(securityAdmin);
        syrupUsdcPoolManager.upgrade(400, "");

        assertEq(syrupUsdcPoolManager.implementation(), poolManagerImplementation);

        assertEq(poolManagerFactory_.versionOf(syrupUsdcPoolManager.implementation()), 400);
    }

    function setupGlobals() internal {
        // Deploy the new MapleGlobals implementation.
        address newGlobalsImplementation = deployFromFile("Contracts@25", "Globals");

        // Set the new implementation.
        vm.prank(governor);
        INonTransparentProxy(globals).setImplementation(newGlobalsImplementation);

        IGlobals globals_ = IGlobals(globals);

        // Configure MapleGlobals.
        vm.startPrank(governor);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(basicStrategyFactory), true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(aaveStrategyFactory),  true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(skyStrategyFactory),   true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(aUsdc),                true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(savingsUsds),          true);
        globals_.setValidInstanceOf("PSM",              address(usdsLitePSM),          true);
        vm.stopPrank();
    }

    function setupStrategies() internal {
        // Deploy the strategy factories.
        bytes memory data = abi.encode(address(globals));

        basicStrategyFactory = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));
        aaveStrategyFactory  = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));
        skyStrategyFactory   = IMapleProxyFactory(deployFromFile("Contracts@25", "StrategyFactory", data));

        // Deploy strategy implementations and initializers.
        address basicStrategyImplementation = deployFromFile("Contracts@25", "BasicStrategy");
        address aaveStrategyImplementation  = deployFromFile("Contracts@25", "AaveStrategy");
        address skyStrategyImplementation   = deployFromFile("Contracts@25", "SkyStrategy");

        address basicStrategyInitializer = deployFromFile("Contracts@25", "BasicStrategyInitializer");
        address aaveStrategyInitializer  = deployFromFile("Contracts@25", "AaveStrategyInitializer");
        address skyStrategyInitializer   = deployFromFile("Contracts@25", "SkyStrategyInitializer");

        // Configure the strategy factories.
        vm.startPrank(governor);
        basicStrategyFactory.registerImplementation(100, basicStrategyImplementation, basicStrategyInitializer);
        aaveStrategyFactory.registerImplementation(100,  aaveStrategyImplementation,  aaveStrategyInitializer);
        skyStrategyFactory.registerImplementation(100,   skyStrategyImplementation,   skyStrategyInitializer);

        basicStrategyFactory.setDefaultVersion(100);
        aaveStrategyFactory.setDefaultVersion(100);
        skyStrategyFactory.setDefaultVersion(100);
        vm.stopPrank();

        // Assert factory configurations.
        assertEq(basicStrategyFactory.migratorForPath(100, 100), basicStrategyInitializer);
        assertEq(aaveStrategyFactory.migratorForPath(100, 100),  aaveStrategyInitializer);
        assertEq(skyStrategyFactory.migratorForPath(100, 100),   skyStrategyInitializer);

        assertEq(basicStrategyFactory.defaultVersion(), 100);
        assertEq(aaveStrategyFactory.defaultVersion(),  100);
        assertEq(skyStrategyFactory.defaultVersion(),   100);
    }

}
