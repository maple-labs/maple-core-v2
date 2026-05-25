// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

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

    /**************************************************************************************************************************************/
    /*** syrupBTC Procedure Addresses                                                                                                   ***/
    /**************************************************************************************************************************************/

    // syrupBTC Deployer 0x987cF164b7bfC45f833CF5f426F3FF9f341dD11E

    address assetControllerV100Implementation  = 0x4911fA884Bb6Ba1Fc3bc9f6798006ED6aBB7d5f5;
    address assetPriceOracleV100Implementation = 0x033B333d3fDBf10b66c79807AAA3b951d87b265e;
    address bitcoinRouterV100Implementation    = 0xCFb0C41791CBA35691670Da366f4E2e0FA175DAA;
    address bitcoinStrategyV100Implementation  = 0x88B040042Eb95Aa46Fd95971bBCd7ea2ebd4b149;
    address compositeTokenV100Implementation   = 0x4Aa3466B78baD18F87fe2a510a1eff65eed5F1CC;

    address assetControllerV100Initializer = 0xA15cee00b256b9e5cC66c624E882629458549638;
    address bitcoinRouterV100Initializer   = 0x9633c4304dDbBadb8f6F035490a86B72C4911cB2;
    address bitcoinStrategyV100Initializer = 0xC345266f92b81BA3D4ed11848878eEbe72471b6f;
    address compositeTokenV100Initializer  = 0x94F3f443086b0B2C8E72896a9AE82De499e8393d;

    address assetControllerProxy  = 0xEC6e3B04b68D319d0bf74cC42a7bcFa4a1c247f5;
    address assetPriceOracleProxy = 0x8ce6cA79Edb491609380A91Bc63B927A929404f4;
    address bitcoinRouterProxy    = 0x6199CaFac0ddCE84a8eb1A94Cd76D255e3AA3e5b;
    address compositeTokenProxy   = 0x67685C6c39E862c57895d5782206829d5cc0aD8C;

    address bitcoinStrategyFactory  = 0x9a05C78e021B15841D50DDFd92dde8Ef7d14508D;
    address bitcoinStrategy1        = 0x56312e04C2A69864BD95E212E7651fC21f9d00cC;  // BTC
    address bitcoinStrategy2        = 0x67a7450CC9235AD416620a79d2398719e6A2D865;  // Stablecoin
    address bitcoinStrategy3        = 0x9B66Be315A68E4374F84B067d5a08f6524D58b73;  // Liquidity
    address syrupBitcoinPool        = 0x0011bDd5f5629D842266E62bE6EF55106c96010C;
    address syrupBitcoinPoolManager = 0x7f9c02bEcaD5E9f5d63831eBDBb318Ef8a8a7B86;

    address mapleWithdrawalManagerV200Implementation = 0xF95E5722226a1018d058CD757B75F1D10289e967;
    address mapleWithdrawalManagerV200Initializer    = 0xD389BFE4A129525b486B098411336a4fCecF3024;
    address mapleWithdrawalManagerV200Migrator       = 0x327ec27a6D898D865D7759D47d36a2c3FBbD23a5;

    address syrupBitcoinPoolDelegate = 0x7F21a3C90567B86417a386d52232B79381563408;

    address bitcoinStrategy1Manager = 0x0DcD6029374bAE21074214834bB0DedD920A0C93;
    address bitcoinStrategy2Manager = 0x4041b0d75e159095365034B28e3b9De0712E1475;
    address bitcoinStrategy3Manager = 0x8f0D8e61dc9D604E6f4147a00994b40Df9d6F565;

    /**************************************************************************************************************************************/
    /*** Core Strategy Deployment Addresses                                                                                             ***/
    /**************************************************************************************************************************************/

    address mapleCoreStrategyV100Implementation;
    address mapleCoreStrategyV100Initializer;
    address mapleCoreStrategyFactory;

    /**************************************************************************************************************************************/
    /*** Health Checker Addresses                                                                                                       ***/
    /**************************************************************************************************************************************/

    address updatedProtocolHealthChecker      = 0xfb8F87D716ac3fC54f33664F51E3961bc2DD3EDb;
    address updatedOpenTermLoanHealthChecker  = 0xa2e3c1e3e2b8E2B8B5e3FF1d4c3b2A1f4e5d6C7d;
    address updatedFixedTermLoanHealthChecker = 0xb3f4d2c1E5a6B7c8d9E0F1A2b3C4D5E6f7A8b9C0;

    /**************************************************************************************************************************************/
    /*** syrupUSDG Addresses                                                                                                            ***/
    /**************************************************************************************************************************************/

    address syrupUSDGPool                   = 0x87b65C4aAFFA76881f9E96F3e7ED945ddFC3Cd7A;
    address syrupUSDGPoolManager            = 0x6c48CD22086F3Db3F23E7cEeDD5c429D93FF3327;
    address syrupUSDGOpenTermLoanManager    = 0x7bE9A1FA4CD69F7a077692d4AFA52bD09531920A;
    address syrupUSDGWithdrawalManagerQueue = 0xAf63C06970086d535F338565D77c5fA3bDC5fD79;
    address syrupUSDGPoolDelegateCover      = 0xFdc1b5A10f4da87b459dfc3bF1313b33a2F6bfA9;
    address syrupUSDGSyrupRouter            = 0x191ac16255f49F7C6cB2e3b2502064A805943849;

}
