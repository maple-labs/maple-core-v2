// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MaplePoolManager as PoolManager } from "../../modules/pool/contracts/MaplePoolManager.sol";

import {
    IGlobals,
    ILoanLike,
    IPool,
    IPoolPermissionManager,
    IProxiedLike,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console, Test } from "../../contracts/Contracts.sol";

import { UpgradeAddressRegistryETH }    from "./UpgradeAddressRegistryETH.sol";
import { UpgradeAddressRegistryBASEL2 } from "./UpgradeAddressRegistryBASEL2.sol";

contract ValidationBaseETH is UpgradeAddressRegistryETH, Test {

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function validateContract(string memory contractName, address contractAddress, bytes32 expectedCodeHash) internal view {
        console.log("contract name     :", contractName);
        console.log("contract address  :", contractAddress);

        console.log("computed code hash:");
        console.logBytes32(contractAddress.codehash);

        console.log("expected code hash:");
        console.logBytes32(expectedCodeHash);

        require(contractAddress.codehash == expectedCodeHash, "code hash does not match");

        console.log("");
    }

    function validateFixedTermLoanFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(protocol.fixedTermLoanFactory).defaultVersion();
        address implementation = IProxyFactoryLike(protocol.fixedTermLoanFactory).implementationOf(502);
        address initializer    = IProxyFactoryLike(protocol.fixedTermLoanFactory).migratorForPath(502, 502);
        address migrator       = IProxyFactoryLike(protocol.fixedTermLoanFactory).migratorForPath(501, 502);
        bool    upgradeEnabled = IProxyFactoryLike(protocol.fixedTermLoanFactory).upgradeEnabledForPath(501, 502);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);
        console.log("migrator address:      ", migrator);
        console.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 501,                             "FTL default version is invalid");
        require(implementation == fixedTermLoanImplementationV502, "FTL implementation is invalid");
        require(initializer == fixedTermLoanInitializerV500,       "FTL initializer is invalid");
        require(migrator == fixedTermLoanV502Migrator,             "FTL migrator is invalid");
        require(upgradeEnabled,                                    "FTL upgrade is not enabled");

        console.log("");
    }

    function validateNewFixedTermLoanFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanFactoryV2).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanFactoryV2).implementationOf(502);
        address initializer    = IProxyFactoryLike(fixedTermLoanFactoryV2).migratorForPath(502, 502);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 502,                             "new FTL default version is invalid");
        require(implementation == fixedTermLoanImplementationV502, "new FTL implementation is invalid");
        require(initializer == fixedTermLoanInitializerV500,       "new FTL initializer is invalid");

        console.log("");
    }

    function validatePoolManagerFactory() internal view {
        uint256 defaultVersion      = IProxyFactoryLike(protocol.poolManagerFactory).defaultVersion();
        address implementationV300  = IProxyFactoryLike(protocol.poolManagerFactory).implementationOf(300);
        address initializerV300     = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(300, 300);
        bool    upgradeEnabled1     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(200, 300);
        bool    upgradeEnabled2     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(201, 300);
        address migrator1           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(200, 300);
        address migrator2           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(201, 300);

        console.log("default version:           ", defaultVersion);
        console.log("implementation 300 address:", implementationV300);
        console.log("initializer address:       ", initializerV300);
        console.log("migrator1 address:         ", migrator1);
        console.log("migrator2 address:         ", migrator2);
        console.log("upgrade enabled:           ", upgradeEnabled1);
        console.log("upgrade enabled:           ", upgradeEnabled2);

        require(defaultVersion == 300,                               "PM default version is invalid");
        require(implementationV300 == poolManagerImplementationV300, "PM implementation is invalid");
        require(initializerV300 == poolManagerInitializer,           "PM initializer is invalid");
        require(migrator1 == migrator2,                              "PM migrator is invalid");
        require(migrator1 == poolManagerMigrator,                    "PM migrator is invalid");
        require(upgradeEnabled1 && upgradeEnabled2,                  "PM upgrade is not enabled");

        console.log("");
    }

    function validatePoolManagerFactoryForQueueWm() internal view {
        address implementationV301 = IProxyFactoryLike(protocol.poolManagerFactory).implementationOf(301);
        address initializerV300    = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(301, 301);
        bool    upgradeEnabled     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(300, 301);
        address migrator           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(300, 301);

        console.log("implementation 301 address:", implementationV301);
        console.log("initializer address:       ", initializerV300);
        console.log("migrator address:          ", migrator);
        console.log("upgrade enabled:           ", upgradeEnabled);

        require(implementationV301 == poolManagerImplementationV301, "PM implementation is invalid");
        require(initializerV300 == poolManagerInitializer,           "PM initializer is invalid");
        require(migrator == address(poolManagerWMMigrator),          "PM migrator is invalid");
        require(upgradeEnabled,                                      "PM upgrade is not enabled");

        console.log("");
    }

    function validateWithdrawalManagerCyclicalFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(protocol.withdrawalManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(protocol.withdrawalManagerFactory).implementationOf(110);
        address initializer    = IProxyFactoryLike(protocol.withdrawalManagerFactory).migratorForPath(110, 110);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 110,                      "Cyclical WM default version is invalid");
        require(implementation == cyclicalWMImplementation, "Cyclical WM implementation is invalid");
        require(initializer == cyclicalWMInitializer,       "Cyclical WM initializer is invalid");

        console.log("");
    }

    function validateNewWithdrawalQueueFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(queueWMFactory).defaultVersion();
        address implementation = IProxyFactoryLike(queueWMFactory).implementationOf(100);
        address initializer    = IProxyFactoryLike(queueWMFactory).migratorForPath(100, 100);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 100,                   "Queue Wm default version is invalid");
        require(implementation == queueWMImplementation, "Queue Wm implementation is invalid");
        require(initializer == queueWMInitializer,       "Queue Wm initializer is invalid");

        console.log("");
    }

    function validateLoans(address[] memory loans) internal view {
        for (uint256 i; i < loans.length; i++) {
            validateLoan(loans[i]);
            console.log("");
        }
    }

    function validateLoan(address loan) internal view {
        address implementation = IProxiedLike(loan).implementation();
        address factory        = ILoanLike(loan).factory();

        console.log("fixed term loan address:        ", loan);
        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", fixedTermLoanImplementationV502);
        console.log("current factory:",                 factory);
        console.log("expected factory:",                fixedTermLoanFactoryV2);

        require(implementation == fixedTermLoanImplementationV502,      "implementation address does not match");
        require(factory        == fixedTermLoanFactoryV2,               "factory does not match");
        require(IProxyFactoryLike(fixedTermLoanFactoryV2).isLoan(loan), "loan not instance on factory");
    }

    function validatePoolManager(address poolManager, address expectedImplementation) internal view {
        address currentImplementation = IProxiedLike(poolManager).implementation();

        console.log("PM address:                     ", poolManager);
        console.log("current implementation address: ", currentImplementation);
        console.log("expected implementation address:", expectedImplementation);

        require(currentImplementation == expectedImplementation, "implementation address does not match");

        console.log("");
    }

}

