// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

// NOTE: Placeholder to test setup, we can remove this once we have a proper test suite for the upgrade.
contract UpgradeLoanTests is ProtocolUpgradeBase {

    uint256 start;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22446028);

        upgradeProtocol();

        start  = block.timestamp;
    }

    function testFork_upgradeOTLs() external {
        assertEq(block.timestamp, start);
    }

}
