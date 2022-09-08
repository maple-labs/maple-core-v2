// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { CSVWriter } from "../modules/contract-test-utils/contracts/csv.sol";
import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { IAction } from "./interfaces/IAction.sol";
import { ILogger } from "./interfaces/ILogger.sol";

contract PoolSimulation is TestUtils, CSVWriter {

    uint256 actionIndex;    // Index of the next action that will be performed.
    uint256 simulationEnd;  // Time when the simulation ends (inclusive).

    IAction[] actions;  // Actions that will be performed during the simulation (will be sorted ascending by timestamp).
    ILogger[] loggers;  // List of loggers used to output the state of the simulation during each snapshot and after each action.

    function add(IAction action_) external {
        actions.push(action_);
    }

    function add(IAction[] memory actions_) external {
        for (uint256 i = 0; i < actions_.length; ++i) {
            actions.push(actions_[i]);
        }
    }

    function record(ILogger logger_) external {
        loggers.push(logger_);
        initCSV(logger_.filepath(), logger_.headers());
    }

    function run() external {
        // Sort all actions based on their timestamp.
        _sort();

        // Snapshot the initial state of the simulation.
        _snapshot(block.timestamp);

        while (true) {
            // Calculate when the next snapshot will be taken.
            uint256 nextTimestamp_ = block.timestamp + 1 days;

            // Round down the timestamp to the end of the simulation if it exceeds it.
            if (nextTimestamp_ > simulationEnd) nextTimestamp_ = simulationEnd;

            // Perform all actions up to and including the time of the snapshot.
            _act(nextTimestamp_);

            // Take the snapshot.
            _snapshot(nextTimestamp_);

            // If we are at the end, terminate the simulation.
            if (block.timestamp == simulationEnd) break;
        }

        // Store all logs permanently.
        _flush();
    }

    /*************************/
    /*** Utility Functions ***/
    /*************************/

    function _sort() internal {
        if (actions.length == 0) revert("No actions added");

        // NOTE: Sorting algorithm should be stable to avoid issues with duplicate timestamps.
        for (uint256 i = 0; i < actions.length - 1; ++i) {
            for (uint256 j = 0; j < actions.length - 1 - i; ++j) {
                if (actions[j].timestamp() > actions[j + 1].timestamp()) {
                    ( actions[j], actions[j + 1] ) = ( actions[j + 1], actions[j] );
                }
            }
        }

        // Set the end of the simulation to the time of the latest action, plus an extra 10 days.
        simulationEnd = actions[actions.length - 1].timestamp() + 10 days;
    }

    function _act(uint256 nextTimestamp_) internal {
        // Perform all actions that occur up to and including the given timestamp.
        while (actionIndex != actions.length) {
            IAction nextAction_ = actions[actionIndex];

            // Ignore invalid actions that were set to occur in the past.
            if (nextAction_.timestamp() < block.timestamp) {
                ++actionIndex;
                continue;
            }

            // If no more actions before the next timestamp exist, stop.
            if (nextAction_.timestamp() > nextTimestamp_) break;

            // Perform the action and take a snapshot of the state afterwards.
            _act(nextAction_);

            // Increment the counter to point to the next action.
            ++actionIndex;
        }
    }

    function _snapshot(uint256 timestamp_) internal {
        vm.warp(timestamp_);
        _log("");
    }

    function _act(IAction action_) internal {
        vm.warp(action_.timestamp());
        action_.act();
        _log(action_.description());
    }

    function _log(string memory notes_) internal {
        for (uint i = 0; i < loggers.length; ++i) {
            addRow(loggers[i].filepath(), loggers[i].output(notes_));
        }
    }

    function _flush() internal {
        for (uint i = 0; i < loggers.length; ++i) {
            writeFile(loggers[i].filepath());
        }
    }

}