contract ValidationBaseBASEL2 is UpgradeAddressRegistryBASEL2, Test {

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function validateContract(string memory contractName, address contractAddress, bytes32 expectedCodeHash) internal view {
        console.log("contract name     :", contractName);
        console.log("contract address  :", contractAddress);

        console.log("computed code hash:");
        console.logBytes32(contractAddress.codehash);

        console.log("expected code hash:");
        console.logBytes32(expectedCodeHash);

        require(contractAddress.codehash == expectedCodeHash, "code hash does not match");

        console.log("");
    }

    function validateFixedTermLoanFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(protocol.fixedTermLoanFactory).defaultVersion();
        address implementation = IProxyFactoryLike(protocol.fixedTermLoanFactory).implementationOf(502);
        address initializer    = IProxyFactoryLike(protocol.fixedTermLoanFactory).migratorForPath(502, 502);
        address migrator       = IProxyFactoryLike(protocol.fixedTermLoanFactory).migratorForPath(501, 502);
        bool    upgradeEnabled = IProxyFactoryLike(protocol.fixedTermLoanFactory).upgradeEnabledForPath(501, 502);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);
        console.log("migrator address:      ", migrator);
        console.log("upgrade enabled:       ", upgradeEnabled);

        require(defaultVersion == 501,                             "FTL default version is invalid");
        require(implementation == fixedTermLoanImplementationV502, "FTL implementation is invalid");
        require(initializer == fixedTermLoanInitializerV500,       "FTL initializer is invalid");
        require(migrator == fixedTermLoanV502Migrator,             "FTL migrator is invalid");
        require(upgradeEnabled,                                    "FTL upgrade is not enabled");

        console.log("");
    }

    function validateNewFixedTermLoanFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(fixedTermLoanFactoryV2).defaultVersion();
        address implementation = IProxyFactoryLike(fixedTermLoanFactoryV2).implementationOf(502);
        address initializer    = IProxyFactoryLike(fixedTermLoanFactoryV2).migratorForPath(502, 502);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 502,                             "new FTL default version is invalid");
        require(implementation == fixedTermLoanImplementationV502, "new FTL implementation is invalid");
        require(initializer == fixedTermLoanInitializerV500,       "new FTL initializer is invalid");

        console.log("");
    }

    function validatePoolManagerFactory() internal view {
        uint256 defaultVersion      = IProxyFactoryLike(protocol.poolManagerFactory).defaultVersion();
        address implementationV300  = IProxyFactoryLike(protocol.poolManagerFactory).implementationOf(300);
        address initializerV300     = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(300, 300);
        bool    upgradeEnabled1     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(200, 300);
        bool    upgradeEnabled2     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(201, 300);
        address migrator1           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(200, 300);
        address migrator2           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(201, 300);

        console.log("default version:           ", defaultVersion);
        console.log("implementation 300 address:", implementationV300);
        console.log("initializer address:       ", initializerV300);
        console.log("migrator1 address:         ", migrator1);
        console.log("migrator2 address:         ", migrator2);
        console.log("upgrade enabled:           ", upgradeEnabled1);
        console.log("upgrade enabled:           ", upgradeEnabled2);

        require(defaultVersion == 300,                               "PM default version is invalid");
        require(implementationV300 == poolManagerImplementationV300, "PM implementation is invalid");
        require(initializerV300 == poolManagerInitializer,           "PM initializer is invalid");
        require(migrator1 == migrator2,                              "PM migrator is invalid");
        require(migrator1 == poolManagerMigrator,                    "PM migrator is invalid");
        require(upgradeEnabled1 && upgradeEnabled2,                  "PM upgrade is not enabled");

        console.log("");
    }

    function validatePoolManagerFactoryForQueueWm() internal view {
        address implementationV301 = IProxyFactoryLike(protocol.poolManagerFactory).implementationOf(301);
        address initializerV300    = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(301, 301);
        bool    upgradeEnabled     = IProxyFactoryLike(protocol.poolManagerFactory).upgradeEnabledForPath(300, 301);
        address migrator           = IProxyFactoryLike(protocol.poolManagerFactory).migratorForPath(300, 301);

        console.log("implementation 301 address:", implementationV301);
        console.log("initializer address:       ", initializerV300);
        console.log("migrator address:          ", migrator);
        console.log("upgrade enabled:           ", upgradeEnabled);

        require(implementationV301 == poolManagerImplementationV301, "PM implementation is invalid");
        require(initializerV300 == poolManagerInitializer,           "PM initializer is invalid");
        require(migrator == address(poolManagerWMMigrator),          "PM migrator is invalid");
        require(upgradeEnabled,                                      "PM upgrade is not enabled");

        console.log("");
    }

    function validateWithdrawalManagerCyclicalFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(protocol.withdrawalManagerFactory).defaultVersion();
        address implementation = IProxyFactoryLike(protocol.withdrawalManagerFactory).implementationOf(110);
        address initializer    = IProxyFactoryLike(protocol.withdrawalManagerFactory).migratorForPath(110, 110);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 110,                      "Cyclical WM default version is invalid");
        require(implementation == cyclicalWMImplementation, "Cyclical WM implementation is invalid");
        require(initializer == cyclicalWMInitializer,       "Cyclical WM initializer is invalid");

        console.log("");
    }

    function validateNewWithdrawalQueueFactory() internal view {
        uint256 defaultVersion = IProxyFactoryLike(queueWMFactory).defaultVersion();
        address implementation = IProxyFactoryLike(queueWMFactory).implementationOf(100);
        address initializer    = IProxyFactoryLike(queueWMFactory).migratorForPath(100, 100);

        console.log("default version:       ", defaultVersion);
        console.log("implementation address:", implementation);
        console.log("initializer address:   ", initializer);

        require(defaultVersion == 100,                   "Queue Wm default version is invalid");
        require(implementation == queueWMImplementation, "Queue Wm implementation is invalid");
        require(initializer == queueWMInitializer,       "Queue Wm initializer is invalid");

        console.log("");
    }

    function validateLoans(address[] memory loans) internal view {
        for (uint256 i; i < loans.length; i++) {
            validateLoan(loans[i]);
            console.log("");
        }
    }

    function validateLoan(address loan) internal view {
        address implementation = IProxiedLike(loan).implementation();
        address factory        = ILoanLike(loan).factory();

        console.log("fixed term loan address:        ", loan);
        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", fixedTermLoanImplementationV502);
        console.log("current factory:",                 factory);
        console.log("expected factory:",                fixedTermLoanFactoryV2);

        require(implementation == fixedTermLoanImplementationV502,      "implementation address does not match");
        require(factory        == fixedTermLoanFactoryV2,               "factory does not match");
        require(IProxyFactoryLike(fixedTermLoanFactoryV2).isLoan(loan), "loan not instance on factory");
    }

    function validatePoolManager(address poolManager, address expectedImplementation) internal view {
        address currentImplementation = IProxiedLike(poolManager).implementation();

        console.log("PM address:                     ", poolManager);
        console.log("current implementation address: ", currentImplementation);
        console.log("expected implementation address:", expectedImplementation);

        require(currentImplementation == expectedImplementation, "implementation address does not match");

        console.log("");
    }

}

