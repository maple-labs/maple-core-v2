// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { NonTransparentProxy } from "../modules/globals/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MapleLoanFactory as FixedTermLoanFactory }           from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoan as FixedTermLoanImplementationV502 }       from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanV502Migrator as FixedTermLoanV502Migrator } from "../modules/fixed-term-loan/contracts/MapleLoanV502Migrator.sol";

import { MapleGlobals as Globals } from "../modules/globals/contracts/MapleGlobals.sol";

import { MaplePoolManager as PoolManager }                       from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolDeployer as PoolDeployer }                     from "../modules/pool/contracts/MaplePoolDeployer.sol";
import { MaplePoolManagerInitializer as PoolManagerInitializer } from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolManagerMigrator as PoolManagerMigrator }       from "../modules/pool/contracts/proxy/MaplePoolManagerMigrator.sol";
import { MaplePoolManagerWMMigrator as PoolManagerWMMigrator }   from "../modules/pool/contracts/proxy/MaplePoolManagerWMMigrator.sol";

import { MaplePoolPermissionManager as PoolPermissionManager }
    from "../modules/pool-permission-manager/contracts/MaplePoolPermissionManager.sol";
import { MaplePoolPermissionManagerInitializer as PoolPermissionManagerInitializer }
    from "../modules/pool-permission-manager/contracts/proxy/MaplePoolPermissionManagerInitializer.sol";

import { MapleWithdrawalManager as WithdrawalManagerCyclical }
    from "../modules/withdrawal-manager-cyclical/contracts/MapleWithdrawalManager.sol";
import { MapleWithdrawalManagerInitializer as WithdrawalManagerCyclicalInitializer }
    from "../modules/withdrawal-manager-cyclical/contracts/MapleWithdrawalManagerInitializer.sol";

import { MapleWithdrawalManagerFactory as WithdrawalManagerQueueFactory }
    from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerFactory.sol";
import { MapleWithdrawalManagerInitializer as WithdrawalManagerQueueInitializer }
    from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerInitializer.sol";
import { MapleWithdrawalManager as WithdrawalManagerQueue }
    from "../modules/withdrawal-manager-queue/contracts/MapleWithdrawalManager.sol";

import { MapleAddressRegistry }       from "../modules/address-registry/contracts/MapleAddressRegistry.sol";
import { MapleAddressRegistryBaseL2 } from "../modules/address-registry/contracts/MapleAddressRegistryBase.sol";


import { IProxyFactoryLike } from "../contracts/interfaces/Interfaces.sol";

// TODO: Refactor to have address registry be agnostic of chain and setup addresses per chain to de-dup.
contract DeployQ4UpdateETH is MapleAddressRegistry, Script {

    function run() external {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        address fixedTermLoanFactoryV2          = address(new FixedTermLoanFactory(globals, fixedTermLoanFactory));
        address fixedTermLoanImplementationV502 = address(new FixedTermLoanImplementationV502());
        address fixedTermLoanInitializerV500    = address(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501));
        address fixedTermLoanV502Migrator       = address(new FixedTermLoanV502Migrator());

        console.log("Fixed Term Loan");
        console.log("   factoryV2:         ", fixedTermLoanFactoryV2);
        console.log("   implementationV502:", fixedTermLoanImplementationV502);
        console.log("   initializerV500:   ", fixedTermLoanInitializerV500);
        console.log("   migratorV502:      ", fixedTermLoanV502Migrator);

        address globalsImplementationV3 = address(new Globals());

        console.log("Globals");
        console.log("   implementationV3:", globalsImplementationV3);

        address poolDeployerV3 = address(new PoolDeployer(globals));

        console.log("Pool Deployer");
        console.log("   deployerV3:", poolDeployerV3);

        address poolManagerImplementationV300 = address(new PoolManager());
        address poolManagerImplementationV301 = address(new PoolManager());
        address poolManagerInitializer        = address(new PoolManagerInitializer());
        address poolManagerMigrator           = address(new PoolManagerMigrator());
        address poolManagerWMMigrator         = address(new PoolManagerWMMigrator());

        console.log("Pool Manager");
        console.log("   implementationV300:", poolManagerImplementationV300);
        console.log("   implementationV301:", poolManagerImplementationV301);
        console.log("   initializer:       ", poolManagerInitializer);
        console.log("   migrator:          ", poolManagerMigrator);
        console.log("   wmMigrator:        ", poolManagerWMMigrator);

        address poolPermissionManagerImplementation = address(new PoolPermissionManager());
        address poolPermissionManagerInitializer    = address(new PoolPermissionManagerInitializer());
        address poolPermissionManager               = address(new NonTransparentProxy(governor, poolPermissionManagerInitializer));

        console.log("Pool Permission Manager");
        console.log("   implementation:", poolPermissionManagerImplementation);
        console.log("   initializer:   ", poolPermissionManagerInitializer);
        console.log("   ppmProxy:      ", poolPermissionManager);

        address cyclicalWMImplementation = address(new WithdrawalManagerCyclical());
        address cyclicalWMInitializer    = address(new WithdrawalManagerCyclicalInitializer());

        console.log("Cyclical Withdrawal Manager");
        console.log("   implementation:", cyclicalWMImplementation);
        console.log("   initializer:   ", cyclicalWMInitializer);

        address queueWMFactory        = address(new WithdrawalManagerQueueFactory(globals));
        address queueWMImplementation = address(new WithdrawalManagerQueue());
        address queueWMInitializer    = address(new WithdrawalManagerQueueInitializer());

        console.log("Queue Withdrawal Manager");
        console.log("   factory:       ", queueWMFactory);
        console.log("   implementation:", queueWMImplementation);
        console.log("   initializer:   ", queueWMInitializer);

        vm.stopBroadcast();
    }

}

