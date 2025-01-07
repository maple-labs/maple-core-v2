// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Test } from "../../contracts/Runner.sol";

import { IGlobals, IMapleProxied, IMapleProxyFactory, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ValidateGlobalsUpgrade is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(IMapleProxied(address(globals)).implementation(), newGlobalsImplementation);
    }

}

// TODO: Let's also assert there is no migrator set for the upgrade paths for the PM
contract ValidateStrategiesFactoriesSetup is UpgradeAddressRegistry, Test {

    function run() external {
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
    }

    function validateFactory(address factory, uint256 version, address implementation, address initializer) internal {
        IMapleProxyFactory factoryContract = IMapleProxyFactory(factory);

        assertEq(factoryContract.defaultVersion(),                  version);
        assertEq(factoryContract.migratorForPath(version, version), initializer);
        assertEq(factoryContract.implementationOf(version),         implementation);
    }

}

contract ValidateStrategiesGlobalsSetup is UpgradeAddressRegistry, Test {

    function run() external {
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

}

// TODO: Needs all pools we are upgrading added
contract ValidateStrategiesPoolManagerUpgrade is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(IMapleProxyFactory(poolManagerFactory).versionOf(IMapleProxied(syrupUSDCPoolManager).implementation()),          400);
        assertEq(IMapleProxyFactory(poolManagerFactory).versionOf(IMapleProxied(syrupUSDTPoolManager).implementation()),          400);
        assertEq(IMapleProxyFactory(poolManagerFactory).versionOf(IMapleProxied(securedLendingUSDCPoolManager).implementation()), 400);
    }

}

// TODO: The length isn't sufficient we should assert the address of the instance is in the array
contract ValidateStrategyAddition is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(IPoolManager(syrupUSDCPoolManager).strategyListLength(),          4);  // Both LMs + Aave and Sky
        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyListLength(), 3);  // Both LMs + Aave
        assertEq(IPoolManager(syrupUSDTPoolManager).strategyListLength(),          3);  // Both LMs + Aave
    }

}

contract ValidateLoanFactoriesSetup is UpgradeAddressRegistry, Test {

    function run() external {
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

    function validateFactory(address factory, uint256 version, address implementation, address initializer) internal {
        IMapleProxyFactory factoryContract = IMapleProxyFactory(factory);

        assertEq(factoryContract.defaultVersion(),                  version);
        assertEq(factoryContract.migratorForPath(version, version), initializer);
        assertEq(factoryContract.implementationOf(version),         implementation);
    }

}
