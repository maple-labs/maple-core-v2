// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleBorrowerActions } from "../modules/syrup-utils/contracts/MapleBorrowerActions.sol";

contract BorrowerActionsDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        console.log("ETH_SENDER: ", ETH_SENDER);

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying MapleBorrowerActions Implementation...");

        address borrowerActionsImplementation= address(new MapleBorrowerActions());

        console.log("MapleBorrowerActions Implementation: ", borrowerActionsImplementation);

        vm.stopBroadcast();
    }

}
