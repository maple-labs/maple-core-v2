// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

import {
    console2 as console,
    FixedTermLoan,
    FixedTermLoanManager,
    FixedTermRefinancer,
    PoolManager,
    OpenTermLoan,
    OpenTermLoanManager
} from "../../contracts/Contracts.sol";

import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "../health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";

contract LoanLifecycleTest is ProtocolUpgradeBase {

    function testForkFuzz_lifecycle_success(uint256 seed_) external {
        seed = seed_;

        _setUpAddresses();

        _activatePoolManager(_poolManager);

        deposit(_pool, makeAddr("lp"), 90_000_000e6);

        // Perform the upgrade
        _upgradeAndAssert();

        fuzzedSetup(10,10,10, seed_);

        // Assert the invariants
        _checkInvariants();

        payOffAllLoans();
    }

    function testForkFuzz_lifecycle_newAndOldLoans(uint256 seed_) external {
        seed = seed_;

        _setUpAddresses();

        _activatePoolManager(_poolManager);

        deposit(_pool, makeAddr("lp"), 90_000_000e6);

        // Create 3 loans of each type
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 1 days);
            createAndFundLoan(createSomeOpenTermLoan);
            vm.warp(block.timestamp + 1 days);
            createAndFundLoan(createSomeFixedTermLoan);
        }
        vm.warp(block.timestamp + 1 days);

        // Perform the upgrade
        _upgradeAndAssert();

        // Create remaining loans
        fuzzedSetup(7,7,10, seed);

        _checkInvariants();

        payOffAllLoans();
    }

    function _checkInvariants() internal {
        fixedTermLoanHC = new FixedTermLoanHealthChecker();
        openTermLoanHC  = new OpenTermLoanHealthChecker();

        // Use the deployed version for protocol health checker
        protocolHC = ProtocolHealthChecker(protocolHealthChecker);

        FixedTermLoanHealthChecker.Invariants memory FTLInvariants =
            fixedTermLoanHC.checkInvariants(address(_poolManager), getAllActiveFixedTermLoans());

        OpenTermLoanHealthChecker.Invariants memory OTLInvariants =
            openTermLoanHC.checkInvariants(address(_poolManager), getAllActiveOpenTermLoans());

        ProtocolHealthChecker.Invariants memory protocolInvariants = protocolHC.checkInvariants(address(_poolManager));

        assertFixedTermLoanHealthChecker(FTLInvariants);
        assertOpenTermLoanHealthChecker(OTLInvariants);
        assertProtocolHealthChecker(protocolInvariants);
    }

}
