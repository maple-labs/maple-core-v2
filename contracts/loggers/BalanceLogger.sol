// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20Like } from "../interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract BalanceLogger is Logger {

    address owner;

    IERC20Like asset;

    constructor(IERC20Like asset_, address owner_, string memory filepath_) Logger(filepath_) {
        asset = asset_;
        owner = owner_;
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](3);

        headers_[0] = "timestamp";
        headers_[1] = "balance";
        headers_[2] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](3);

        values_[0] = _formattedTime();
        values_[1] = convertUintToString(asset.balanceOf(owner));
        values_[2] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
