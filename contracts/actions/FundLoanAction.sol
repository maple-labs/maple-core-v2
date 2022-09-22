// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { ILoanLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract FundLoanAction is Action {

    ILoanLike        public loan;
    IPoolManagerLike public poolManager;

    constructor(uint256 timestamp_, string memory description_, IPoolManagerLike poolManager_, ILoanLike loan_) Action(timestamp_, description_) {
        poolManager = poolManager_;
        loan        = loan_;
    }

    function act() external override {
        vm.startPrank(poolManager.poolDelegate());
        poolManager.fund(loan.principalRequested(), address(loan), poolManager.loanManagerList(0));
        vm.stopPrank();
    }

}
