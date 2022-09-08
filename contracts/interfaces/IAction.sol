// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

interface IAction {

    // Performs the action.
    function act() external;

    // Returns a description of what the action does (used for logging purposes).
    function description() external view returns (string memory name_);

    // Defines at which time during the simulation this action should be performed.
    function timestamp() external view returns (uint256 timestamp_);

}
