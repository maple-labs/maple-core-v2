// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Test } from "../../contracts/Runner.sol";

import { IGlobals, IMapleProxied, IMapleProxyFactory, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ValidateStrategiesGlobalsAndFactoriesSetup is UpgradeAddressRegistry, Test {

    function run() external {
        validateFactoriesSetup();
        validateGlobalsUpgrade();
        validateGlobalsSetup();
    }

    function validateFactoriesSetup() internal {
        validateFactory({
            factory:        basicStrategyFactory,
            version:        100,
            implementation: newBasicStrategyImplementation,
            initializer:    newBasicStrategyInitializer
        });

        validateFactory({
            factory:        aaveStrategyFactory,
            version:        100,
            implementation: newAaveStrategyImplementation,
            initializer:    newAaveStrategyInitializer
        });

        validateFactory({
            factory:        skyStrategyFactory,
            version:        100,
            implementation: newSkyStrategyImplementation,
            initializer:    newSkyStrategyInitializer
        });

        validateFactory({
            factory:        poolManagerFactory,
            version:        400,
            implementation: newPoolManagerImplementation,
            initializer:    newPoolManagerInitializer
        });

        assertTrue(IMapleProxyFactory(poolManagerFactory).upgradeEnabledForPath(300, 400));
        assertTrue(IMapleProxyFactory(poolManagerFactory).upgradeEnabledForPath(301, 400));

        assertEq(IMapleProxyFactory(poolManagerFactory).migratorForPath(300, 400), address(0));
        assertEq(IMapleProxyFactory(poolManagerFactory).migratorForPath(301, 400), address(0));
    }

    function validateGlobalsUpgrade() internal {
        assertEq(IMapleProxied(address(globals)).implementation(), newGlobalsImplementation);
    }

    function validateGlobalsSetup() internal {
        IGlobals globals_ = IGlobals(globals);

        assertTrue(globals_.isInstanceOf("STRATEGY_FACTORY", fixedTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("STRATEGY_FACTORY", aaveStrategyFactory));
        assertTrue(globals_.isInstanceOf("STRATEGY_FACTORY", basicStrategyFactory));
        assertTrue(globals_.isInstanceOf("STRATEGY_FACTORY", skyStrategyFactory));

        assertTrue(globals_.isInstanceOf("STRATEGY_VAULT", aUsdc));
        assertTrue(globals_.isInstanceOf("STRATEGY_VAULT", aUsdt));
        assertTrue(globals_.isInstanceOf("STRATEGY_VAULT", savingsUsds));
        assertTrue(globals_.isInstanceOf("PSM",            usdsLitePSM));
    }

    function validateFactory(address factory, uint256 version, address implementation, address initializer) internal {
        IMapleProxyFactory factoryContract = IMapleProxyFactory(factory);

        assertEq(factoryContract.defaultVersion(),                  version);
        assertEq(factoryContract.migratorForPath(version, version), initializer);
        assertEq(factoryContract.implementationOf(version),         implementation);
    }

}

contract ValidateStrategiesPoolManagerUpgrade is UpgradeAddressRegistry, Test {

    function run() external {

        for (uint256 i = 0; i < poolManagers.length; i++) {
            assertEq(IMapleProxyFactory(poolManagerFactory).versionOf(IMapleProxied(poolManagers[i]).implementation()), 400);
        }
    }

}

contract ValidateStrategyAddition is UpgradeAddressRegistry, Test {

    function run() external {

        // Assert SyrupUSDC
        assertTrue(IPoolManager(syrupUSDCPoolManager).isStrategy(syrupUSDCAaveStrategy));
        assertTrue(IPoolManager(syrupUSDCPoolManager).isStrategy(syrupUSDCSkyStrategy));

        assertEq(IPoolManager(syrupUSDCPoolManager).strategyListLength(), 4);
        assertEq(IPoolManager(syrupUSDCPoolManager).strategyList(2),      syrupUSDCAaveStrategy);
        assertEq(IPoolManager(syrupUSDCPoolManager).strategyList(3),      syrupUSDCSkyStrategy);

        validateIsInstance(aaveStrategyFactory, syrupUSDCAaveStrategy);
        validateIsInstance(skyStrategyFactory,  syrupUSDCSkyStrategy);

        // Assert SyrupUSDT
        assertTrue(IPoolManager(syrupUSDTPoolManager).isStrategy(syrupUSDTAaveStrategy));

        assertEq(IPoolManager(syrupUSDTPoolManager).strategyListLength(), 3);
        assertEq(IPoolManager(syrupUSDTPoolManager).strategyList(2),      syrupUSDTAaveStrategy);

        validateIsInstance(aaveStrategyFactory, syrupUSDTAaveStrategy);

        // Assert SecuredLendingUSDC
        assertTrue(IPoolManager(securedLendingUSDCPoolManager).isStrategy(securedLendingAaveStrategy));

        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyListLength(), 3);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyList(2),      securedLendingAaveStrategy);

        validateIsInstance(aaveStrategyFactory, securedLendingAaveStrategy);
    }

    function validateIsInstance(address factory, address strategy) internal {
        assertTrue(IMapleProxyFactory(factory).isInstance(strategy));
    }

}

contract ValidateDILSetup is UpgradeAddressRegistry, Test {

    function run() external {

        for (uint256 i = 0; i < poolDelegates.length; i++) {
            assertCanDeployFrom(poolDelegates[i]);
        }

        validateFactory({
            factory:        fixedTermLoanFactoryV2,
            version:        600,
            implementation: newFixedTermLoanImplementation,
            initializer:    newFixedTermLoanInitializer
        });

        validateFactory({
            factory:        openTermLoanFactory,
            version:        200,
            implementation: newOpenTermLoanImplementation,
            initializer:    newOpenTermLoanInitializer
        });
    }

    function assertCanDeployFrom(address delegate) internal {
        assertTrue(IGlobals(globals).canDeployFrom(fixedTermLoanFactoryV2, delegate));
        assertTrue(IGlobals(globals).canDeployFrom(openTermLoanFactory,    delegate));
    }

    function validateFactory(address factory, uint256 version, address implementation, address initializer) internal {
        IMapleProxyFactory factoryContract = IMapleProxyFactory(factory);

        assertEq(factoryContract.defaultVersion(),                  version);
        assertEq(factoryContract.migratorForPath(version, version), initializer);
        assertEq(factoryContract.implementationOf(version),         implementation);
    }

}