contract DeployQ4UpdateBASEL2 is MapleAddressRegistryBaseL2, Script {

    function run() external {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        address fixedTermLoanFactoryV2          = address(new FixedTermLoanFactory(globals, fixedTermLoanFactory));
        address fixedTermLoanImplementationV502 = address(new FixedTermLoanImplementationV502());
        address fixedTermLoanInitializerV500    = address(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501));
        address fixedTermLoanV502Migrator       = address(new FixedTermLoanV502Migrator());

        console.log("Fixed Term Loan");
        console.log("   factoryV2:          ", fixedTermLoanFactoryV2);
        console.log("   implementationV502: ", fixedTermLoanImplementationV502);
        console.log("   initializerV500:    ", fixedTermLoanInitializerV500);
        console.log("   migratorV502:       ", fixedTermLoanV502Migrator);

        address globalsImplementationV3 = address(new Globals());

        console.log("Globals");
        console.log("   implementationV3: ", globalsImplementationV3);

        address poolDeployerV3 = address(new PoolDeployer(globals));

        console.log("Pool Deployer");
        console.log("   deployerV3: ", poolDeployerV3);

        address poolManagerImplementationV300 = address(new PoolManager());
        address poolManagerImplementationV301 = address(new PoolManager());
        address poolManagerInitializer        = address(new PoolManagerInitializer());
        address poolManagerMigrator           = address(new PoolManagerMigrator());
        address poolManagerWMMigrator         = address(new PoolManagerWMMigrator());

        console.log("Pool Manager");
        console.log("   implementationV300: ", poolManagerImplementationV300);
        console.log("   implementationV301: ", poolManagerImplementationV301);
        console.log("   initializer:        ", poolManagerInitializer);
        console.log("   migrator:           ", poolManagerMigrator);
        console.log("   wmMigrator:         ", poolManagerWMMigrator);

        address poolPermissionManagerImplementation = address(new PoolPermissionManager());
        address poolPermissionManagerInitializer    = address(new PoolPermissionManagerInitializer());
        address poolPermissionManager               = address(new NonTransparentProxy(governor, poolPermissionManagerInitializer));

        console.log("Pool Permission Manager");
        console.log("   implementation: ", poolPermissionManagerImplementation);
        console.log("   initializer:    ", poolPermissionManagerInitializer);
        console.log("   ppmProxy:       ", poolPermissionManager);

        address cyclicalWMImplementation = address(new WithdrawalManagerCyclical());
        address cyclicalWMInitializer    = address(new WithdrawalManagerCyclicalInitializer());

        console.log("Cyclical Withdrawal Manager");
        console.log("   implementation: ", cyclicalWMImplementation);
        console.log("   initializer:    ", cyclicalWMInitializer);

        address queueWMFactory        = address(new WithdrawalManagerQueueFactory(globals));
        address queueWMImplementation = address(new WithdrawalManagerQueue());
        address queueWMInitializer    = address(new WithdrawalManagerQueueInitializer());

        console.log("Queue Withdrawal Manager");
        console.log("   factory:        ", queueWMFactory);
        console.log("   implementation: ", queueWMImplementation);
        console.log("   initializer:    ", queueWMInitializer);

        vm.stopBroadcast();
    }

}
