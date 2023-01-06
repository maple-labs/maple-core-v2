// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { ILogger } from "../interfaces/ILogger.sol";

abstract contract Logger is ILogger, TestUtils {

    string internal constant NULL = "NULL";

    uint256 internal immutable START = block.timestamp;

    string public override filepath;

    constructor(string memory filepath_) {
        filepath = filepath_;
    }

    function _formattedTime() internal view returns (string memory formattedTime_) {
        formattedTime_ = string(abi.encodePacked(
            convertUintToString((block.timestamp - START) / 1 days),
            ".",
            convertUintToString((block.timestamp - START) % 1 days / 0.01 days)
        ));
    }

    function convertUintToSixDecimalString(uint256 value, uint256 precision) internal pure returns (string memory numberString) {
        uint256 intAmount   = value / precision;
        uint256 centsAmount = value * 1e6 / precision % 1e6;

        return string(abi.encodePacked(convertUintToString(intAmount), ".", _prependZerosToSixDecimalString(convertUintToString(centsAmount))));
    }

    function _prependZerosToSixDecimalString(string memory value_) internal pure returns (string memory value) {
        uint256 length = bytes(value_).length;

        if (length == 6) {
            return value_;
        }

        uint256 zeros = 6 - length;
        string memory zerosString;

        if (zeros == 1) {
            zerosString = "0";
        } else if (zeros == 2) {
            zerosString = "00";
        } else if (zeros == 3) {
            zerosString = "000";
        } else if (zeros == 4) {
            zerosString = "0000";
        } else if (zeros == 5) {
            zerosString = "00000";
        } else {
            zerosString = "000000";
        }

        return string(abi.encodePacked(zerosString, value_));
    }

}
