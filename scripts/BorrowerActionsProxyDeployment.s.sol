// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { NonTransparentProxy } from "../modules/syrup-utils/modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

contract BorrowerActionsProxyDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER       = vm.envAddress("ETH_SENDER");
        address BORROWER_ACTIONS = vm.envAddress("BORROWER_ACTIONS");

        console.log("ETH_SENDER:       ", ETH_SENDER);
        console.log("BORROWER_ACTIONS: ", BORROWER_ACTIONS);

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying MapleBorrowerActions NTP...");

        address borrowerActions = address(new NonTransparentProxy(securityAdmin, BORROWER_ACTIONS));

        console.log("MapleBorrowerActions Proxy: ", borrowerActions);

        vm.stopBroadcast();
    }

}