contract ValidateDeployContractsETH is ValidationBaseETH {

    function setUp() public override {
        super.setUp();
    }

    // Check the newly deployed contracts.
    function run() external view {
        validateContract(
            "fixedTermLoanImplementationV502",
            fixedTermLoanImplementationV502,
            expectedFixedTermLoanImplementationV502CodeHash
        );

        validateContract(
            "fixedTermLoanInitializerV500",
            fixedTermLoanInitializerV500,
            expectedFixedTermLoanInitializerV500CodeHash
        );

        validateContract(
            "fixedTermLoanFactoryV2",
            fixedTermLoanFactoryV2,
            expectedFixedTermLoanFactoryV2CodeHash
        );

        validateContract(
            "fixedTermLoanMigratorV502",
            fixedTermLoanV502Migrator,
            expectedFixedTermLoanV502MigratorCodeHash
        );

        validateContract(
            "globalsImplementationV3",
            globalsImplementationV3,
            expectedGlobalsImplementationV3CodeHash
        );

        validateContract(
            "poolDeployerV3",
            poolDeployerV3,
            expectedPoolDeployerV3CodeHash
        );

        validateContract(
            "poolManagerImplementationV300",
            poolManagerImplementationV300,
            expectedPoolManagerImplementationV300CodeHash
        );

        validateContract(
            "poolManagerImplementationV301",
            poolManagerImplementationV301,
            expectedPoolManagerImplementationV301CodeHash
        );

        validateContract(
            "poolManagerInitializer",
            poolManagerInitializer,
            expectedPoolManagerInitializerCodeHash
        );

        validateContract(
            "poolManagerMigrator",
            poolManagerMigrator,
            expectedPoolManagerMigratorCodeHash
        );

        validateContract(
            "poolManagerWMMigrator",
            poolManagerWMMigrator,
            expectedPoolManagerWMMigratorCodeHash
        );

        validateContract(
            "poolPermissionManager",
            poolPermissionManager,
            expectedPoolPermissionManagerCodeHash
        );

        validateContract(
            "poolPermissionManagerImplementation",
            poolPermissionManagerImplementation,
            expectedPoolPermissionManagerImplCodeHash
        );

        validateContract(
            "poolPermissionManagerInitializer",
            poolPermissionManagerInitializer,
            expectedPoolPermissionManagerInitializerCodeHash
        );

        validateContract(
            "cyclicalWMImplementation",
            cyclicalWMImplementation,
            expectedCyclicalWMImplementationCodeHash
        );

        validateContract(
            "cyclicalWMInitializer",
            cyclicalWMInitializer,
            expectedCyclicalWMInitializerCodeHash
        );

        validateContract(
            "queueWMFactory",
            queueWMFactory,
            expectedQueueWMFactoryCodeHash
        );

        validateContract(
            "queueWMImplementation",
            queueWMImplementation,
            expectedQueueWMImplementationCodeHash
        );

        validateContract(
            "queueWMInitializer",
            queueWMInitializer,
            expectedQueueWMInitializerCodeHash
        );

    }

}

