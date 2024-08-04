// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleLoan as FixedTermLoan } from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoan as OpenTermLoan }  from "../modules/open-term-loan/contracts/MapleLoan.sol";

contract DeployQ32024Loans is Script {

    function run() external {
        address deployer = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(deployer);

        address fixedTermLoan = address(new FixedTermLoan());
        address openTermLoan  = address(new OpenTermLoan());

        console.log("FixedTermLoan deployed at: %s", fixedTermLoan);
        console.log("OpenTermLoan deployed at: %s ", openTermLoan);

        vm.stopBroadcast();
    }

}
