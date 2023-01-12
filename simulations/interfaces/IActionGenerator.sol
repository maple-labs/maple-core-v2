// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAction } from "./IAction.sol";

import { LoanScenario } from "../LoanScenario.sol";

interface IActionGenerator {

    // Generates all the actions for a given loan scenario.
    // TODO: should be interface or address as argument
    function generateActions(LoanScenario scenario_) external returns (IAction[] memory actions_);

}
