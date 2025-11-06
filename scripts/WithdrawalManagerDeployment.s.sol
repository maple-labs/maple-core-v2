// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleWithdrawalManager }             from "../modules/withdrawal-manager-queue/contracts/MapleWithdrawalManager.sol";
import { MapleWithdrawalManagerInitializer }  from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerInitializer.sol";
import { MapleWithdrawalManagerMigratorV200 } from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerMigratorV200.sol";

contract WithdrawalManagerDeployment is Script, MapleAddressRegistryETH {

    address withdrawalManagerImplementation;
    address withdrawalManagerInitializer;
    address withdrawalManagerMigrator;

    address deployer = vm.envAddress("ETH_SENDER");

    function run() public {
        console.log("Deployer:", deployer, "\n");

        vm.startBroadcast(deployer);

        withdrawalManagerImplementation = address(new MapleWithdrawalManager());
        withdrawalManagerInitializer    = address(new MapleWithdrawalManagerInitializer());
        withdrawalManagerMigrator       = address(new MapleWithdrawalManagerMigratorV200());

        vm.stopBroadcast();

        console.log("WithdrawalManager implementation (v200) deployed at:  ", withdrawalManagerImplementation);
        console.log("WithdrawalManager initializer (v200) deployed at:     ", withdrawalManagerInitializer);
        console.log("WithdrawalManager migrator (v100 -> v200) deployed at:", withdrawalManagerMigrator);
    }

}
