// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

abstract contract UpgradeAddressRegistry {

    struct Pool {
        string name;
        address pool;
        address poolManager;
        address withdrawalManager;
        address fixedTermLoanManager;
        address openTermLoanManager;
        address[] lps;
        address[] otLoans;
        address[] ftLoans;
    }

    struct Protocol {
        address governor;
        address mapleTreasury;
        address securityAdmin;
        address mplv1;
        address xmpl;
        address usdc;
        address fixedTermFeeManagerV1;
        address fixedTermLoanFactory;
        address fixedTermLoanManagerFactory;
        address fixedTermRefinancerV2;
        address globals;
        address globalsImplementationV2;
        address liquidatorFactory;
        address openTermLoanFactory;
        address openTermLoanManagerFactory;
        address openTermRefinancerV1;
        address poolDeployerV2;
        address poolManagerFactory;
        address withdrawalManagerFactory;
        Asset[] assets;
    }

    struct Asset {
        address asset;
        address oracle;
    } 

    address fixedTermLoanImplementationV502;
    address fixedTermLoanInitializerV500;
    address fixedTermLoanFactoryV2;
    address fixedTermLoanV502Migrator;

    address globalsImplementationV3;

    address poolDeployerV3;

    address poolManagerImplementationV300;
    address poolManagerImplementationV301;  // Same implementation as 301, but changes the WM in the migrator.
    address poolManagerInitializer;
    address poolManagerMigrator;
    address poolManagerWMMigrator;

    address poolPermissionManagerImplementation;
    address poolPermissionManagerInitializer;

    address cyclicalWMImplementation;
    address cyclicalWMInitializer;
    address queueWMFactory;
    address queueWMImplementation;
    address queueWMInitializer;

    Protocol protocol;

    Pool[] pools;
}
