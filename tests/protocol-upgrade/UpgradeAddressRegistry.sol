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
    /*** syrupBTC Procedure Addresses                                                                                                   ***/
    /**************************************************************************************************************************************/

    address assetControllerImplementation;
    address assetPriceOracleImplementation;
    address bitcoinRouterImplementation;
    address bitcoinStrategyImplementation;
    address compositeTokenImplementation;

    address assetControllerInitializer;
    address bitcoinRouterInitializer;
    address bitcoinStrategyInitializer;
    address compositeTokenInitializer;

    address assetControllerProxy;
    address assetPriceOracleProxy;
    address bitcoinRouterProxy;
    address compositeTokenProxy;

    address bitcoinStrategyFactory;
    address bitcoinStrategy1;
    address bitcoinStrategy2;
    address bitcoinStrategy3;
    address syrupBitcoinPool;
    address syrupBitcoinPoolManager;

    address mapleWithdrawalManagerV200Implementation;
    address mapleWithdrawalManagerV200Initializer;
    address mapleWithdrawalManagerV200Migrator;

    address syrupBitcoinPoolDelegate = 0x7F21a3C90567B86417a386d52232B79381563408;

    address bitcoinStrategy1Manager = 0x0DcD6029374bAE21074214834bB0DedD920A0C93;
    address bitcoinStrategy2Manager = 0x4041b0d75e159095365034B28e3b9De0712E1475;
    address bitcoinStrategy3Manager = 0x8f0D8e61dc9D604E6f4147a00994b40Df9d6F565;

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Upgrade Addresses                                                                                           ***/
    /**************************************************************************************************************************************/

    address[] withdrawalManagerQueuesToUpgrade = [
        cashUSDCWithdrawalManagerQueue,
        blueChipSecuredUSDCWithdrawalManagerQueue,
        highYieldCorpUSDCWithdrawalManagerQueue,
        highYieldCorpWETHWithdrawalManagerQueue,
        securedLendingUSDCWithdrawalManagerQueue,
        LendAndLongUSDC1WithdrawalManagerQueue,
        LendAndLongUSDC2WithdrawalManagerQueue,
        syrupUSDCWithdrawalManagerQueue,
        syrupUSDTWithdrawalManagerQueue
    ];

    /**************************************************************************************************************************************/
    /*** Core Strategy Deployment Addresses                                                                                             ***/
    /**************************************************************************************************************************************/

    address mapleCoreStrategyV100Implementation;
    address mapleCoreStrategyV100Initializer;
    address mapleCoreStrategyFactory;

}
