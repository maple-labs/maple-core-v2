// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanLike, IPoolLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract ImpairLoanAction is Action {

    address loan;

    IPoolManagerLike poolManager;

    constructor(
        uint256 timestamp_,
        string memory description_,
        IPoolManagerLike poolManager_,
        address loan_
    )
        Action(timestamp_, description_)
    {
        poolManager = poolManager_;
        loan        = loan_;
    }

    function act() external override {
        vm.startPrank(poolManager.poolDelegate());
        poolManager.impairLoan(loan);
        vm.stopPrank();
    }

}
