// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    ILoanLike,
    ILoanManagerLike,
    IPoolManagerLike
} from "../interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract BusinessSimLogger is Logger {

    address poolDelegate;
    address treasury;

    IERC20Like       asset;
    ILoanManagerLike loanManager;
    IPoolManagerLike poolManager;

    constructor(
        address loanManager_,
        address poolDelegate_,
        address poolManager_,
        address treasury_,
        string memory filepath_
    )
        Logger(filepath_)
    {
        poolDelegate = poolDelegate_;
        treasury     = treasury_;

        poolManager = IPoolManagerLike(poolManager_);

        asset       = IERC20Like(poolManager.asset());
        loanManager = ILoanManagerLike(loanManager_);
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](11);

        headers_[0] = "Day";
        headers_[1] = "Outstanding Principal";
        headers_[2] = "Accrued Interest";
        headers_[3] = "Unrealized Losses";
        headers_[4] = "Cash";
        headers_[5] = "Pool Value";
        headers_[6] = "Pool Value w Unrealized Losses";
        headers_[7] = "Cover Balance";
        headers_[8] = "Treasury Balance";
        headers_[9] = "Pool Delegate Balance";
        headers_[10] = "Notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](11);

        values_[0] = _formattedTime();
        values_[1] = convertUintToSixDecimalString(loanManager.principalOut(),                                 1e6);
        values_[2] = convertUintToSixDecimalString(loanManager.getAccruedInterest(),                           1e6);
        values_[3] = convertUintToSixDecimalString(loanManager.unrealizedLosses(),                             1e6);
        values_[4] = convertUintToSixDecimalString(asset.balanceOf(poolManager.pool()),                        1e6);
        values_[5] = convertUintToSixDecimalString(poolManager.totalAssets(),                                  1e6);
        values_[6] = convertUintToSixDecimalString(poolManager.totalAssets() - loanManager.unrealizedLosses(), 1e6);
        values_[7] = convertUintToSixDecimalString(asset.balanceOf(poolManager.poolDelegateCover()),           1e6);
        values_[8] = convertUintToSixDecimalString(asset.balanceOf(treasury),                                  1e6);
        values_[9] = convertUintToSixDecimalString(asset.balanceOf(poolDelegate),                              1e6);
        values_[10] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
