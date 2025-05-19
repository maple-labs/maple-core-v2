// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract UpgradeLoanTests is ProtocolUpgradeBase {

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22446028);

        upgradeProtocol();
    }

    function testFork_upgradeOTLs() external {
        for (uint256 i; i < allOpenTermLoans.length; i++) {
            assertTrue(IOpenTermLoan(allOpenTermLoans[i]).loanTermsAccepted());
        }
    }

}