contract ValidateDeployContractsBASEL2 is ValidationBaseBASEL2 {

    function setUp() public override {
        super.setUp();
    }

    // Check the newly deployed contracts.
    function run() external view {
        validateContract(
            "fixedTermLoanImplementationV502",
            fixedTermLoanImplementationV502,
            expectedFixedTermLoanImplementationV502CodeHash
        );

        validateContract(
            "fixedTermLoanInitializerV500",
            fixedTermLoanInitializerV500,
            expectedFixedTermLoanInitializerV500CodeHash
        );

        validateContract(
            "fixedTermLoanFactoryV2",
            fixedTermLoanFactoryV2,
            expectedFixedTermLoanFactoryV2BASECodeHash
        );

        validateContract(
            "fixedTermLoanMigratorV502",
            fixedTermLoanV502Migrator,
            expectedFixedTermLoanV502MigratorCodeHash
        );

        validateContract(
            "globalsImplementationV3",
            globalsImplementationV3,
            expectedGlobalsImplementationV3CodeHash
        );

        validateContract(
            "poolDeployerV3",
            poolDeployerV3,
            expectedPoolDeployerV3CodeHash
        );

        validateContract(
            "poolManagerImplementationV300",
            poolManagerImplementationV300,
            expectedPoolManagerImplementationV300CodeHash
        );

        validateContract(
            "poolManagerImplementationV301",
            poolManagerImplementationV301,
            expectedPoolManagerImplementationV301CodeHash
        );

        validateContract(
            "poolManagerInitializer",
            poolManagerInitializer,
            expectedPoolManagerInitializerCodeHash
        );

        validateContract(
            "poolManagerMigrator",
            poolManagerMigrator,
            expectedPoolManagerMigratorCodeHash
        );

        validateContract(
            "poolManagerWMMigrator",
            poolManagerWMMigrator,
            expectedPoolManagerWMMigratorCodeHash
        );

        validateContract(
            "poolPermissionManager",
            poolPermissionManager,
            expectedPoolPermissionManagerCodeHash
        );

        validateContract(
            "poolPermissionManagerImplementation",
            poolPermissionManagerImplementation,
            expectedPoolPermissionManagerImplCodeHash
        );

        validateContract(
            "poolPermissionManagerInitializer",
            poolPermissionManagerInitializer,
            expectedPoolPermissionManagerInitializerCodeHash
        );

        validateContract(
            "cyclicalWMImplementation",
            cyclicalWMImplementation,
            expectedCyclicalWMImplementationCodeHash
        );

        validateContract(
            "cyclicalWMInitializer",
            cyclicalWMInitializer,
            expectedCyclicalWMInitializerCodeHash
        );

        validateContract(
            "queueWMFactory",
            queueWMFactory,
            expectedQueueWMFactoryCodeHash
        );

        validateContract(
            "queueWMImplementation",
            queueWMImplementation,
            expectedQueueWMImplementationCodeHash
        );

        validateContract(
            "queueWMInitializer",
            queueWMInitializer,
            expectedQueueWMInitializerCodeHash
        );

    }

}

