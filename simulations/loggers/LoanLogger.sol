// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20Like, IMapleLoan } from "../../contracts/interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract LoanLogger is Logger {

    IERC20Like internal asset;
    IMapleLoan internal loan;

    constructor(IMapleLoan loan_, string memory filepath_) Logger(filepath_) {
        loan  = loan_;
        asset = IERC20Like(loan_.fundsAsset());
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](6);

        headers_[0] = "timestamp";
        headers_[1] = "balance";
        headers_[2] = "principal";
        headers_[3] = "nextPaymentDueDate";
        headers_[4] = "paymentsRemaining";
        headers_[5] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](6);

        values_[0] = _formattedTime();
        values_[1] = convertUintToString(asset.balanceOf(address(loan)));
        values_[2] = convertUintToString(loan.principal());
        values_[3] = convertUintToString(loan.nextPaymentDueDate());
        values_[4] = convertUintToString(loan.paymentsRemaining());
        values_[5] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
