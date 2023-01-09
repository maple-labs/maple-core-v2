// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleLoan } from "../../../modules/loan-v400/contracts/interfaces/IMapleLoan.sol";

contract SkimmerBase {

    IMapleLoan internal loan;

    constructor (address loan_) {
        loan = IMapleLoan(loan_);
    }

    function skim(address token_, address destination_) public virtual returns (uint256 skimmed_) {
        skimmed_ = loan.skim(token_, destination_);
    }

}