contract ValidateUpgradeGlobalsETH is ValidationBaseETH {

    function run() external view {
        address implementation = IProxiedLike(protocol.globals).implementation();

        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", globalsImplementationV3);

        require(implementation == globalsImplementationV3, "implementation address does not match");

        // Validate that operational admin has been set
        require(IGlobals(globals).operationalAdmin() == securityAdmin, "operational admin not set");

        // PPM is initialized
        require(IPoolPermissionManager(poolPermissionManager).globals() == protocol.globals, "PPM not initialized");

        // Validate All Factories
        validateFixedTermLoanFactory();
        validateNewFixedTermLoanFactory();
        validatePoolManagerFactory();
        validatePoolManagerFactoryForQueueWm();
        validateWithdrawalManagerCyclicalFactory();
        validateNewWithdrawalQueueFactory();

        // Check oracles delays are set
        ( address wbtcOracle, uint96 wbtcMaxDelay ) = IGlobals(globals).priceOracleOf(wbtc);

        require(wbtcOracle == btcUsdOracle, "WBTC oracle not set");
        require(wbtcMaxDelay == 14400,      "WBTC oracle delay not set");

        ( address wethOracle, uint96 wethMaxDelay ) = IGlobals(globals).priceOracleOf(weth);

        require(wethOracle == ethUsdOracle, "WETH oracle not set");
        require(wethMaxDelay == 14400,      "WETH oracle delay not set");
    }

}

