// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ILoanLike } from "../../../contracts/interfaces/Interfaces.sol";

contract SkimmerBase {

    ILoanLike loan;

    constructor (address loan_) {
        loan = ILoanLike(loan_);
    }

    function skim(address token_, address destination_) public virtual returns (uint256 skimmed_) {
        skimmed_ = loan.skim(token_, destination_);
    }

}
