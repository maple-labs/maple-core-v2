// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleLoanFeeManager } from "../../contracts/interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract FeeManagerLogger is Logger {

    IMapleLoanFeeManager internal feeManager;

    constructor(IMapleLoanFeeManager feeManager_, string memory filepath_) Logger(filepath_) {
        feeManager = feeManager_;
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](2);

        headers_[0] = "timestamp";
        // TODO
        headers_[1] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](2);

        values_[0] = _formattedTime();
        // TODO
        values_[1] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
