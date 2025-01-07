// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleLoan as FixedTermLoan }                       from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanInitializer as FixedTermLoanInitializer } from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";

import { MapleLoan as OpenTermLoan }                       from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleLoanInitializer as OpenTermLoanInitializer } from "../modules/open-term-loan/contracts/MapleLoanInitializer.sol";

contract DelegateInitiatedLoansDeployment is Script {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying loans...");

        address fixedTermLoanImplementation = address(new FixedTermLoan());
        address fixedTermLoanInitializer    = address(new FixedTermLoanInitializer());

        address openTermLoanImplementation  = address(new OpenTermLoan());
        address openTermLoanInitializer     = address(new OpenTermLoanInitializer());

        console.log("Fixed term loan implementation: ", fixedTermLoanImplementation);
        console.log("Fixed term loan initializer:    ", fixedTermLoanInitializer);
        console.log("---------------------------------");

        console.log("Open term loan implementation:  ", openTermLoanImplementation);
        console.log("Open term loan initializer:     ", openTermLoanInitializer);
        console.log("---------------------------------");

        vm.stopBroadcast();
    }

}
