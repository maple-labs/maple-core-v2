// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { CSVWriter } from "../modules/contract-test-utils/contracts/csv.sol";

import { IAction } from "./interfaces/IAction.sol";
import { ILogger } from "./interfaces/ILogger.sol";

import { ActionHandler } from "./ActionHandler.sol";

contract PoolSimulation is ActionHandler, CSVWriter {

    ILogger[] internal loggers;  // List of loggers used to output the state of the simulation during each snapshot and after each action.

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
            uint256 nextTimestamp_ = block.timestamp + 1 days;  // TODO: Make parameter

            // Round down the timestamp to the end of the simulation if it exceeds it.
            if (nextTimestamp_ > endTimestamp) nextTimestamp_ = endTimestamp;

            // Perform all actions up to and including the time of the snapshot.
            _act(nextTimestamp_);

            // Take the snapshot.
            _snapshot(nextTimestamp_);

            // If we are at the end, terminate the simulation.
            if (block.timestamp == endTimestamp) break;
        }

        // Store all logs permanently.
        _flush();
    }

    /*************************/
    /*** Utility Functions ***/
    /*************************/

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
        for (uint256 i; i < loggers.length; ++i) {
            addRow(loggers[i].filepath(), loggers[i].output(notes_));
        }
    }

    function _flush() internal {
        if (loggers.length > 0) {
            makeDir(loggers[0].filepath());
        }

        for (uint256 i; i < loggers.length; ++i) {
            writeFile(loggers[i].filepath());
        }
    }

}
