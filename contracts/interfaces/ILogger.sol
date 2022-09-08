// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

interface ILogger {

    // Returns the path where the output of the logger should be written.
    function filepath() external view returns (string memory filepath_);

    // Returns the CSV headers of the logger.
    function headers() external view returns (string[] memory headers_);

    // Returns the current values of the states that the logger is monitoring.
    function output(string memory notes_) external view returns (string[] memory values_);

}
