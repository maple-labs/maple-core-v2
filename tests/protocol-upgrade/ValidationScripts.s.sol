// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxiedLike, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { console as console, Test } from "../../contracts/Contracts.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ValidationBase is UpgradeAddressRegistry, Test {

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function validateCodeHash(address account, bytes32 codeHash) internal view {
        console.log("computed code hash:", uint256(account.codehash));
        console.log("expected code hash:", uint256(codeHash));

        require(account.codehash == codeHash, "code hash does not match");
    }

}

contract ValidateDeployContracts is ValidationBase {

    function setUp() public override {
        super.setUp();
    }

    function run() external view {
        validateContract(
            "fixedTermLoanImplementationV501",
            fixedTermLoanImplementationV501,
            expectedFixedTermLoanImplementationV501CodeHash
        );

        validateContract(
            "fixedTermLoanInitializerV500",
            fixedTermLoanInitializerV500,
            expectedFixedTermLoanInitializerV500CodeHash
        );

        validateContract(
            "fixedTermLoanMigratorV500",
            fixedTermLoanMigratorV500,
            expectedFixedTermLoanMigratorV500CodeHash
        );

        validateContract(
            "fixedTermRefinancerV2",
            fixedTermRefinancerV2,
            expectedFixedTermRefinancerV2CodeHash
        );

        validateContract(
            "fixedTermLoanManagerImplementationV301",
            fixedTermLoanManagerImplementationV301,
            expectedFixedTermLoanManagerImplementationV301CodeHash
        );

        validateContract(
            "fixedTermLoanManagerInitializerV300",
            fixedTermLoanManagerInitializerV300,
            expectedFixedTermLoanManagerInitializerV300CodeHash
        );

        validateContract(
            "globalsImplementationV2",
            globalsImplementationV2,
            expectedGlobalsImplementationV2CodeHash
        );

        validateContract(
            "openTermLoanFactory",
            openTermLoanFactory,
            expectedOpenTermLoanFactoryCodeHash
        );

        validateContract(
            "openTermLoanImplementationV101",
            openTermLoanImplementationV101,
            expectedOpenTermLoanImplementationV101CodeHash
        );

        validateContract(
            "openTermLoanInitializerV100",
            openTermLoanInitializerV100,
            expectedOpenTermLoanInitializerV100CodeHash
        );

        validateContract(
            "openTermRefinancerV1",
            openTermRefinancerV1,
            expectedOpenTermRefinancerV1CodeHash
        );

        validateContract(
            "openTermLoanManagerFactory",
            openTermLoanManagerFactory,
            expectedOpenTermLoanManagerFactoryCodeHash
        );

        validateContract(
            "openTermLoanManagerImplementationV100",
            openTermLoanManagerImplementationV100,
            expectedOpenTermLoanManagerImplementationV100CodeHash
        );

        validateContract(
            "openTermLoanManagerInitializerV100",
            openTermLoanManagerInitializerV100,
            expectedOpenTermLoanManagerInitializerV100CodeHash
        );

        validateContract(
            "poolDeployerV2",
            poolDeployerV2,
            expectedPoolDeployerV2CodeHash
        );


        validateContract(
            "poolManagerImplementationV200",
            poolManagerImplementationV200,
            expectedPoolManagerImplementationV200CodeHash
        );

    }

    function validateContract(string memory contractName, address contractAddress, bytes32 expectedCodeHash) internal view {
        console.log("contract name:     ", contractName);
        console.log("contract address:  ", contractAddress);

        validateCodeHash(contractAddress, expectedCodeHash);

        console.log("");
    }

}

contract ValidateUpgradeMapleGlobals is ValidationBase {

    function run() external view {
        address implementation = IProxiedLike(mapleGlobalsProxy).implementation();

        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", globalsImplementationV2);

        require(implementation == globalsImplementationV2, "implementation address does not match");
    }

}