contract ValidateUpgradeGlobalsBASEL2 is ValidationBaseBASEL2 {

    function run() external view {
        address implementation = IProxiedLike(protocol.globals).implementation();

        console.log("current implementation address: ", implementation);
        console.log("expected implementation address:", globalsImplementationV3);

        require(implementation == globalsImplementationV3, "implementation address does not match");

        // Validate that operational admin has been set
        require(IGlobals(globals).operationalAdmin() == securityAdmin, "operational admin not set");

        // PPM is initialized
        require(IPoolPermissionManager(poolPermissionManager).globals() == protocol.globals, "PPM not initialized");

        // Validate All Factories
        validateFixedTermLoanFactory();
        validateNewFixedTermLoanFactory();
        validatePoolManagerFactory();
        validatePoolManagerFactoryForQueueWm();
        validateWithdrawalManagerCyclicalFactory();
        validateNewWithdrawalQueueFactory();
    }

}

contract ValidateMegaProcedureETH is ValidationBaseETH {

    function setUp() public override {
        super.setUp();
    }

    // Check the newly deployed contracts.
    function run() external view {
        // Validate Globals Config
        IGlobals globals_ = IGlobals(protocol.globals);

        require(globals_.isInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactoryV2),            "Loan not added");
        require(globals_.isInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactoryV2),            "FT Loan not added");
        require(globals_.isInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager)),    "PPM not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", protocol.withdrawalManagerFactory), "WMCF not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory),                    "WMQF not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory),                    "WMF not added");

        for (uint256 i; i < queueUpgradePools.length; i++) {
            require(globals_.isInstanceOf("QUEUE_POOL_MANAGER", pools[queueUpgradePools[i]].poolManager), "QPM1 not added");
        }

        require(globals_.canDeployFrom(protocol.poolManagerFactory,       poolDeployerV3), "PMF can't deploy");
        require(globals_.canDeployFrom(protocol.withdrawalManagerFactory, poolDeployerV3), "WMF can't deploy");
        require(globals_.canDeployFrom(queueWMFactory,                    poolDeployerV3), "QMF can't deploy 1");
        require(globals_.canDeployFrom(queueWMFactory,                    securityAdmin),  "QMF can't deploy 2");

        // ValidateLenders
        for (uint256 i; i < pools.length; i++) {
            for (uint256 j; j < pools[i].lps.length; j++) {
                require(
                    IPoolPermissionManager(poolPermissionManager).lenderAllowlist(pools[i].poolManager, pools[i].lps[j]),
                    "lender not allowed"
                );
            }
        }

        // ValidateUpgradePoolManagerContractsETH
        for (uint256 i; i < pools.length; i++) {
            validatePoolManager(pools[i].poolManager, poolManagerImplementationV300);
        }

        // ValidateUpgradeFixedTermLoansETH
        for (uint256 i; i < pools.length; i++) {
            validateLoans(pools[i].ftLoans);
        }

    }

}

contract ValidateMegaProcedureBASEL2 is ValidationBaseBASEL2 {

    function setUp() public override {
        super.setUp();
    }

    // Check the newly deployed contracts.
    function run() external view {
        // Validate Globals Config
        IGlobals globals_ = IGlobals(protocol.globals);

        require(globals_.isInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactoryV2),            "Loan not added");
        require(globals_.isInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactoryV2),            "FT Loan not added");
        require(globals_.isInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager)),    "PPM not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", protocol.withdrawalManagerFactory), "WMCF not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory),                    "WMQF not added");
        require(globals_.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory),                    "WMF not added");

        for (uint256 i; i < queueUpgradePools.length; i++) {
            require(globals_.isInstanceOf("QUEUE_POOL_MANAGER", pools[queueUpgradePools[i]].poolManager), "QPM1 not added");
        }

        require(globals_.canDeployFrom(protocol.poolManagerFactory,       poolDeployerV3), "PMF can't deploy");
        require(globals_.canDeployFrom(protocol.withdrawalManagerFactory, poolDeployerV3), "WMF can't deploy");
        require(globals_.canDeployFrom(queueWMFactory,                    poolDeployerV3), "QMF can't deploy 1");
        require(globals_.canDeployFrom(queueWMFactory,                    securityAdmin),  "QMF can't deploy 2");

        // ValidateLenders
        for (uint256 i; i < pools.length; i++) {
            for (uint256 j; j < pools[i].lps.length; j++) {
                require(
                    IPoolPermissionManager(poolPermissionManager).lenderAllowlist(pools[i].poolManager, pools[i].lps[j]),
                    "lender not allowed"
                );
            }
        }

        // ValidateUpgradePoolManagerContractsETH
        for (uint256 i; i < pools.length; i++) {
            validatePoolManager(pools[i].poolManager, poolManagerImplementationV300);
        }

        // ValidateUpgradeFixedTermLoansETH
        for (uint256 i; i < pools.length; i++) {
            validateLoans(pools[i].ftLoans);
        }

    }

}

