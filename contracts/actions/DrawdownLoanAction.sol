// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { ILoanLike, IERC20Like } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract DrawdownLoanAction is Action {

    ILoanLike public loan;

    constructor(uint256 timestamp_, string memory description_, ILoanLike loan_) Action(timestamp_, description_) {
        loan = loan_;
    }

    function act() external override {
        IERC20Like collateralAsset = IERC20Like(ILoanLike(loan).collateralAsset());

        vm.startPrank(loan.borrower());

        collateralAsset.mint(loan.borrower(),  loan.collateralRequired());
        collateralAsset.approve(address(loan), loan.collateralRequired());

        loan.drawdownFunds(loan.drawableFunds(), loan.borrower());
        vm.stopPrank();
    }

}