contract ValidateAddGlobalConfiguration is ValidationBase {

    IGlobals globals = IGlobals(mapleGlobalsProxy);

    function run() external view {
        require(globals.isInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory),        "LIQ factory is not added");
        require(globals.isInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory),       "PM factory is not added");
        require(globals.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory), "WM factory is not added");

        require(globals.isInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory), "FTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory), "FTL factory is not added");

        require(globals.isInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory), "OTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    openTermLoanFactory), "OTL factory is not added");

        require(globals.isInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory), "FT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory), "FT-LM factory is not added");

        require(globals.isInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory), "OT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    openTermLoanManagerFactory), "OT-LM factory is not added");

        require(globals.isInstanceOf("FT_REFINANCER", fixedTermRefinancerV2), "FT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    fixedTermRefinancerV2), "FT-REF is not added");

        require(globals.isInstanceOf("OT_REFINANCER", openTermRefinancerV1), "OT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    openTermRefinancerV1), "OT-REF is not added");

        require(globals.isInstanceOf("FEE_MANAGER", fixedTermFeeManagerV1), "FM is not added");

        require(globals.canDeployFrom(poolManagerFactory,       poolDeployerV2), "PD can't deploy PM");
        require(globals.canDeployFrom(withdrawalManagerFactory, poolDeployerV2), "PD can't deploy WM");

        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenPermissionedPoolManager), "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdcPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenWethPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, orthogonalPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, icebreakerPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, aqruPoolManager),              "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdc3PoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, cashMgmtPoolManager),          "PM can't deploy FT-LM");

        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenPermissionedPoolManager), "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenUsdcPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenWethPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, orthogonalPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, icebreakerPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, aqruPoolManager),              "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenUsdc3PoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, cashMgmtPoolManager),          "PM can't deploy OT-LM");
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
        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanFactory).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanFactory).implementationOf(501);
        address migrator       = IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(400, 501);
        address initializer    = IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501);
        bool    upgradeEnabled = IProxyFactoryLike(fixedTermLoanFactory).upgradeEnabledForPath(400, 501);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);
        console.log("migrator address:      ", migrator);
        console.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 501,                             "FTL default version is invalid");
        require(implementation == fixedTermLoanImplementationV501, "FTL implementation is invalid");
        require(initializer == fixedTermLoanInitializerV500,       "FTL initializer is invalid");
        require(migrator == fixedTermLoanMigratorV500,             "FTL migrator is invalid");
        require(upgradeEnabled,                                    "FTL upgrade is not enabled");

        console.log("");
    }

    function validateFixedTermLoanManagerFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanManagerFactory).implementationOf(301);
        address migrator       = IProxyFactoryLike(fixedTermLoanManagerFactory).migratorForPath(200, 301);
        address initializer    = IProxyFactoryLike(fixedTermLoanManagerFactory).migratorForPath(301, 301);
        bool    upgradeEnabled = IProxyFactoryLike(fixedTermLoanManagerFactory).upgradeEnabledForPath(200, 301);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);
        console.log("migrator address:      ", migrator);
        console.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 301,                                    "FT-LM default version is invalid");
        require(implementation == fixedTermLoanManagerImplementationV301, "FT-LM implementation is invalid");
        require(initializer == fixedTermLoanManagerInitializerV300,       "FT-LM initializer is invalid");
        require(migrator == address(0),                                   "FT-LM migrator is invalid");
        require(upgradeEnabled,                                           "FT-LM upgrade is not enabled");

        console.log("");
    }

    function validateOpenTermLoanFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(openTermLoanFactory).defaultVersion();
        address implementation = IProxyFactoryLike(openTermLoanFactory).implementationOf(101);
        address initializer    = IProxyFactoryLike(openTermLoanFactory).migratorForPath(101, 101);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 101,                            "OTL default version is invalid");
        require(implementation == openTermLoanImplementationV101, "OTL implementation is invalid");
        require(initializer == openTermLoanInitializerV100,       "OTL initializer is invalid");

        console.log("");
    }

    function validateOpenTermLoanManagerFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(openTermLoanManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(openTermLoanManagerFactory).implementationOf(100);
        address initializer    = IProxyFactoryLike(openTermLoanManagerFactory).migratorForPath(100, 100);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 100,                                   "OT-LM default version is invalid");
        require(implementation == openTermLoanManagerImplementationV100, "OT-LM implementation is invalid");
        require(initializer == openTermLoanManagerInitializerV100,       "OT-LM initializer is invalid");

        console.log("");
    }

    function validatePoolManagerFactory() internal view {
        uint256 defaultVersion  = IProxyFactoryLike(poolManagerFactory).defaultVersion();
        address implementation  = IProxyFactoryLike(poolManagerFactory).implementationOf(200);
        address initializerV100 = IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 100);
        address initializerV200 = IProxyFactoryLike(poolManagerFactory).migratorForPath(200, 200);
        address migrator        = IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 200);
        bool    upgradeEnabled  = IProxyFactoryLike(poolManagerFactory).upgradeEnabledForPath(100, 200);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializerV200);
        console.log("migrator address:      ", migrator);
        console.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 200,                           "PM default version is invalid");
        require(implementation == poolManagerImplementationV200, "PM implementation is invalid");
        require(initializerV200 == initializerV100,              "PM initializer is invalid");
        require(migrator == address(0),                          "PM migrator is invalid");
        require(upgradeEnabled,                                  "PM upgrade is not enabled");

        console.log("");
    }

}

