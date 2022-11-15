// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IERC20Like, ILoanLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract RefinanceAction is Action {

    address refinancer;

    uint256 principalIncrease;
    uint256 returnFundAmount;

    bytes[] refinanceCalls;

    IERC20Like       public asset;
    ILoanLike        public loan;
    IPoolManagerLike public poolManager;


    constructor(
        uint256 timestamp_,
        string memory description_,
        ILoanLike loan_,
        IPoolManagerLike poolManager_,
        address refinancer_,
        uint256 principalIncrease_,
        uint256 returnFundAmount_,
        bytes[] memory calls_
    )
        Action(timestamp_, description_)
    {
        loan        = loan_;
        asset       = IERC20Like(loan_.fundsAsset());
        poolManager = poolManager_;

        refinancer   = refinancer_;

        principalIncrease = principalIncrease_;
        returnFundAmount  = returnFundAmount_;

        refinanceCalls = calls_;
    }

    function act() external override {
        address borrower_ = loan.borrower();
        vm.prank(borrower_);
        loan.proposeNewTerms(refinancer, block.timestamp + 1, refinanceCalls);

        // Pay any additional fees if principal is increased.
        if (principalIncrease > 0) {
            asset.mint(borrower_, returnFundAmount);
            asset.approve(address(loan), returnFundAmount);
            loan.returnFunds(returnFundAmount);
        }

        vm.prank(poolManager.poolDelegate());
        poolManager.acceptNewTerms(address(loan), refinancer, block.timestamp + 1, refinanceCalls, principalIncrease);
    }

}
