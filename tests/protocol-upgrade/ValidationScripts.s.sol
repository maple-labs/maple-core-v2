// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxiedLike, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { console2, Test } from "../../contracts/Contracts.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

contract ValidationBase is AddressRegistry, Test {

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

}

contract ValidateUpgradeMapleGlobals is ValidationBase {

    // TODO: Replace this with the address of the new MapleGlobals implementation.
    address constant newImplementation = address(0);

    // TODO: Replace this with the code hash of the new MapleGlobals implementation.
    bytes32 constant expectedCodeHash = bytes32(0);

    function run() external view {
        bytes32 computedCodeHash = keccak256(abi.encode(newImplementation.code));

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedCodeHash));

        require(computedCodeHash == expectedCodeHash, "implementation code hash does not match");

        address implementation = IProxiedLike(mapleGlobalsV2Proxy).implementation();

        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newImplementation);

        require(implementation == newImplementation, "implementation address does not match");
    }

}

contract ValidateUpgradeFixedTermLoans is ValidationBase {

    // TODO: Replace this with the address of the new FTL implementation.
    address constant newImplementation = address(0);

    // TODO: Replace this with the code hash of the new FTL implementation.
    bytes32 constant expectedCodeHash = bytes32(0);

    function run() external view {
        validateCodeHash();

        validateLoans(mavenPermissionedLoans);
        validateLoans(mavenUsdcLoans);
        validateLoans(mavenWethLoans);
        validateLoans(orthogonalLoans);
        validateLoans(icebreakerLoans);
        validateLoans(aqruLoans);
        validateLoans(mavenUsdc3Loans);
        validateLoans(cashMgmtLoans);
    }

    function validateCodeHash() internal view {
        bytes32 computedCodeHash = keccak256(abi.encode(newImplementation.code));

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedCodeHash));

        require(computedCodeHash == expectedCodeHash, "code hash does not match");
    }

    function validateLoans(address[] memory loans) internal view {
        for (uint256 i; i < loans.length; i++) {
            validateLoan(loans[i]);
        }
    }

    function validateLoan(address loan) internal view {
        address implementation = IProxiedLike(loan).implementation();

        console2.log("fixed term loan address:        ", loan);
        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newImplementation);

        require(implementation == newImplementation, "implementation address does not match");
    }

}

