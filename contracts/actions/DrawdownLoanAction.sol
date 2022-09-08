// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { ILoanLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract DrawdownLoanAction is Action {

    ILoanLike loan;

    constructor(uint256 timestamp_, string memory description_, ILoanLike loan_) Action(timestamp_, description_) {
        loan = loan_;
    }

    function act() external override {
        vm.startPrank(loan.borrower());
        loan.drawdownFunds(loan.principal(), loan.borrower());
        vm.stopPrank();
    }

}
