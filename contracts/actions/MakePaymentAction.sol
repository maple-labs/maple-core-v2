// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IERC20Like, ILoanLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract MakePaymentAction is Action {

    IERC20Like public asset;
    ILoanLike  public loan;

    constructor(uint256 timestamp_, string memory description_, ILoanLike loan_) Action(timestamp_, description_) {
        loan  = loan_;
        asset = IERC20Like(loan_.fundsAsset());
    }

    function act() external override {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getNextPaymentBreakdown();

        address borrower_ = loan.borrower();
        uint256 payment_  = principal_ + interest_ + fees_;

        vm.startPrank(borrower_);
        asset.mint(borrower_, payment_);
        asset.approve(address(loan), payment_);
        loan.makePayment(payment_);
        vm.stopPrank();
    }

}