contract ValidateConfigureFactories is ValidationBase {

    function run() external view {
        validateFixedTermLoanFactory();
        validateFixedTermLoanManagerFactory();
        validateOpenTermLoanFactory();
        validateOpenTermLoanManagerFactory();
        validatePoolManagerFactory();
    }

    function validateFixedTermLoanFactory() internal view {
        console2.log("implementation code hash:", uint256(newFtlImplementation.codehash));
        console2.log("migrator code hash:      ", uint256(newFtlMigrator.codehash));

        require(newFtlImplementation.codehash == expectedFtlImplementationCodeHash, "FTL implementation code hash does not match");
        require(newFtlMigrator.codehash == expectedFtlMigratorCodeHash,             "FTL migrator code hash does not match");

        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanFactory).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanFactory).implementationOf(500);
        address migrator       = IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(400, 500);
        bool    upgradeEnabled = IProxyFactoryLike(fixedTermLoanFactory).upgradeEnabledForPath(400, 500);

        console2.log("default version:       ", defaultVersion);
        console2.log("implementation address:", implementation);
        console2.log("migrator address:      ", migrator);
        console2.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 500,                  "FTL default version is invalid");
        require(implementation == newFtlImplementation, "FTL implementation is invalid");
        require(migrator == newFtlMigrator,             "FTL migrator is invalid");
        require(upgradeEnabled,                         "FTL upgrade is not enabled");
    }

    function validateFixedTermLoanManagerFactory() internal view {
        console2.log("implementation code hash:", uint256(newFtlmImplementation.codehash));

        require(newFtlmImplementation.codehash == expectedFtlmImplementationCodeHash, "FT-LM implementation code hash does not match");

        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanManagerFactory).implementationOf(300);
        address migrator       = IProxyFactoryLike(fixedTermLoanManagerFactory).migratorForPath(200, 300);
        bool    upgradeEnabled = IProxyFactoryLike(fixedTermLoanManagerFactory).upgradeEnabledForPath(200, 300);

        console2.log("default version:       ", defaultVersion);
        console2.log("implementation address:", implementation);
        console2.log("migrator address:      ", migrator);
        console2.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 300,                   "FT-LM default version is invalid");
        require(implementation == newFtlmImplementation, "FT-LM implementation is invalid");
        require(migrator == address(0),                  "FT-LM migrator is invalid");
        require(upgradeEnabled,                          "FT-LM upgrade is not enabled");
    }

    function validateOpenTermLoanFactory() internal view {
        console2.log("factory code hash:       ", uint256(newOtlFactory.codehash));
        console2.log("implementation code hash:", uint256(newOtlImplementation.codehash));
        console2.log("initializer code hash:   ", uint256(newOtlInitializer.codehash));

        require(newOtlFactory.codehash == expectedOtlFactoryCodeHash,               "OTL factory code hash does not match");
        require(newOtlImplementation.codehash == expectedOtlImplementationCodeHash, "OTL implementation code hash does not match");
        require(newOtlInitializer.codehash == expectedOtlInitializerCodeHash,       "OTL initializer code hash does not match");

        uint256 defaultVersion = IProxyFactoryLike(newOtlFactory).defaultVersion();
        address implementation = IProxyFactoryLike(newOtlFactory).implementationOf(100);
        address initializer    = IProxyFactoryLike(newOtlFactory).migratorForPath(100, 100);

        console2.log("default version:       ", defaultVersion);
        console2.log("implementation address:", implementation);
        console2.log("initializer address:   ", initializer);

        require(defaultVersion == 100,                  "OTL default version is invalid");
        require(implementation == newOtlImplementation, "OTL implementation is invalid");
        require(initializer == newOtlInitializer,       "OTL initializer is invalid");
    }

    function validateOpenTermLoanManagerFactory() internal view {
        console2.log("factory code hash:       ", uint256(newOtlmFactory.codehash));
        console2.log("implementation code hash:", uint256(newOtlmImplementation.codehash));
        console2.log("initializer code hash:   ", uint256(newOtlmInitializer.codehash));

        require(newOtlmFactory.codehash == expectedOtlmFactoryCodeHash,               "OT-LM factory code hash does not match");
        require(newOtlmImplementation.codehash == expectedOtlmImplementationCodeHash, "OT-LM implementation code hash does not match");
        require(newOtlmInitializer.codehash == expectedOtlmInitializerCodeHash,       "OT-LM initializer code hash does not match");

        uint256 defaultVersion = IProxyFactoryLike(newOtlmFactory).defaultVersion();
        address implementation = IProxyFactoryLike(newOtlmFactory).implementationOf(100);
        address initializer    = IProxyFactoryLike(newOtlmFactory).migratorForPath(100, 100);

        console2.log("default version:       ", defaultVersion);
        console2.log("implementation address:", implementation);
        console2.log("initializer address:   ", initializer);

        require(defaultVersion == 100,                   "OT-LM default version is invalid");
        require(implementation == newOtlmImplementation, "OT-LM implementation is invalid");
        require(initializer == newOtlmInitializer,       "OT-LM initializer is invalid");
    }

    function validatePoolManagerFactory() internal view {
        console2.log("implementation code hash:", uint256(newPmImplementation.codehash));

        require(newPmImplementation.codehash == expectedPmImplementationCodeHash, "PM implementation code hash does not match");

        uint256 defaultVersion = IProxyFactoryLike(poolManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(poolManagerFactory).implementationOf(200);
        address migrator       = IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 200);
        bool    upgradeEnabled = IProxyFactoryLike(poolManagerFactory).upgradeEnabledForPath(100, 200);

        console2.log("default version:       ", defaultVersion);
        console2.log("implementation address:", implementation);
        console2.log("migrator address:      ", migrator);
        console2.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 200,                 "PM default version is invalid");
        require(implementation == newPmImplementation, "PM implementation is invalid");
        require(migrator == address(0),                "PM migrator is invalid");
        require(upgradeEnabled,                        "PM upgrade is not enabled");
    }

}

contract ValidateRemoveGlobalConfiguration is ValidationBase {

    IGlobals globals = IGlobals(mapleGlobalsV2Proxy);

    function run() external view {
        require(!globals.isInstanceOf("LIQUIDATOR",         liquidatorFactory),           "LIQ factory is not removed");
        require(!globals.isInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory), "FT-LM factory is not removed");
        require(!globals.isInstanceOf("POOL_MANAGER",       poolManagerFactory),          "PM factory is not removed");
        require(!globals.isInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory),    "WM factory is not removed");
        require(!globals.isInstanceOf("LOAN",               fixedTermLoanFactory),        "FTL factory is not removed");

        require(!globals.canDeployFrom(poolManagerFactory,       poolDeployer), "PD can deploy PM");
        require(!globals.canDeployFrom(withdrawalManagerFactory, poolDeployer), "PD can deploy WM");
    }

}

