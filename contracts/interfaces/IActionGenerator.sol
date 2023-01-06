// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAction } from "../interfaces/IAction.sol";

import { LoanScenario } from "../LoanScenario.sol";

interface IActionGenerator {

    // Generates all the actions for a given loan scenario.
    function generateActions(LoanScenario scenario_) external returns (IAction[] memory actions_);

}
