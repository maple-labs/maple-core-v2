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

        activatePoolManager(_poolManager);
        setLiquidityCap(_poolManager, 100_000_000e6);

        deposit(_pool, makeAddr("lp"), 90_000_000e6);

        // Perform the upgrade
        _upgradeAndAssert();

        fuzzedSetup(10,10,10, seed_);

        // Assert the invariants
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

        payOffAllLoans();
    }

}
