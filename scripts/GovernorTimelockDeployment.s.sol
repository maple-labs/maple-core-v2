// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { GovernorTimelock } from "../modules/globals/contracts/GovernorTimelock.sol";

// TODO: Update script with correctly assigned addresses once confirmed with Matt
contract GovernorTimelockDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        console.log("ETH_SENDER: ", ETH_SENDER);

        vm.startBroadcast(ETH_SENDER);

        console.log("Governor Timelock...");

        address tokenWithdrawer = governor;
        address proposer        = governor;
        address executor        = operationalAdmin;
        address canceller       = securityAdmin;
        address roleAdmin       = governor;

        // Deploy GovernorTimelock
        address governorTimelock = address(new GovernorTimelock(tokenWithdrawer, proposer, executor, canceller, roleAdmin));

        console.log("Governor Timelock deployed at:", governorTimelock);
        console.log("---------------------------------");

        vm.stopBroadcast();
    }

}
