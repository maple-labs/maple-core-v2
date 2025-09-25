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
    address syrupBitcoinPool;
    address syrupBitcoinPoolManager;

    address mapleWithdrawalManagerV200Implementation;
    address mapleWithdrawalManagerV200Initializer;
    address mapleWithdrawalManagerV200Migrator;

}
