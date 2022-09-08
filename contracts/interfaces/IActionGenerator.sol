// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IAction }      from "../interfaces/IAction.sol";
import { LoanScenario } from "../LoanScenario.sol";

interface IActionGenerator {

    // Generates all the actions for a given loan scenario.
    function generateActions(LoanScenario scenario_) external returns (IAction[] memory actions_);

}
