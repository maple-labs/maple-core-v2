// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IMapleLoan } from "../../../modules/loan/contracts/interfaces/IMapleLoan.sol";

contract BorrowerBase {

    IMapleLoan loan;

    constructor (address loan_) {
        loan = IMapleLoan(loan_);
    }

    function acceptBorrower() public virtual {
        loan.acceptBorrower();
    }

    function closeLoan(uint256 amount_) public virtual returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        return loan.closeLoan(amount_);
    }

    function drawdownFunds(uint256 amount_, address destination_) public virtual returns (uint256 collateralPosted_) {
        return loan.drawdownFunds(amount_, destination_);
    }

    function fundLoan(address lender_) public virtual returns (uint256 fundsLent_) {
        return loan.fundLoan(lender_);
    }

    function makePayment(uint256 amount_) public virtual returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        return loan.makePayment(amount_);
    }

    function postCollateral(uint256 amount_) public virtual returns (uint256 collateralPosted_) {
        return loan.postCollateral(amount_);
    }

    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) public virtual returns (bytes32 refinanceCommitment_) {
        return loan.proposeNewTerms(refinancer_, deadline_, calls_);
    }

    function removeCollateral(uint256 amount_, address destination_) public virtual {
        loan.removeCollateral(amount_, destination_);
    }

    function returnFunds(uint256 amount_) public virtual returns (uint256 fundsReturned_) {
        return loan.returnFunds(amount_);
    }

    function setPendingBorrower(address pendingBorrower_) public virtual {
        loan.setPendingBorrower(pendingBorrower_);
    }

    function upgrade(uint256 toVersion_, bytes calldata arguments_) public virtual {
        loan.upgrade(toVersion_, arguments_);
    }

}
