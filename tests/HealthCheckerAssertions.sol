// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../contracts/interfaces/Interfaces.sol";

import { console2 as console, Runner } from "../contracts/Runner.sol";

import { ProtocolHealthChecker } from "./health-checkers/ProtocolHealthChecker.sol";

contract HealthCheckerAssertions is Runner {

    function assertProtocolInvariants(address poolManager_, address healthChecker_) internal {
        ProtocolHealthChecker.Invariants memory results;

        results = ProtocolHealthChecker(healthChecker_).checkInvariants(poolManager_);

        assertTrue(results.fixedTermLoanManagerInvariantA);
        assertTrue(results.fixedTermLoanManagerInvariantB);
        assertTrue(results.fixedTermLoanManagerInvariantF);
        assertTrue(results.fixedTermLoanManagerInvariantI);
        assertTrue(results.fixedTermLoanManagerInvariantJ);
        assertTrue(results.fixedTermLoanManagerInvariantK);
        assertTrue(results.openTermLoanManagerInvariantE);
        assertTrue(results.openTermLoanManagerInvariantG);
        assertTrue(results.poolInvariantA);
        assertTrue(results.poolInvariantD);
        assertTrue(results.poolInvariantE);
        assertTrue(results.poolInvariantI);
        assertTrue(results.poolInvariantJ);
        assertTrue(results.poolInvariantK);
        assertTrue(results.poolManagerInvariantA);
        assertTrue(results.poolManagerInvariantB);
        assertTrue(results.withdrawalManagerCyclicalInvariantC);
        assertTrue(results.withdrawalManagerCyclicalInvariantD);
        assertTrue(results.withdrawalManagerCyclicalInvariantE);
        assertTrue(results.withdrawalManagerCyclicalInvariantM);
    }

}
