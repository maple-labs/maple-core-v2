// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleLoan }             from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleLoanInitializer }  from "../modules/open-term-loan/contracts/proxy/MapleLoanInitializer.sol";
import { MapleLoanV202Migrator } from "../modules/open-term-loan/contracts/MapleLoanV202Migrator.sol";

import { MapleLoanManager }            from "../modules/open-term-loan-manager/contracts/MapleLoanManager.sol";
import { MapleLoanManagerInitializer } from "../modules/open-term-loan-manager/contracts/proxy/MapleLoanManagerInitializer.sol";

// NOTE: OTL / OTLM contracts only
contract RefinanceUpgradesDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        console.log("ETH_SENDER: ", ETH_SENDER);

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying loan...");

        // Deploy Initializer
        address loanInitializer = address(new MapleLoanInitializer());

        // Deploy Implementation
        address loanImplementation = address(new MapleLoan());

        // Deploy Migrator
        address loanMigrator = address(new MapleLoanV202Migrator());

        console.log("Loan implementation deployed at  ", loanImplementation);
        console.log("Loan initializer deployed at     ", loanInitializer);
        console.log("Loan migrator deployed at        ", loanMigrator);
        console.log("---------------------------------");

        console.log("Deploying loan manager...");

        // Deploy Initializer
        address loanManagerInitializer = address(new MapleLoanManagerInitializer());

        // Deploy Implementation
        address loanManagerImplementation = address(new MapleLoanManager());

        console.log("Loan manager implementation deployed at  ", loanManagerImplementation);
        console.log("Loan manager initializer deployed at     ", loanManagerInitializer);
        console.log("---------------------------------");

        vm.stopBroadcast();
    }

}