contract ValidatePoolManagerPauseETH is ValidationBaseETH {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            validatePMPause(pools[queueUpgradePools[i]].poolManager);
        }
    }

    function validatePMPause(address poolManager) internal view {
        IGlobals globals_ = IGlobals(protocol.globals);

        // Check functions that should be Unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.migrate.selector),                      "migrate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setImplementation.selector),            "setImplementation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.upgrade.selector),                      "upgrade");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestFunds.selector),                 "requestFunds");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setDelegateManagementFeeRate.selector), "setDelegateManagementFeeRate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.triggerDefault.selector),               "triggerDefault");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.finishCollateralLiquidation.selector),  "finishCollateralLiquidation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.canCall.selector),                      "canCall");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processRedeem.selector),                "processRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processWithdraw.selector),              "processWithdraw");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.removeShares.selector),                 "removeShares");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setIsLoanManager.selector),             "setIsLoanManager");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setLiquidityCap.selector),              "setLiquidityCap");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.depositCover.selector),                 "depositCover");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.withdrawCover.selector),                "withdrawCover");

        // Check functions that should be Paused
        require(globals_.isFunctionPaused(poolManager, PoolManager.requestRedeem.selector),   "requestRedeem");
        require(globals_.isFunctionPaused(poolManager, PoolManager.requestWithdraw.selector), "requestWithdraw");
    }

}

contract ValidatePoolManagerPauseBASEL2 is ValidationBaseBASEL2 {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            validatePMPause(pools[queueUpgradePools[i]].poolManager);
        }
    }

    function validatePMPause(address poolManager) internal view {
        IGlobals globals_ = IGlobals(protocol.globals);

        // Check functions that should be Unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.migrate.selector),                      "migrate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setImplementation.selector),            "setImplementation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.upgrade.selector),                      "upgrade");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestFunds.selector),                 "requestFunds");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setDelegateManagementFeeRate.selector), "setDelegateManagementFeeRate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.triggerDefault.selector),               "triggerDefault");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.finishCollateralLiquidation.selector),  "finishCollateralLiquidation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.canCall.selector),                      "canCall");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processRedeem.selector),                "processRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processWithdraw.selector),              "processWithdraw");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.removeShares.selector),                 "removeShares");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setIsLoanManager.selector),             "setIsLoanManager");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setLiquidityCap.selector),              "setLiquidityCap");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.depositCover.selector),                 "depositCover");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.withdrawCover.selector),                "withdrawCover");

        // Check functions that should be Paused
        require(globals_.isFunctionPaused(poolManager, PoolManager.requestRedeem.selector),   "requestRedeem");
        require(globals_.isFunctionPaused(poolManager, PoolManager.requestWithdraw.selector), "requestWithdraw");
    }

}

contract ValidateEmptyCashWMETH is ValidationBaseETH {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            require(IPool(pools[queueUpgradePools[i]].pool).balanceOf(pools[queueUpgradePools[i]].withdrawalManager) == 0, "WM has shares");
        }
    }

}

contract ValidateEmptyCashWMBASEL2 is ValidationBaseBASEL2 {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            require(IPool(pools[queueUpgradePools[i]].pool).balanceOf(pools[queueUpgradePools[i]].withdrawalManager) == 0, "WM has shares");
        }
    }

}

