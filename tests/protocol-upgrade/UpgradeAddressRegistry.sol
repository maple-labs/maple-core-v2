// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { StdCheats } from "../../modules/forge-std/src/StdCheats.sol";

contract UpgradeAddressRegistry is AddressRegistry, StdCheats {

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses                                                                                           ***/
    /**************************************************************************************************************************************/

    address oldGlobalsOnTreasury = 0xC234c62c8C09687DFf0d9047e40042cd166F3600;

    address timelock = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address canceller = securityAdmin;
    address executor  = operationalAdmin;
    address proposer  = governor;
    address roleAdmin = governor;

    address backupExecutor  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdmin = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Plasma                                                                                  ***/
    /**************************************************************************************************************************************/

    address timelockPlasma = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerPlasma       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorPlasma        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerPlasma        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminPlasma       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerPlasma = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorPlasma  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminPlasma = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDTPlasma       = 0xC4374775489CB9C56003BF2C9b12495fC64F0771;
    address syrupUSDTDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Base                                                                                    ***/
    /**************************************************************************************************************************************/

    address timelockBase = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerBase       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorBase        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerBase        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminBase       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerBase = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorBase  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminBase = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDCBase             = 0x660975730059246A68521a3e2FBD4740173100f5;
    address syrupUSDCBaseDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Mantle                                                                                  ***/
    /**************************************************************************************************************************************/

    address timelockMantle = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerMantle       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorMantle        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerMantle        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminMantle       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerMantle = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorMantle  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminMantle = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Ink                                                                                     ***/
    /**************************************************************************************************************************************/

    address timelockInk = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerInk       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorInk        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerInk        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminInk       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerInk = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorInk  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminInk = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDCInk = 0x3c23e6FB09064e9A64829Fa8FEe27Ad19A27Bfa9;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Monad                                                                                   ***/
    /**************************************************************************************************************************************/

    address timelockMonad = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerMonad       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorMonad        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerMonad        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminMonad       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerMonad = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorMonad  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminMonad = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDCMonad = 0xaB6e5a0C3799d020c790D34F7B2C02639e238AF7;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Arbitrum                                                                                ***/
    /**************************************************************************************************************************************/

    address timelockArbitrum = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerArbitrum       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorArbitrum        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerArbitrum        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminArbitrum       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerArbitrum = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorArbitrum  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminArbitrum = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDCArbitrum             = 0x41CA7586cC1311807B4605fBB748a3B8862b42b5;
    address syrupUSDCArbitrumDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    address syrupUSDGArbitrum             = 0xE1B0dC5A21b10f1634fBfbE9976fBA2Ee2e1c762;
    address syrupUSDGArbitrumDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - Arc                                                                                     ***/
    /**************************************************************************************************************************************/

    address timelockArc = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerArc       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorArc        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerArc        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminArc       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerArc = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorArc  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminArc = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    address syrupUSDCArc             = 0x0dC6b79F3c3854E4d74514fD4d29BE6c96Beee39;
    address syrupUSDCArcDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** GovernorTimelock Procedure Addresses - XLayer                                                                                  ***/
    /**************************************************************************************************************************************/

    address timelockXLayer = 0x2eFFf88747EB5a3FF00d4d8d0f0800E306C0426b;

    address cancellerXLayer       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
    address executorXLayer        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
    address proposerXLayer        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address roleAdminXLayer       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address tokenWithdrawerXLayer = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
    address backupExecutorXLayer  = 0x6D9F3a385796A5407C06a5BF18e903916548993e;
    address backupRoleAdminXLayer = 0xa04Bddfb5bCe1Afc0a939749Dc721BA762019b2a;

    /**************************************************************************************************************************************/
    /*** CCIP Procedure Addresses - Robinhood                                                                                           ***/
    /**************************************************************************************************************************************/

    // TODO: Replace with the Robinhood default admin once it is confirmed.
    address syrupUSDCRobinhood             = 0xC6a4854eeB493224d5f9485E12Dd3A81f22EEE14;
    address syrupUSDCRobinhoodDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** CCIP Procedure Addresses - Tempo                                                                                               ***/
    /**************************************************************************************************************************************/

    // TODO: Replace with the Tempo default admin once it is confirmed.
    address syrupUSDCTempo             = 0x20c0000000000000000000008191667423F70E67;
    address syrupUSDCTempoDefaultAdmin = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Queue v2.0.0 Addresses                                                                                      ***/
    /**************************************************************************************************************************************/

    address mapleWithdrawalManagerV200Implementation = 0xF95E5722226a1018d058CD757B75F1D10289e967;
    address mapleWithdrawalManagerV200Initializer    = 0xD389BFE4A129525b486B098411336a4fCecF3024;
    address mapleWithdrawalManagerV200Migrator       = 0x327ec27a6D898D865D7759D47d36a2c3FBbD23a5;

    /**************************************************************************************************************************************/
    /*** Health Checker Addresses                                                                                                       ***/
    /**************************************************************************************************************************************/

    address updatedProtocolHealthChecker     = 0xfb8F87D716ac3fC54f33664F51E3961bc2DD3EDb;
    address updatedOpenTermLoanHealthChecker = 0xa2e3c1e3e2b8E2B8B5e3FF1d4c3b2A1f4e5d6C7d;

    /**************************************************************************************************************************************/
    /*** Modular Release - Legacy Strategies                                                                                            ***/
    /**************************************************************************************************************************************/

    address syrupUSDCFixedTermLoanManager          = 0x4A1c3F0D9aD0b3f9dA085bEBfc22dEA54263371b;
    address syrupUSDTFixedTermLoanManager          = 0xC17aa0Cb662bC4787bB16bD3Bc13d0d88eB7aBDd;
    address securedLendingUSDCFixedTermLoanManager = 0x78a13c2f24dF55feeF7f8C895396cf1DD21Cf56f;

    address syrupUSDCAaveStrategy          = 0x560B3A85Af1cEF113BB60105d0Cf21e1d05F91d4;
    address syrupUSDCSkyStrategy           = 0x859C9980931fa0A63765fD8EF2e29918Af5b038C;
    address syrupUSDTAaveStrategy          = 0x2b817B822B0ddd4597a92dBEd1bD0a6796CA37E0;
    address securedLendingUSDCAaveStrategy = 0x87Aa770f610679DFC2553FB95fAc1B4d996BA1cd;
    address securedLendingUSDCSkyStrategy  = 0xe3eE1b26AF5396Cec45c8C3b4c4FD5136A2455CC;

    /**************************************************************************************************************************************/
    /*** Modular Release - Strategy Delegates                                                                                           ***/
    /**************************************************************************************************************************************/

    address dexLpUSDCDelegate     = 0xD6c4aa6aCe3d84042F20f4104dB73b8e9498af20;
    address dexLpUSDTDelegate     = 0x161C8444e26589c889D3272EA16fBF4542823bD3;
    address dexLpUSDGDelegate     = 0xce856C275F5F538cBf98b775F4c5f82BD11953C8;
    address basisUSDTDelegate     = 0xc273F952D5F8bEad96F48e9eF825349EAEAbA941;
    address pyusdUSDCDelegate     = 0xbDb279963Fa7E8D21e455A39255803c17f58c3d2;
    address pyusdMislUSDCDelegate = 0xFdD0254684cb059D90151f864405Fc47d50329AF;
    address pyusdUSDTDelegate     = 0xeF82e192A10d19C8984A80fd4045288b475ac2f9;
    address pyusdUSDGDelegate     = 0xbe6ebdAf944169B0a0522AFecf1Ec1377A04C3a1;
    address usdtbUSDCDelegate     = 0xDD6325358295eBA7434f31a692F96C4b0209f4B3;
    address usdtbUSDTDelegate     = 0xEd6E21286eBe15B53aa0C9CD8cdDb3726b12A3fE;
    address ustbUSDCDelegate      = 0xDC24F91f20e6B1e75A7343393C8749184801f810;
    address ustbMislUSDCDelegate  = 0x73C3e24b928d2a024043a8A8AddE06065eaA1C69;
    address ustbUSDTDelegate      = 0x3eF5CEB04B9B9ec3ba7E9e83200D18782BFdFf62;
    address defiUSDCDelegate      = 0x01FAEC366bb8f508D03e54368078633c060b532d;
    address defiUSDTDelegate      = 0xA9c5398FbEdaa21BFD5175445bEa0669246Faa02;
    address defiUSDGDelegate      = 0x02a064e126998726E838394469C2009f7Fe6150B;
    address aaveV3USDCDelegate    = 0x280dE039be6C86E782f2F5DF0482873a1ea49840;
    address aaveV3USDTDelegate    = 0x900AC4DE423AC307572Ebd685A34D8aA6647075a;

    /**************************************************************************************************************************************/
    /*** Modular Release - Deployed Strategies                                                                                          ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Modular Release - Managed Wallets                                                                                              ***/
    /**************************************************************************************************************************************/

    address dexLpUSDC_syrupUSDC_managedWallet              = 0x649aEF93e8688e74965f1E60ce4eB6b273180DE1;
    address dexLpUSDT_syrupUSDT_managedWallet              = 0x232f60a3cD961Ae4024C9761a59E091Ea0Eb5328;
    address dexLpUSDG_syrupUSDG_managedWallet              = 0x3B1E96fB67c8E4B17a764f735650764c7661C7a0;
    address basisUSDT_syrupUSDT_managedWallet              = 0xa4943BEe2cE013e547E90E0F4565a181A2dc5391;
    address pyusdUSDC_syrupUSDC_managedWallet              = 0x0F6b3eAd281c44c4F4571aB494836F9001827A11;
    address pyusdUSDC_securedLending2USDC_managedWallet    = 0x5D060Be5e00e42baa72425Aa7b11fAd2052Db089;
    address pyusdMislUSDC_securedLendingUSDC_managedWallet = 0x02Ed70FF9689f27205e66111113a6671eC0F65bC;
    address pyusdUSDT_syrupUSDT_managedWallet              = 0xA58a1Ad9bbE5cA9124C7AB29c3C6b7b442906814;
    address pyusdUSDG_syrupUSDG_managedWallet              = 0x8D0be82e1ea979898285BE2e97C8F3F82f2bB979;
    address usdtbUSDC_syrupUSDC_managedWallet              = 0x1c4Ba6076b7a4058fd016b9DE937c465D57Ab0Fb;
    address usdtbUSDC_securedLending2USDC_managedWallet    = 0x539854C14dBB2fDB9F5FA8f6F52120c309791C7A;
    address usdtbUSDT_syrupUSDT_managedWallet              = 0xD33bAdBd105ac2e6473E0308be00c413Bb0CF3e4;
    address ustbUSDC_syrupUSDC_managedWallet               = 0xECf5fd0B39C81e850C1AA2A2C7b3BFFe396Abc73;
    address ustbUSDC_securedLending2USDC_managedWallet     = 0x9B1629012fd0d9dF69667D3EB7e972dCe7901371;
    address ustbMislUSDC_securedLendingUSDC_managedWallet  = 0x7CaF30307efEeeCb9B042dA71749ae5660A5C0d2;
    address ustbUSDT_syrupUSDT_managedWallet               = 0xdCd572776B5E669d576CcB8314d251CfE59C7fF4;
    address defiUSDC_syrupUSDC_managedWallet               = 0x2bCdf509eEE48E19d17444903a63872CE51A3259;
    address defiUSDT_syrupUSDT_managedWallet               = 0x7a5c8809Ee2D66A712205E57ca295894751273cA;
    address defiUSDG_syrupUSDG_managedWallet               = 0xEf65d8aA4003B6FBC2169abCB5204AE2165967E3;

}
