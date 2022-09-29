// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IMapleLoan } from "../../../modules/loan/contracts/interfaces/IMapleLoan.sol";

contract SkimmerBase {

    IMapleLoan loan;

    constructor (address loan_) {
        loan = IMapleLoan(loan_);
    }

    function skim(address token_, address destination_) public virtual returns (uint256 skimmed_) {
        loan.skim(token_, destination_);
    }

}
