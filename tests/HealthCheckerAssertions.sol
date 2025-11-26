// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Runner } from "../contracts/Runner.sol";

import { FixedTermLoanHealthChecker } from "./health-checkers/FixedTermLoanHealthChecker.sol";
import { LPHealthChecker }            from "./health-checkers/LPHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "./health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "./health-checkers/ProtocolHealthChecker.sol";
import { SyrupBTCHealthChecker }      from "./health-checkers/SyrupBTCHealthChecker.sol";

contract HealthCheckerAssertions is Runner {

    function assertProtocolInvariants(address poolManager_, address healthChecker_) internal view {
        ProtocolHealthChecker.Invariants memory results;

        results = ProtocolHealthChecker(healthChecker_).checkInvariants(poolManager_);

        assertTrue(results.fixedTermLoanManagerInvariantA, "FixedTermLoanManagerInvariantA");
        assertTrue(results.fixedTermLoanManagerInvariantB, "FixedTermLoanManagerInvariantB");
        assertTrue(results.fixedTermLoanManagerInvariantF, "FixedTermLoanManagerInvariantF");
        assertTrue(results.fixedTermLoanManagerInvariantI, "FixedTermLoanManagerInvariantI");
        assertTrue(results.fixedTermLoanManagerInvariantJ, "FixedTermLoanManagerInvariantJ");
        assertTrue(results.fixedTermLoanManagerInvariantK, "FixedTermLoanManagerInvariantK");

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

        assertTrue(results.withdrawalManagerCyclicalInvariantC, "WithdrawalManagerCyclicalInvariantC");
        assertTrue(results.withdrawalManagerCyclicalInvariantD, "WithdrawalManagerCyclicalInvariantD");
        assertTrue(results.withdrawalManagerCyclicalInvariantE, "WithdrawalManagerCyclicalInvariantE");
        assertTrue(results.withdrawalManagerCyclicalInvariantM, "WithdrawalManagerCyclicalInvariantM");
        assertTrue(results.withdrawalManagerCyclicalInvariantN, "WithdrawalManagerCyclicalInvariantN");

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

    function assertFixedTermLoanInvariants(address poolManager_, address[] memory loans_, address healthChecker_) internal view {
        FixedTermLoanHealthChecker.Invariants memory results;

        results = FixedTermLoanHealthChecker(healthChecker_).checkInvariants(poolManager_, loans_);

        assertTrue(results.fixedTermLoanInvariantA, "FixedTermLoanInvariantA");
        assertTrue(results.fixedTermLoanInvariantB, "FixedTermLoanInvariantB");
        assertTrue(results.fixedTermLoanInvariantC, "FixedTermLoanInvariantC");

        assertTrue(results.fixedTermLoanManagerInvariantD, "FixedTermLoanManagerInvariantD");
        assertTrue(results.fixedTermLoanManagerInvariantE, "FixedTermLoanManagerInvariantE");
        assertTrue(results.fixedTermLoanManagerInvariantM, "FixedTermLoanManagerInvariantM");
        assertTrue(results.fixedTermLoanManagerInvariantN, "FixedTermLoanManagerInvariantN");
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

    function assertSyrupBTCInvariants(
        address healthChecker_,
        address bitcoinRouter_,
        address[] memory depositAssets_
    )
        internal view
    {
        SyrupBTCHealthChecker.Invariants memory results;

        results = SyrupBTCHealthChecker(healthChecker_).checkInvariants(bitcoinRouter_, depositAssets_);

        assertTrue(results.syrupBTCInvariantA, "SyrupBTCInvariantA");
        assertTrue(results.syrupBTCInvariantB, "SyrupBTCInvariantB");
        assertTrue(results.syrupBTCInvariantC, "SyrupBTCInvariantC");
        assertTrue(results.syrupBTCInvariantD, "SyrupBTCInvariantD");
        assertTrue(results.syrupBTCInvariantE, "SyrupBTCInvariantE");
        assertTrue(results.syrupBTCInvariantF, "SyrupBTCInvariantF");
        assertTrue(results.syrupBTCInvariantG, "SyrupBTCInvariantG");

        assertTrue(results.poolInvariantA, "PoolInvariantA");
        assertTrue(results.poolInvariantD, "PoolInvariantD");
        assertTrue(results.poolInvariantE, "PoolInvariantE");
        assertTrue(results.poolInvariantI, "PoolInvariantI");
        assertTrue(results.poolInvariantJ, "PoolInvariantJ");
        assertTrue(results.poolInvariantK, "PoolInvariantK");

        assertTrue(results.poolManagerInvariantA, "PoolManagerInvariantA");
        assertTrue(results.poolManagerInvariantB, "PoolManagerInvariantB");

        assertTrue(results.poolPermissionManagerInvariantA, "PoolPermissionManagerInvariantA");

        assertTrue(results.withdrawalManagerQueueInvariantA, "WithdrawalManagerQueueInvariantA");
        assertTrue(results.withdrawalManagerQueueInvariantB, "WithdrawalManagerQueueInvariantB");
        assertTrue(results.withdrawalManagerQueueInvariantD, "WithdrawalManagerQueueInvariantD");
        assertTrue(results.withdrawalManagerQueueInvariantE, "WithdrawalManagerQueueInvariantE");
        assertTrue(results.withdrawalManagerQueueInvariantF, "WithdrawalManagerQueueInvariantF");
        assertTrue(results.withdrawalManagerQueueInvariantH, "WithdrawalManagerQueueInvariantH");
    }

}
