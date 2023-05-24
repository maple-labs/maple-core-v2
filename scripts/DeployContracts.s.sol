// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

// TODO: Get all of these form the Contracts.sol "index".
import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleLoan as FixedTermLoan }                       from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanInitializer as FixedTermLoanInitializer } from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleLoanV5Migrator as FixedTermLoanV5Migrator }   from "../modules/fixed-term-loan/contracts/MapleLoanV5Migrator.sol";
import { Refinancer as FixedTermRefinancerV2 }              from "../modules/fixed-term-loan/contracts/Refinancer.sol";

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

import { UpgradeAddressRegistry as AddressRegistry } from "../tests/protocol-upgrade/UpgradeAddressRegistry.sol";

contract DeployContracts is AddressRegistry, Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Fixed Term Loan upgrades
        fixedTermLoanImplementationV500 = address(new FixedTermLoan());
        fixedTermLoanInitializerV500    = address(new FixedTermLoanInitializer());
        fixedTermLoanMigratorV500       = address(new FixedTermLoanV5Migrator());
        fixedTermRefinancerV2           = address(new FixedTermRefinancerV2());

        console.log("");
        console.log("FixedTermLoan Implementation:", fixedTermLoanImplementationV500);
        console.log("FixedTermLoan Initializer:   ", fixedTermLoanInitializerV500);
        console.log("FixedTermLoan Migrator:      ", fixedTermLoanMigratorV500);
        console.log("FixedTermRefinancer:         ", fixedTermRefinancerV2);

        // Fixed Term LoanManager upgrades
        fixedTermLoanManagerImplementationV300 = address(new FixedTermLoanManager());
        fixedTermLoanManagerInitializerV300    = address(new FTLMInitializer());

        console.log("");
        console.log("FixedTermLoanManager Implementation:", fixedTermLoanManagerImplementationV300);
        console.log("FixedTermLoanManager Initializer:   ", fixedTermLoanManagerInitializerV300);

        // Globals
        globalsImplementationV2 = address(new MapleGlobals());

        console.log("");
        console.log("Globals Implementation:", globalsImplementationV2);

        // New contracts for Open Term Loan
        openTermLoanFactory            = address(new OpenTermLoanFactory(mapleGlobalsProxy));
        openTermLoanImplementationV100 = address(new OpenTermLoan());
        openTermLoanInitializerV100    = address(new OpenTermLoanInitializer());
        openTermRefinancerV1           = address(new OpenTermRefinancer());

        console.log("");
        console.log("OpenTermLoanFactory:        ", openTermLoanFactory);
        console.log("OpenTermLoan Implementation:", openTermLoanImplementationV100);
        console.log("OpenTermLoan Initializer:   ", openTermLoanInitializerV100);
        console.log("OpenTermRefinancer:         ", openTermRefinancerV1);

        // New contracts for Open Term LoanManager
        openTermLoanManagerFactory            = address(new OpenTermLoanManagerFactory(mapleGlobalsProxy));
        openTermLoanManagerImplementationV100 = address(new OpenTermLoanManager());
        openTermLoanManagerInitializerV100    = address(new OTLMInitializer());

        console.log("");
        console.log("OpenTermLoanManagerFactory:        ", openTermLoanManagerFactory);
        console.log("OpenTermLoanManager Implementation:", openTermLoanManagerImplementationV100);
        console.log("OpenTermLoanManager Initializer:   ", openTermLoanManagerInitializerV100);

        // New Pool Deployer contract
        poolDeployerV2 = address(new PoolDeployer(mapleGlobalsProxy));

        console.log("");
        console.log("Pool Deployer:", poolDeployerV2);

        // New contracts for Pool Manager
        poolManagerImplementationV200 = address(new PoolManager());

        console.log("");
        console.log("PoolManager Implementation:", poolManagerImplementationV200);

        vm.stopBroadcast();
    }

}
