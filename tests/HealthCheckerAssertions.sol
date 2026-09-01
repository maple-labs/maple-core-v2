// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Runner } from "../contracts/Runner.sol";

import { LPHealthChecker }            from "./health-checkers/LPHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "./health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "./health-checkers/ProtocolHealthChecker.sol";

contract HealthCheckerAssertions is Runner {

    function assertProtocolInvariants(address poolManager_, address healthChecker_, address[] memory manualRedeemers_) internal view {
        ProtocolHealthChecker.Invariants memory results;

        results = ProtocolHealthChecker(healthChecker_).checkInvariants(poolManager_, manualRedeemers_);

        assertTrue(results.openTermLoanManagerInvariantE, "OpenTermLoanManagerInvariantE");
        assertTrue(results.openTermLoanManagerInvariantG, "OpenTermLoanManagerInvariantG");

        assertTrue(results.poolInvariantA, "PoolInvariantA");
        assertTrue(results.poolInvariantD, "PoolInvariantD");
        assertTrue(results.poolInvariantE, "PoolInvariantE");
        assertTrue(results.poolInvariantI, "PoolInvariantI");
        assertTrue(results.poolInvariantJ, "PoolInvariantJ");
        assertTrue(results.poolInvariantK, "PoolInvariantK");

        assertTrue(results.poolManagerInvariantA, "PoolManagerInvariantA");
        assertTrue(results.poolManagerInvariantB, "PoolManagerInvariantB");

        assertTrue(results.withdrawalManagerQueueInvariantA, "WithdrawalManagerQueueInvariantA");
        assertTrue(results.withdrawalManagerQueueInvariantB, "WithdrawalManagerQueueInvariantB");
        assertTrue(results.withdrawalManagerQueueInvariantD, "WithdrawalManagerQueueInvariantD");
        assertTrue(results.withdrawalManagerQueueInvariantE, "WithdrawalManagerQueueInvariantE");
        assertTrue(results.withdrawalManagerQueueInvariantF, "WithdrawalManagerQueueInvariantF");

        assertTrue(results.strategiesInvariantA, "StrategiesInvariantA");
        assertTrue(results.strategiesInvariantB, "StrategiesInvariantB");
        assertTrue(results.strategiesInvariantC, "StrategiesInvariantC");
        assertTrue(results.strategiesInvariantD, "StrategiesInvariantD");
        assertTrue(results.strategiesInvariantE, "StrategiesInvariantE");
        assertTrue(results.strategiesInvariantF, "StrategiesInvariantF");
        assertTrue(results.strategiesInvariantG, "StrategiesInvariantG");
    }

    function assertOpenTermLoanInvariants(address poolManager_, address[] memory loans_, address healthChecker_) internal view {
        OpenTermLoanHealthChecker.Invariants memory results;

        results = OpenTermLoanHealthChecker(healthChecker_).checkInvariants(poolManager_, loans_);

        assertTrue(results.openTermLoanInvariantA, "OpenTermLoanInvariantA");
        assertTrue(results.openTermLoanInvariantB, "OpenTermLoanInvariantB");
        assertTrue(results.openTermLoanInvariantC, "OpenTermLoanInvariantC");
        assertTrue(results.openTermLoanInvariantD, "OpenTermLoanInvariantD");
        assertTrue(results.openTermLoanInvariantE, "OpenTermLoanInvariantE");
        assertTrue(results.openTermLoanInvariantF, "OpenTermLoanInvariantF");
        assertTrue(results.openTermLoanInvariantG, "OpenTermLoanInvariantG");
        assertTrue(results.openTermLoanInvariantH, "OpenTermLoanInvariantH");
        assertTrue(results.openTermLoanInvariantI, "OpenTermLoanInvariantI");

        assertTrue(results.openTermLoanManagerInvariantA, "OpenTermLoanManagerInvariantA");
        assertTrue(results.openTermLoanManagerInvariantB, "OpenTermLoanManagerInvariantB");
        assertTrue(results.openTermLoanManagerInvariantC, "OpenTermLoanManagerInvariantC");
        assertTrue(results.openTermLoanManagerInvariantD, "OpenTermLoanManagerInvariantD");
        assertTrue(results.openTermLoanManagerInvariantF, "OpenTermLoanManagerInvariantF");
        assertTrue(results.openTermLoanManagerInvariantH, "OpenTermLoanManagerInvariantH");
        assertTrue(results.openTermLoanManagerInvariantI, "OpenTermLoanManagerInvariantI");
        assertTrue(results.openTermLoanManagerInvariantJ, "OpenTermLoanManagerInvariantJ");
        assertTrue(results.openTermLoanManagerInvariantK, "OpenTermLoanManagerInvariantK");
    }

    function assertLPInvariants(address pool_, address[] memory lps_, address healthChecker_) internal view {
        LPHealthChecker.Invariants memory results;

        results = LPHealthChecker(healthChecker_).checkInvariants(pool_, lps_);

        assertTrue(results.poolInvariantB, "PoolInvariantB");
        assertTrue(results.poolInvariantG, "PoolInvariantG");

        assertTrue(results.withdrawalManagerCyclicalInvariantA, "WithdrawalManagerCyclicalInvariantA");
        assertTrue(results.withdrawalManagerCyclicalInvariantB, "WithdrawalManagerCyclicalInvariantB");
        assertTrue(results.withdrawalManagerCyclicalInvariantF, "WithdrawalManagerCyclicalInvariantF");
        assertTrue(results.withdrawalManagerCyclicalInvariantG, "WithdrawalManagerCyclicalInvariantG");
        assertTrue(results.withdrawalManagerCyclicalInvariantH, "WithdrawalManagerCyclicalInvariantH");
        assertTrue(results.withdrawalManagerCyclicalInvariantI, "WithdrawalManagerCyclicalInvariantI");
        assertTrue(results.withdrawalManagerCyclicalInvariantJ, "WithdrawalManagerCyclicalInvariantJ");
        assertTrue(results.withdrawalManagerCyclicalInvariantK, "WithdrawalManagerCyclicalInvariantK");
        assertTrue(results.withdrawalManagerCyclicalInvariantL, "WithdrawalManagerCyclicalInvariantL");

        assertTrue(results.withdrawalManagerQueueInvariantC, "WithdrawalManagerQueueInvariantC");
        assertTrue(results.withdrawalManagerQueueInvariantG, "WithdrawalManagerQueueInvariantG");
        assertTrue(results.withdrawalManagerQueueInvariantH, "WithdrawalManagerQueueInvariantH");
    }

}
