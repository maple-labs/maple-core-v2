// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistry as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistry.sol";

import { Test } from "../../contracts/Contracts.sol";

import { ProtocolHealthChecker } from "./ProtocolHealthChecker.sol";

contract HealthCheckerMainnetTests is AddressRegistry, Test {

    ProtocolHealthChecker protocolHealthChecker_;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17879220);

        protocolHealthChecker_ = new ProtocolHealthChecker();
    }

    function test_healthChecker_mainnet() public {
        _checkPool(mapleDirectUSDCPoolManager);
    }

    function _checkPool(address poolManager_) internal {
        ProtocolHealthChecker.Invariants memory results;

        results = protocolHealthChecker_.checkInvariants(poolManager_);

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
        assertTrue(results.withdrawalManagerInvariantC);
        assertTrue(results.withdrawalManagerInvariantD);
        assertTrue(results.withdrawalManagerInvariantE);
        assertTrue(results.withdrawalManagerInvariantM);
    }

}
