// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { Action }          from "./Action.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

contract DrawdownLoanAction is Action, ProtocolActions {

    address public loan;

    constructor(uint256 timestamp_, string memory description_, address loan_) Action(timestamp_, description_) {
        loan = loan_;
    }

    function act() external override {
        drawdown(loan, IFixedTermLoan(loan).drawableFunds());
    }

}
