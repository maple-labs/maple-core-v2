// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { ILoanManagerLike } from "../interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract LoanManagerLogger is Logger {

    ILoanManagerLike loanManager;

    constructor(ILoanManagerLike loanManager_, string memory filepath_) Logger(filepath_) {
        loanManager = loanManager_;
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](10);

        headers_[0] = "timestamp";
        headers_[1] = "domainStart";
        headers_[2] = "domainEnd";
        headers_[3] = "principalOut";
        headers_[4] = "issuanceRate";
        headers_[5] = "accruedInterest";
        headers_[6] = "accountedInterest";
        headers_[7] = "assetsUnderManagement";
        headers_[8] = "unrealizedLosses";
        headers_[9] = "notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](10);

        values_[0] = _formattedTime();
        values_[1] = convertUintToString(loanManager.domainStart());
        values_[2] = convertUintToString(loanManager.domainEnd());
        values_[3] = convertUintToString(loanManager.principalOut());
        values_[4] = convertUintToString(loanManager.issuanceRate());
        values_[5] = convertUintToString(loanManager.getAccruedInterest());
        values_[6] = convertUintToString(loanManager.accountedInterest());
        values_[7] = convertUintToString(loanManager.assetsUnderManagement());
        values_[8] = convertUintToString(loanManager.unrealizedLosses());
        values_[9] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
