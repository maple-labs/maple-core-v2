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
    /*** Modular Release - Deployed Contracts                                                                                           ***/
    /**************************************************************************************************************************************/

    address public allocationStrategyFactory;
    address public allocationStrategyV100Implementation;
    address public allocationStrategyV100Initializer;
    address public globalsV500Implementation;
    address public liquidityRouterV100;
    address public modularAaveStrategyFactory;
    address public modularAaveStrategyV100Implementation;
    address public modularAaveStrategyV100Initializer;
    address public modularSkyStrategyFactory;
    address public modularSkyStrategyV100Implementation;
    address public modularSkyStrategyV100Initializer;
    address public poolDeployerV500;
    address public poolManagerV500Implementation;
    address public poolManagerV500Initializer;
    address public poolManagerV500Migrator;
    address public strategyDeployerV100;
    address public strategyManagerFactory;
    address public strategyManagerV100Implementation;
    address public strategyManagerV100Initializer;
    address public withdrawalManagerQueueV201Implementation;
    address public withdrawalManagerQueueV201Initializer;

    /**************************************************************************************************************************************/
    /*** Modular Release - Strategy Delegates                                                                                           ***/
    /**************************************************************************************************************************************/

    // TODO: Replace these with real addresses when they are known.
    address aaveStrategyUSDCDelegate = makeAddr("aaveStrategyUSDCDelegate");
    address aaveStrategyUSDTDelegate = makeAddr("aaveStrategyUSDTDelegate");
    address aaveStrategyUSDGDelegate = makeAddr("aaveStrategyUSDGDelegate");
    address skyStrategyUSDCDelegate  = makeAddr("skyStrategyUSDCDelegate");
    address lpDexUSDCDelegate        = makeAddr("lpDexUSDCDelegate");
    address crossPoolUSDCDelegate    = makeAddr("crossPoolUSDCDelegate");
    address tBillsUSDCDelegate       = makeAddr("tBillsUSDCDelegate");
    address pyusdUSDCDelegate        = makeAddr("pyusdUSDCDelegate");
    address spreadsUSDTDelegate      = makeAddr("spreadsUSDTDelegate");
    address lpDexUSDTDelegate        = makeAddr("lpDexUSDTDelegate");
    address crossPoolUSDTDelegate    = makeAddr("crossPoolUSDTDelegate");
    address tBillsUSDTDelegate       = makeAddr("tBillsUSDTDelegate");
    address pyusdUSDTDelegate        = makeAddr("pyusdUSDTDelegate");
    address lpDexUSDGDelegate        = makeAddr("lpDexUSDGDelegate");
    address crossPoolUSDGDelegate    = makeAddr("crossPoolUSDGDelegate");
    address tBillsUSDGDelegate       = makeAddr("tBillsUSDGDelegate");
    address pyusdUSDGDelegate        = makeAddr("pyusdUSDGDelegate");

    /**************************************************************************************************************************************/
    /*** Modular Release - Deployed Strategies                                                                                          ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Modular Release - Managed Wallets                                                                                              ***/
    /**************************************************************************************************************************************/

    // TODO: Replace these with real addresses when they are known.
    address lpDexUSDCManagedWallet     = makeAddr("lpDexUSDCManagedWallet");
    address crossPoolUSDCManagedWallet = makeAddr("crossPoolUSDCManagedWallet");
    address tBillsUSDCManagedWallet    = makeAddr("tBillsUSDCManagedWallet");
    address pyusdUSDCManagedWallet     = makeAddr("pyusdUSDCManagedWallet");
    address spreadsUSDTManagedWallet   = makeAddr("spreadsUSDTManagedWallet");
    address lpDexUSDTManagedWallet     = makeAddr("lpDexUSDTManagedWallet");
    address crossPoolUSDTManagedWallet = makeAddr("crossPoolUSDTManagedWallet");
    address tBillsUSDTManagedWallet    = makeAddr("tBillsUSDTManagedWallet");
    address pyusdUSDTManagedWallet     = makeAddr("pyusdUSDTManagedWallet");
    address lpDexUSDGManagedWallet     = makeAddr("lpDexUSDGManagedWallet");
    address crossPoolUSDGManagedWallet = makeAddr("crossPoolUSDGManagedWallet");
    address tBillsUSDGManagedWallet    = makeAddr("tBillsUSDGManagedWallet");
    address pyusdUSDGManagedWallet     = makeAddr("pyusdUSDGManagedWallet");

}
