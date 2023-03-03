// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Action }          from "./Action.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

contract FundLoanAction is Action, ProtocolActions {

    address public loan;
    address public poolManager;  // TODO: Is this still needed?

    constructor(
        uint256 timestamp_,
        string memory description_,
        address poolManager_,
        address loan_
    )
        Action(timestamp_, description_)
    {
        loan        = loan_;
        poolManager = poolManager_;
    }

    function act() external override {
        fundLoan(loan);
    }

}
