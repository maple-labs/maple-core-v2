// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { ProtocolHealthChecker } from "../tests/health-checkers/ProtocolHealthChecker.sol";

contract DeployHealthChecker is Script {

    function run() external {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        // Deploy the ProtocolHealthChecker contract.
        address protocolHealthChecker = address(new ProtocolHealthChecker());

        console.log("ProtocolHealthChecker deployed at: %s", protocolHealthChecker);

        vm.stopBroadcast();
    }

}
