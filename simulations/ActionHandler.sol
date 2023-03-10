// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { IAction } from "./interfaces/IAction.sol";

contract ActionHandler is TestUtils {

    uint256 internal actionIndex;   // Index of the next action that will be performed.
    uint256 internal endTimestamp;  // Time when the simulation ends (inclusive).

    IAction[] internal actions;  // Actions that will be performed during the simulation (will be sorted ascending by timestamp).

    function add(IAction action_) public {
        actions.push(action_);
    }

    function add(IAction[] memory actions_) public {
        for (uint256 i; i < actions_.length; ++i) {
            actions.push(actions_[i]);
        }
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function _sort() internal {
        require(actions.length != 0, "NO_ACTIONS");

        // NOTE: Sorting algorithm should be stable to avoid issues with duplicate timestamps.
        for (uint256 i; i < actions.length - 1; ++i) {
            for (uint256 j = 0; j < actions.length - 1 - i; ++j) {
                if (actions[j].timestamp() > actions[j + 1].timestamp()) {
                    ( actions[j], actions[j + 1] ) = ( actions[j + 1], actions[j] );
                }
            }
        }

        // Set the end of the simulation to the time of the latest action, plus an extra 10 days.
        endTimestamp = actions[actions.length - 1].timestamp() + 10 days;
    }

}
