// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPool } from "../../contracts/interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract PoolLogger is Logger {

    IPool internal pool;

    constructor(IPool pool_, string memory filepath_) Logger(filepath_) {
        pool = pool_;
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](3);

        headers_[0] = "timestamp";
        headers_[1] = "totalSupply";
        headers_[2] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](3);

        values_[0] = _formattedTime();
        values_[1] = convertUintToString(pool.totalSupply());
        values_[2] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
