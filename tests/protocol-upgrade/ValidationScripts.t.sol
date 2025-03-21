// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Test } from "../../contracts/Runner.sol";

import {
    IGlobals,
    IMapleProxied,
    IMapleProxyFactory,
    INonTransparentProxied,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

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

        assertTrue(IGlobals(globals).canDeployFrom(poolManagerFactory,               newPoolDeployer));
        assertTrue(IGlobals(globals).canDeployFrom(withdrawalManagerCyclicalFactory, newPoolDeployer));
        assertTrue(IGlobals(globals).canDeployFrom(withdrawalManagerQueueFactory,    newPoolDeployer));
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
        assertTrue(IPoolManager(securedLendingUSDCPoolManager).isStrategy(securedLendingSkyStrategy));

        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyListLength(), 4);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyList(2),      securedLendingAaveStrategy);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyList(3),      securedLendingSkyStrategy);

        validateIsInstance(aaveStrategyFactory, securedLendingAaveStrategy);
        validateIsInstance(skyStrategyFactory,  securedLendingSkyStrategy);

        // Assert LendAndLongUSDC1
        assertTrue(IPoolManager(LendAndLongUSDC1PoolManager).isStrategy(LendAndLongUSDC1AaveStrategy));
        assertTrue(IPoolManager(LendAndLongUSDC1PoolManager).isStrategy(LendAndLongUSDC1SkyStrategy));

        assertEq(IPoolManager(LendAndLongUSDC1PoolManager).strategyListLength(), 4);
        assertEq(IPoolManager(LendAndLongUSDC1PoolManager).strategyList(2),      LendAndLongUSDC1AaveStrategy);
        assertEq(IPoolManager(LendAndLongUSDC1PoolManager).strategyList(3),      LendAndLongUSDC1SkyStrategy);

        validateIsInstance(aaveStrategyFactory, LendAndLongUSDC1AaveStrategy);
        validateIsInstance(skyStrategyFactory,  LendAndLongUSDC1SkyStrategy);

        // Assert LendAndLongUSDC2
        assertTrue(IPoolManager(LendAndLongUSDC2PoolManager).isStrategy(LendAndLongUSDC2AaveStrategy));
        assertTrue(IPoolManager(LendAndLongUSDC2PoolManager).isStrategy(LendAndLongUSDC2SkyStrategy));

        assertEq(IPoolManager(LendAndLongUSDC2PoolManager).strategyListLength(), 4);
        assertEq(IPoolManager(LendAndLongUSDC2PoolManager).strategyList(2),      LendAndLongUSDC2AaveStrategy);
        assertEq(IPoolManager(LendAndLongUSDC2PoolManager).strategyList(3),      LendAndLongUSDC2SkyStrategy);

        validateIsInstance(aaveStrategyFactory, LendAndLongUSDC2AaveStrategy);
        validateIsInstance(skyStrategyFactory,  LendAndLongUSDC2SkyStrategy);
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
            version:        601,
            implementation: newFixedTermLoanImplementation,
            initializer:    newFixedTermLoanInitializer
        });

        validateFactory({
            factory:        openTermLoanFactory,
            version:        201,
            implementation: newOpenTermLoanImplementation,
            initializer:    newOpenTermLoanInitializer
        });

        assertTrue(IGlobals(globals).isInstanceOf("BORROWER_ACTIONS", borrowerActionsProxy));
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

contract ValidateBorrowerActions is UpgradeAddressRegistry, Test {

    function run() external {
        assertEq(INonTransparentProxied(borrowerActionsProxy).implementation(), borrowerActionsImplementation);
        assertEq(INonTransparentProxied(borrowerActionsProxy).admin(),          securityAdmin);
    }

}
