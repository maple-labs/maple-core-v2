// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { ProtocolHealthChecker }     from "../tests/health-checkers/ProtocolHealthChecker.sol";
import { OpenTermLoanHealthChecker } from "../tests/health-checkers/OpenTermLoanHealthChecker.sol";

contract DeployHealthChecker is Script {

    function run() external {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        // Deploy the ProtocolHealthChecker contract.
        address protocolHealthChecker = address(new ProtocolHealthChecker());

        console.log("ProtocolHealthChecker deployed at: %s", protocolHealthChecker);

        // Deploy the OpenTermLoanHealthChecker contract.
        address openTermLoanHealthChecker = address(new OpenTermLoanHealthChecker());

        console.log("OpenTermLoanHealthChecker deployed at: %s", openTermLoanHealthChecker);

        vm.stopBroadcast();
    }

}
