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
        address operationalAdmin;
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

    bytes32 constant expectedFixedTermLoanImplementationV502CodeHash  = 0x168d2cde2ee106d29c16296cd0e32bcbf2769d05f26548b2464992f5350d8697;
    bytes32 constant expectedFixedTermLoanInitializerV500CodeHash     = 0x7d00dd204a33d89b847cdcf0689bc6109bfa41ac9a4371478d582d6222fd30e6;
    bytes32 constant expectedFixedTermLoanFactoryV2CodeHash           = 0x15cb499e08b7b59e744b231ac36ceedcd856033d22ce07c8560e05f0561783fb;
    bytes32 constant expectedFixedTermLoanFactoryV2BASECodeHash       = 0x4b003dc649d64af65fd42dea7b34726b9a28f47a48f0ce6fe5b916216b9c85a1;
    bytes32 constant expectedFixedTermLoanV502MigratorCodeHash        = 0x9efc2854537663a6d2859e8701d97de4722d758d794d924ec8aa562fd0dc7e17;
    bytes32 constant expectedGlobalsImplementationV3CodeHash          = 0xe058190392cf4a3c49619cc5e87a7c42bdc7148514f21f21c47946dfa747948d;
    bytes32 constant expectedPoolDeployerV3CodeHash                   = 0x4f1b53123fde7838673d2b0dfc1c47c25437a17a5cce9512a8d56bbc42ab4bfc;
    bytes32 constant expectedPoolManagerImplementationV300CodeHash    = 0x0210cf1836149284ea4c3a92eee06591c270843d7601be0bc346809930900fa9;
    bytes32 constant expectedPoolManagerImplementationV301CodeHash    = 0x0210cf1836149284ea4c3a92eee06591c270843d7601be0bc346809930900fa9;
    bytes32 constant expectedPoolManagerInitializerCodeHash           = 0x0e9dfff45cb7b38ea31e6468f48f2e12f6749aafea239c778f9cce8086d0fa53;
    bytes32 constant expectedPoolManagerMigratorCodeHash              = 0xe75fc744c70e95a3465ccc462b3533e454113b898bf724ebf925495dc4162eb5;
    bytes32 constant expectedPoolManagerWMMigratorCodeHash            = 0x7745d1b777612c3e91ad3b57c145dd0d9af416c549b290918bb06c25c35c13fd;
    bytes32 constant expectedPoolPermissionManagerCodeHash            = 0xfc4b542b98e65e308447b9e52ec457622b749a3a19b65f827640310f1a34134c;
    bytes32 constant expectedPoolPermissionManagerImplCodeHash        = 0x5b13364a741b2496cac16e25e737dec7dbbf0f5cdf6ab8b4eab5efe59b09f201;
    bytes32 constant expectedPoolPermissionManagerInitializerCodeHash = 0x67450c06ff1102c2a983d046f8ef5d18e2bec15606e1f721f1be9ff7d41b58ee;
    bytes32 constant expectedCyclicalWMImplementationCodeHash         = 0x37c9ab1efb3b8ed5b422ac5b475a3b1d770fea3c33d86abb50906713d2ae2cfa;
    bytes32 constant expectedCyclicalWMInitializerCodeHash            = 0xb59105bb4cf229a32cc106a168157c6cc4dc14ddd0f59d87bffcb02f9b840f77;
    bytes32 constant expectedQueueWMFactoryCodeHash                   = 0x0311f920ff8482a36b92112aea9804a4f23e7dd03db6042215f049f59d46b603;
    bytes32 constant expectedQueueWMImplementationCodeHash            = 0xfe6515923728df94725da20f95dbb684b885f7db48a876c38598ff0a04a2ce8c;
    bytes32 constant expectedQueueWMInitializerCodeHash               = 0x2819fc721ce337ff7d03e8fbee38c31d21c4e8a3dd140cc8da73d178382b892c;

    address fixedTermLoanInitializerV500;

    address fixedTermLoanImplementationV502 = 0x7a6F2C7B4F6aD1cB00AB23ECc5b41D25dA439005;
    address fixedTermLoanFactoryV2          = 0xeA067DB5B32CE036Ee5D8607DBB02f544768dBC6;
    address fixedTermLoanV502Migrator       = 0x6D4416E6C0536fD33127d38Af21bc912475584E3;

    address globalsImplementationV3 = 0x5A64417823E8382a7e8957E4411873FE758E73a8;

    address poolDeployerV3 = 0x12fB5dbBDB06ab973f047cC46D6bB33ba4d03b96;

    address poolManagerImplementationV300 = 0x0055c00ba4Dec5ed545A5419C4d430daDa8cb1CE;
    address poolManagerImplementationV301 = 0x5b1D19AC5420bA8819aad6C0B98A41095E5C86c2;  // Same implementation as 301
    address poolManagerInitializer        = 0x252C44A1630095504E3D3972b9b296f5ED494911;
    address poolManagerMigrator           = 0x9450d0D19802Ae0aDD44565752CDAB70E0A1C6ed;
    address poolManagerWMMigrator         = 0x9d07A8373E9ABE5A430cCD161d6373e248D7778F;

    address poolPermissionManager               = 0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3;
    address poolPermissionManagerImplementation = 0xC3530358e54bC81EfCe4A2e12A898E996B091753;
    address poolPermissionManagerInitializer    = 0x73A53fcECE63D4C0098535f6f62Df0F5d12A5175;

    address cyclicalWMImplementation = 0xCc4e684916aA7Fa0E4fAEF2359B49A755f89C75b;
    address cyclicalWMInitializer    = 0x485bA3F5235F150bF8e4Afbd3a25c266cDAdD9Dd;
    address queueWMFactory           = 0xca33105902E8d232DDFb9f71Ff3D79C7E7f2C4e5;
    address queueWMImplementation    = 0x899B57Bbd8597aa2d1898476504f479c982c5c2c;
    address queueWMInitializer       = 0x637f8dC4C4d07D1CC30ae131fA94A060dee6be96;

    Protocol protocol;

    Pool[] pools;

    uint256[] cashPools;
}
