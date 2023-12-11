// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProtocolUpgradeBase }       from "../protocol-upgrade/ProtocolUpgradeBase.sol";
import { UpgradeAddressRegistryETH } from "../protocol-upgrade/UpgradeAddressRegistryETH.sol";

import { ProtocolHealthChecker } from "./ProtocolHealthChecker.sol";

import { OpenTermLoanHealthChecker } from "./OpenTermLoanHealthChecker.sol";

import { FixedTermLoanHealthChecker } from "./FixedTermLoanHealthChecker.sol";

// TODO: Update post upgrade to use AddressRegistry and Test for inheritance
contract HealthCheckerMainnetTests is ProtocolUpgradeBase, UpgradeAddressRegistryETH {

    ProtocolHealthChecker      protocolHealthChecker_;
    OpenTermLoanHealthChecker  openTermHC;
    FixedTermLoanHealthChecker fixedTermHC;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18723285);

        protocolHealthChecker_ = new ProtocolHealthChecker();
    }

    function upgradePools() internal {
        _performProtocolUpgrade();

        _upgradeToQueueWM(governor, globals, cashManagementUSDCPoolManager);

        _approveAndAddLpsToQueueWM(cashManagementUSDCPoolManager);
    }

    function testFork_healthChecker_mainnet() public {
        upgradePools();

        _checkPool(mapleDirectUSDCPoolManager);

        _checkPool(cashManagementUSDCPoolManager);
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
        assertTrue(results.poolPermissionManagerInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantC);
        assertTrue(results.withdrawalManagerCyclicalInvariantD);
        assertTrue(results.withdrawalManagerCyclicalInvariantE);
        assertTrue(results.withdrawalManagerCyclicalInvariantM);
        assertTrue(results.withdrawalManagerCyclicalInvariantN);
        assertTrue(results.withdrawalManagerQueueInvariantA);
        assertTrue(results.withdrawalManagerQueueInvariantB);
        assertTrue(results.withdrawalManagerQueueInvariantD);
        assertTrue(results.withdrawalManagerQueueInvariantE);
        assertTrue(results.withdrawalManagerQueueInvariantF);
        assertTrue(results.withdrawalManagerQueueInvariantI);
    }

}
