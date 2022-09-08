// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract PoolManagerLogger is Logger {

    IPoolManagerLike poolManager;

    constructor(IPoolManagerLike poolManager_, string memory filepath_) Logger(filepath_) {
        poolManager = poolManager_;
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](4);

        headers_[0] = "timestamp";
        headers_[1] = "totalAssets";
        headers_[2] = "unrealizedLosses";
        headers_[3] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](4);

        values_[0] = _formattedTime();
        values_[1] = convertUintToString(poolManager.totalAssets());
        values_[2] = convertUintToString(poolManager.unrealizedLosses());
        values_[3] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