contract ValidateAddGlobalConfiguration is ValidationBase {

    IGlobals globals = IGlobals(mapleGlobalsV2Proxy);

    function run() external view {
        require(globals.isInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory),        "LIQ factory is not added");
        require(globals.isInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory),       "PM factory is not added");
        require(globals.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory), "WM factory is not added");

        require(globals.isInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory), "FTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory), "FTL factory is not added");

        require(globals.isInstanceOf("OT_LOAN_FACTORY", newOtlFactory), "OTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    newOtlFactory), "OTL factory is not added");

        require(globals.isInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory), "FT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory), "FT-LM factory is not added");

        require(globals.isInstanceOf("OT_LOAN_MANAGER_FACTORY", newOtlmFactory), "OT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    newOtlmFactory), "OT-LM factory is not added");

        require(globals.isInstanceOf("FT_REFINANCER", fixedTermRefinancer), "FT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    fixedTermRefinancer), "FT-REF is not added");

        require(globals.isInstanceOf("OT_REFINANCER", newOtlRefinancer), "OT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    newOtlRefinancer), "OT-REF is not added");

        require(globals.isInstanceOf("FEE_MANAGER", feeManager), "FM is not added");

        require(globals.canDeployFrom(poolManagerFactory,       newDeployer), "PD can't deploy PM");
        require(globals.canDeployFrom(withdrawalManagerFactory, newDeployer), "PD can't deploy WM");

        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenPermissionedPoolManager), "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdcPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenWethPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, orthogonalPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, icebreakerPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, aqruPoolManager),              "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdc3PoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, cashMgmtPoolManager),          "PM can't deploy FT-LM");

        require(globals.canDeployFrom(newOtlmFactory, mavenPermissionedPoolManager), "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, mavenUsdcPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, mavenWethPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, orthogonalPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, icebreakerPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, aqruPoolManager),              "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, mavenUsdc3PoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(newOtlmFactory, cashMgmtPoolManager),          "PM can't deploy OT-LM");
    }

}

contract ValidateUpgradeFixedTermLoanManagers is ValidationBase {

    function run() external view {
        validateCodeHash();

        validateLoanManager(mavenPermissionedFixedTermLoanManager);
        validateLoanManager(mavenUsdcFixedTermLoanManager);
        validateLoanManager(mavenWethFixedTermLoanManager);
        validateLoanManager(orthogonalFixedTermLoanManager);
        validateLoanManager(icebreakerFixedTermLoanManager);
        validateLoanManager(aqruFixedTermLoanManager);
        validateLoanManager(mavenUsdc3FixedTermLoanManager);
        validateLoanManager(cashMgmtFixedTermLoanManager);
    }

    function validateCodeHash() internal view {
        bytes32 computedCodeHash = newFtlmImplementation.codehash;

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedFtlImplementationCodeHash));

        require(computedCodeHash == expectedFtlImplementationCodeHash, "code hash does not match");
    }

    function validateLoanManager(address loanManager) internal view {
        address implementation = IProxiedLike(loanManager).implementation();

        console2.log("FT-LM address:                  ", loanManager);
        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newFtlmImplementation);

        require(implementation == newFtlmImplementation, "implementation address does not match");
    }

}

contract ValidateUpgradePoolManagers is ValidationBase {

    function run() external view {
        validateCodeHash();

        validatePoolManager(mavenPermissionedPoolManager);
        validatePoolManager(mavenUsdcPoolManager);
        validatePoolManager(mavenWethPoolManager);
        validatePoolManager(orthogonalPoolManager);
        validatePoolManager(icebreakerPoolManager);
        validatePoolManager(aqruPoolManager);
        validatePoolManager(mavenUsdc3PoolManager);
        validateLoanManager(cashMgmtPoolManager);
    }

    function validateCodeHash() internal view {
        bytes32 computedCodeHash =newPmImplementation.codehash;

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedPmImplementationCodeHash));

        require(computedCodeHash == expectedPmImplementationCodeHash, "code hash does not match");
    }

    function validatePoolManager(address poolManager) internal view {
        address implementation = IProxiedLike(poolManager).implementation();

        console2.log("PM address:                     ", poolManager);
        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newPmImplementation);

        require(implementation == newPmImplementation, "implementation address does not match");
    }

}
