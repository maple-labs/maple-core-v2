// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFeeManager,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

contract FixedTermLoanHealthChecker {

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
     * Fixed Term Loan
        * Invariant A: collateral balance >= _collateral`
        * Invariant B: fundsAsset >= _drawableFunds`
        * Invariant C: `_collateral >= collateralRequired_ * (principal_ - drawableFunds_) / principalRequested_`

     * Fixed Term Loan Manager (non-liquidating)
        * Invariant D: totalPrincipal = ∑loan.principal()
        * Invariant E: issuanceRate = ∑issuanceRate(payment)
        * Invariant M: paymentDueDate[payment] = loan.paymentDueDate()
        * Invariant N: startDate[payment] <= loan.paymentDueDate() - loan.paymentInterval()

    *******************************************************************************************************************************/

    struct Invariants {
        bool fixedTermLoanInvariantA;
        bool fixedTermLoanInvariantB;
        bool fixedTermLoanInvariantC;
        bool fixedTermLoanManagerInvariantD;
        bool fixedTermLoanManagerInvariantE;
        bool fixedTermLoanManagerInvariantM;
        bool fixedTermLoanManagerInvariantN;
    }

    function checkInvariants(address poolManager_, address[] memory loans_) external view returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        // Assume indexes for FT/OT LMs are 0 and 1 respectively.
        address fixedTermLoanManager_ = poolManager.loanManagerList(0);

        invariants_.fixedTermLoanInvariantA = check_fixedTermLoan_invariant_A(loans_);
        invariants_.fixedTermLoanInvariantB = check_fixedTermLoan_invariant_B(loans_);
        invariants_.fixedTermLoanInvariantC = check_fixedTermLoan_invariant_C(loans_);

        invariants_.fixedTermLoanManagerInvariantD = check_fixedTermLoanManager_invariant_D(fixedTermLoanManager_, loans_);
        invariants_.fixedTermLoanManagerInvariantE = check_fixedTermLoanManager_invariant_E(fixedTermLoanManager_, loans_);
        invariants_.fixedTermLoanManagerInvariantM = check_fixedTermLoanManager_invariant_M(fixedTermLoanManager_, loans_);
        invariants_.fixedTermLoanManagerInvariantN = check_fixedTermLoanManager_invariant_N(fixedTermLoanManager_, loans_);
    }

    /******************************************************************************************************************************/
    /*** Fixed Term Loan Invariants                                                                                             ***/
    /******************************************************************************************************************************/

    function check_fixedTermLoan_invariant_A(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; i++) {
            IFixedTermLoan loan_ = IFixedTermLoan(loans_[i]);

            if (IERC20(loan_.collateralAsset()).balanceOf(loans_[i]) < loan_.collateral()) return false;
        }

        isMaintained_ = true;
    }

    function check_fixedTermLoan_invariant_B(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; i++) {
            IFixedTermLoan loan_ = IFixedTermLoan(loans_[i]);

            if (IERC20(loan_.fundsAsset()).balanceOf(loans_[i]) < loan_.drawableFunds()) return false;
        }

        isMaintained_ = true;
    }

    function check_fixedTermLoan_invariant_C(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; i++) {
            IFixedTermLoan loan       = IFixedTermLoan(loans_[i]);
            IFeeManager    feeManager = IFeeManager(loan.feeManager());

            // The loan is matured or repossessed, the invariant will underflow because delegateOriginationFee > 0
            if (loan.nextPaymentDueDate() == 0) break;

            // If the drawableFunds is greater than the current principal, no collateral is required.
            if (loan.drawableFunds() >= loan.principal()) break;

            uint256 originationFee_ = feeManager.getOriginationFees(address(loan), loan.principalRequested());

            uint256 fundedAmount = loan.principalRequested() - originationFee_;

            // If drawableFunds exactly equals the funded amount, assume funds haven't been drawn down.
            if (loan.drawableFunds() == fundedAmount) break;

            if (loan.collateral() < (loan.collateralRequired() *
                (loan.principal() - loan.drawableFunds()) + fundedAmount - 1) / fundedAmount) {
                return false;
            }
        }

        isMaintained_ = true;
    }

    /******************************************************************************************************************************/
    /*** Fixed Term Loan Manager Invariants                                                                                     ***/
    /******************************************************************************************************************************/

    function check_fixedTermLoanManager_invariant_D(
        address loanManager_,
        address[] memory loans_
    ) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        uint256 sumOfLoanPrincipal;

        for (uint256 i; i < loans_.length; i++) {
            sumOfLoanPrincipal += IFixedTermLoan(loans_[i]).principal();
        }

        isMaintained_ = IFixedTermLoanManager(loanManager_).principalOut() == sumOfLoanPrincipal;
    }

    function check_fixedTermLoanManager_invariant_E(
        address loanManager_,
        address[] memory loans_
    ) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        isMaintained_ = IFixedTermLoanManager(loanManager_).issuanceRate() == _getSumIssuanceRates(loanManager_, loans_);
    }

    function check_fixedTermLoanManager_invariant_M(
        address loanManager_,
        address[] memory loans_
    ) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; i++) {
            IFixedTermLoan loan               = IFixedTermLoan(loans_[i]);
            IFixedTermLoanManager loanManager = IFixedTermLoanManager(loanManager_);

            if (loan.isImpaired()) continue;

            ( , , , uint256 paymentDueDate, , , ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));

            if (paymentDueDate != loan.nextPaymentDueDate()) return false;
        }

        isMaintained_ = true;
    }

    function check_fixedTermLoanManager_invariant_N(
        address loanManager_,
        address[] memory loans_
    ) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; i++) {
            IFixedTermLoan loan               = IFixedTermLoan(loans_[i]);
            IFixedTermLoanManager loanManager = IFixedTermLoanManager(loanManager_);

            if (loan.isImpaired()) continue;

            ( , , uint256 startDate, , , , ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));

            if (startDate > loan.nextPaymentDueDate() - loan.paymentInterval()) return false;
        }

        isMaintained_ = true;
    }

    /******************************************************************************************************************************/
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function _getSumIssuanceRates(address loanManager_, address[] memory loans_) internal view returns (uint256 sumIssuanceRate_) {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(loanManager_);

        for (uint256 i = 0; i < loans_.length; i++) {
            ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loans_[i])));
            sumIssuanceRate_ += issuanceRate;

            if (IFixedTermLoan(loans_[i]).isImpaired()) {
                sumIssuanceRate_ -= issuanceRate;  // If the loan is impaired the issuance rate is 0
            }
        }
    }

}