contract ValidateUpgradePoolManagerContractsForQueueWMETH is ValidationBaseETH {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            validatePoolManager(pools[queueUpgradePools[i]].poolManager, poolManagerImplementationV301);
            validatePMPause(pools[queueUpgradePools[i]].poolManager);
        }

    }

    function validatePMPause(address poolManager) internal view {
        IGlobals globals_ = IGlobals(protocol.globals);

        // Check functions that should be Unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.migrate.selector),                      "migrate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setImplementation.selector),            "setImplementation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.upgrade.selector),                      "upgrade");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestFunds.selector),                 "requestFunds");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setDelegateManagementFeeRate.selector), "setDelegateManagementFeeRate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.triggerDefault.selector),               "triggerDefault");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.finishCollateralLiquidation.selector),  "finishCollateralLiquidation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.canCall.selector),                      "canCall");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processRedeem.selector),                "processRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processWithdraw.selector),              "processWithdraw");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.removeShares.selector),                 "removeShares");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setIsLoanManager.selector),             "setIsLoanManager");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setLiquidityCap.selector),              "setLiquidityCap");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.depositCover.selector),                 "depositCover");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.withdrawCover.selector),                "withdrawCover");

        // Check functions that were paused but should be unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestRedeem.selector),   "requestRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestWithdraw.selector), "requestWithdraw");
    }

}

contract ValidateUpgradePoolManagerContractsForQueueWMBASEL2 is ValidationBaseBASEL2 {

    function run() external view {
        for (uint256 i; i < queueUpgradePools.length; i++) {
            validatePoolManager(pools[queueUpgradePools[i]].poolManager, poolManagerImplementationV301);
            validatePMPause(pools[queueUpgradePools[i]].poolManager);
        }

    }

    function validatePMPause(address poolManager) internal view {
        IGlobals globals_ = IGlobals(protocol.globals);

        // Check functions that should be Unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.migrate.selector),                      "migrate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setImplementation.selector),            "setImplementation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.upgrade.selector),                      "upgrade");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestFunds.selector),                 "requestFunds");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setDelegateManagementFeeRate.selector), "setDelegateManagementFeeRate");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.triggerDefault.selector),               "triggerDefault");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.finishCollateralLiquidation.selector),  "finishCollateralLiquidation");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.canCall.selector),                      "canCall");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processRedeem.selector),                "processRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.processWithdraw.selector),              "processWithdraw");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.removeShares.selector),                 "removeShares");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setIsLoanManager.selector),             "setIsLoanManager");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.setLiquidityCap.selector),              "setLiquidityCap");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.depositCover.selector),                 "depositCover");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.withdrawCover.selector),                "withdrawCover");

        // Check functions that were paused but should be unpaused
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestRedeem.selector),   "requestRedeem");
        require(!globals_.isFunctionPaused(poolManager, PoolManager.requestWithdraw.selector), "requestWithdraw");
    }

}

contract ValidatePostUpgradeCleanUpETH is ValidationBaseETH {

    function run() external view {
        IGlobals globals_ = IGlobals(protocol.globals);

        require(!globals_.canDeployFrom(protocol.poolManagerFactory,       protocol.poolDeployerV2), "PMF can deploy");
        require(!globals_.canDeployFrom(protocol.withdrawalManagerFactory, protocol.poolDeployerV2), "WMF can deploy");
        require(!globals_.canDeployFrom(queueWMFactory,                    protocol.securityAdmin),  "SA can deploy");

        require(IProxyFactoryLike(protocol.fixedTermLoanFactory).defaultVersion() == 0, "factory not deprecated");

        // Validate that operational admin has been set
        require(IGlobals(globals).operationalAdmin() == protocol.operationalAdmin, "operational admin not set");
    }

}

contract ValidatePostUpgradeCleanUpBASEL2 is ValidationBaseBASEL2 {

    function run() external view {
        IGlobals globals_ = IGlobals(protocol.globals);

        require(!globals_.canDeployFrom(protocol.poolManagerFactory,       protocol.poolDeployerV2), "PMF can deploy");
        require(!globals_.canDeployFrom(protocol.withdrawalManagerFactory, protocol.poolDeployerV2), "WMF can deploy");
        require(!globals_.canDeployFrom(queueWMFactory,                    protocol.securityAdmin),  "SA can deploy");

        require(IProxyFactoryLike(protocol.fixedTermLoanFactory).defaultVersion() == 0, "factory not deprecated");

        // Validate that operational admin has been set
        require(IGlobals(globals).operationalAdmin() == protocol.operationalAdmin, "operational admin not set");
    }

}