contract ValidateUpgradePoolContracts is ValidationBase {

    function run() external view {
        validatePoolManager(mavenPermissionedPoolManager);
        validatePoolManager(mavenUsdcPoolManager);
        validatePoolManager(mavenWethPoolManager);
        validatePoolManager(orthogonalPoolManager);
        validatePoolManager(icebreakerPoolManager);
        validatePoolManager(aqruPoolManager);
        validatePoolManager(mavenUsdc3PoolManager);
        validatePoolManager(cashMgmtPoolManager);

        validateLoanManager(mavenPermissionedFixedTermLoanManager);
        validateLoanManager(mavenUsdcFixedTermLoanManager);
        validateLoanManager(mavenWethFixedTermLoanManager);
        validateLoanManager(orthogonalFixedTermLoanManager);
        validateLoanManager(icebreakerFixedTermLoanManager);
        validateLoanManager(aqruFixedTermLoanManager);
        validateLoanManager(mavenUsdc3FixedTermLoanManager);
        validateLoanManager(cashMgmtFixedTermLoanManager);
    }

    function validatePoolManager(address poolManager) internal view {
        address implementation = IProxiedLike(poolManager).implementation();

        console.log("PM address:                     ", poolManager);
        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", poolManagerImplementationV200);

        require(implementation == poolManagerImplementationV200, "implementation address does not match");

        console.log("");
    }

    function validateLoanManager(address loanManager) internal view {
        address implementation = IProxiedLike(loanManager).implementation();

        console.log("FT-LM address:                  ", loanManager);
        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", fixedTermLoanManagerImplementationV301);

        require(implementation == fixedTermLoanManagerImplementationV301, "implementation address does not match");

        console.log("");
    }

}

contract ValidateUpgradeFixedTermLoans is ValidationBase {

    function run() external view {
        validateLoans(mavenPermissionedLoans);
        validateLoans(mavenUsdcLoans);
        validateLoans(mavenWethLoans);
        validateLoans(orthogonalLoans);
        validateLoans(icebreakerLoans);
        validateLoans(aqruLoans);
        validateLoans(mavenUsdc3Loans);
        validateLoans(cashMgmtLoans);
    }

    function validateLoans(address[] memory loans) internal view {
        for (uint256 i; i < loans.length; i++) {
            validateLoan(loans[i]);
            console.log("");
        }
    }

    function validateLoan(address loan) internal view {
        address implementation = IProxiedLike(loan).implementation();

        console.log("fixed term loan address:        ", loan);
        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", fixedTermLoanImplementationV501);

        require(implementation == fixedTermLoanImplementationV501, "implementation address does not match");
    }

}

contract ValidateRemoveGlobalConfiguration is ValidationBase {

    IGlobals globals = IGlobals(mapleGlobalsProxy);

    function run() external view {
        require(!globals.isInstanceOf("LIQUIDATOR",         liquidatorFactory),           "LIQ factory is not removed");
        require(!globals.isInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory), "FT-LM factory is not removed");
        require(!globals.isInstanceOf("POOL_MANAGER",       poolManagerFactory),          "PM factory is not removed");
        require(!globals.isInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory),    "WM factory is not removed");
        require(!globals.isInstanceOf("LOAN",               fixedTermLoanFactory),        "FTL factory is not removed");

        require(!globals.canDeployFrom(poolManagerFactory,       poolDeployerV1), "PD can deploy PM");
        require(!globals.canDeployFrom(withdrawalManagerFactory, poolDeployerV1), "PD can deploy WM");
    }

}
