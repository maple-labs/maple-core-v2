// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { AddressRegistry } from "../modules/address-registry/contracts/MapleAddressRegistry.sol";

import { MapleLoan as FixedTermLoan }                       from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanInitializer as FixedTermLoanInitializer } from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleLoanV5Migrator as FixedTermLoanV5Migrator }     from "../modules/fixed-term-loan/contracts/MapleLoanV5Migrator.sol";

import { LoanManagerInitializer as FTLMInitializer } from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerInitializer.sol";
import { LoanManager as FixedTermLoanManager }       from "../modules/fixed-term-loan-manager/contracts/LoanManager.sol";

import { MapleGlobals } from "../modules/globals/contracts/MapleGlobals.sol";

import { MapleLoan as OpenTermLoan }                       from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleLoanFactory as OpenTermLoanFactory }         from "../modules/open-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer as OpenTermLoanInitializer } from "../modules/open-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleRefinancer as OpenTermRefinancer }           from "../modules/open-term-loan/contracts/MapleRefinancer.sol";

import { LoanManager as OpenTermLoanManager }               from "../modules/open-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as OpenTermLoanManagerFactory } from "../modules/open-term-loan-manager/contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer as OTLMInitializer }        from "../modules/open-term-loan-manager/contracts/LoanManagerInitializer.sol";

import { PoolDeployer }           from "../modules/pool/contracts/PoolDeployer.sol";
import { PoolManager }            from "../modules/pool/contracts/PoolManager.sol";
import { PoolManagerInitializer } from "../modules/pool/contracts/proxy/PoolManagerInitializer.sol";

contract DeployOpenTermLoans is AddressRegistry, Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address newPoolDeployer = address(new PoolDeployer(mapleGlobalsV2Proxy));

        console.log("");
        console.log("Pool Deployer:", newPoolDeployer);

        // Globals
        address newGlobalsImplementation = address(new MapleGlobals());

        console.log("");
        console.log("Globals Implementation:", newGlobalsImplementation);

        // Pool Manager upgrades
        address newPoolManagerImplementation = address(new PoolManager());
        address newPoolManagerInitializer    = address(new PoolManagerInitializer());

        console.log("");
        console.log("PoolManager Implementation:", newPoolManagerImplementation);
        console.log("PoolManager Initializer:   ", newPoolManagerInitializer);

        // Fixed Term Loan upgrades
        address newFixedTermLoanImplementation = address(new FixedTermLoan());
        address newFixedTermLoanInitializer    = address(new FixedTermLoanInitializer());
        address newFixedTermLoanMigrator       = address(new FixedTermLoanV5Migrator());

        console.log("");
        console.log("FixedTermLoan Implementation:", newFixedTermLoanImplementation);
        console.log("FixedTermLoan Initializer:   ", newFixedTermLoanInitializer);
        console.log("FixedTermLoanMigrator:       ", newFixedTermLoanMigrator);

        // Fixed Term LoanManager upgrades
        address newFixedTermLoanManagerImplementation = address(new FixedTermLoanManager());
        address newFixedTermLoanManagerInitializer    = address(new FTLMInitializer());

        console.log("");
        console.log("FixedTermLoanManager Implementation:", newFixedTermLoanManagerImplementation);
        console.log("FixedTermLoanManager Initializer:   ", newFixedTermLoanManagerInitializer);

        // New contracts for Open Term LoanManager
        address openTermLoanManagerFactory        = address(new OpenTermLoanManagerFactory(mapleGlobalsV2Proxy));
        address openTermLoanManagerImplementation = address(new OpenTermLoanManager());
        address openTermLoanManagerInitializer    = address(new OTLMInitializer());

        console.log("");
        console.log("OpenTermLoanManagerFactory:        ", openTermLoanManagerFactory);
        console.log("OpenTermLoanManager Implementation:", openTermLoanManagerImplementation);
        console.log("OpenTermLoanManager Initializer:   ", openTermLoanManagerInitializer);

        // New contracts for Open Term Loan
        address openTermLoanFactory        = address(new OpenTermLoanFactory(mapleGlobalsV2Proxy));
        address openTermLoanInitializer    = address(new OpenTermLoanInitializer());
        address openTermLoanImplementation = address(new OpenTermLoan());
        address openTermLoanRefinancer     = address(new OpenTermRefinancer());

        console.log("");
        console.log("OpenTermLoanFactory:        ", openTermLoanFactory);
        console.log("OpenTermLoan Implementation:", openTermLoanImplementation);
        console.log("OpenTermLoan Initializer:   ", openTermLoanInitializer);
        console.log("OpenTermRefinancer:         ", openTermLoanRefinancer);

        vm.stopBroadcast();
    }

}
