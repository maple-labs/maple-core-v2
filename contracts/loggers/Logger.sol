// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { ILogger } from "../interfaces/ILogger.sol";

abstract contract Logger is ILogger, TestUtils {

    string  constant  NULL  = "NULL";
    uint256 immutable START = block.timestamp;

    string public override filepath;

    constructor(string memory filepath_) {
        filepath  = filepath_;
    }

    function _formattedTime() internal view returns (string memory formattedTime_) {
        formattedTime_ = string(abi.encodePacked(
            convertUintToString((block.timestamp - START) / 1 days),
            ".",
            convertUintToString((block.timestamp - START) % 1 days / 0.01 days)
        ));
    }

}
