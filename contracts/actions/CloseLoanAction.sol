// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import {
    IERC20Like,
    ILoanLike,
    ILoanManagerLike,
    IPoolLike,
    IPoolManagerLike
} from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract CloseLoanAction is Action {

    IERC20Like asset;
    ILoanLike  loan;

    constructor(uint256 timestamp_, string memory description_, ILoanLike loan_) Action(timestamp_, description_) {
        asset = IERC20Like(loan_.fundsAsset());
        loan  = loan_;
    }

    function act() external override {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        address borrower_ = loan.borrower();
        uint256 payment_  = principal_ + interest_ + fees_;

        vm.startPrank(borrower_);
        asset.mint(borrower_, payment_);
        asset.approve(address(loan), payment_);
        loan.closeLoan(payment_);
        vm.stopPrank();
    }

}
