// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Runner } from "../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    /**************************************************************************************************************************************/
    /*** Upgrade Procedure                                                                                                              ***/
    /**************************************************************************************************************************************/

    function upgradeProtocol() internal {
        upgradeGovernorTimelock();
    }

    function upgradeGovernorTimelock() internal {
        proposer  = makeAddr("proposer");
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = governor;
        timelock  = deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin));
    }

}
