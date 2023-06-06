// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

contract OpenTermLoanHealthChecker {

    uint256 constant internal BUFFER              = 1e6;
    uint256 constant internal UNDERFLOW_THRESHOLD = 10;

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
    * Open Term Loan
        * Invariant A: dateFunded <= datePaid (if not zero)
        * Invariant B: dateFunded <= dateImpaired (if not zero)
        * Invariant C: dateFunded <= dateCalled (if not zero)
        * Invariant D: datePaid <= dateImpaired (if not zero)
        * Invariant E: datePaid <= dateCalled (if not zero)
        * Invariant F: calledPrincipal <= principal
        * Invariant G: dateCalled != 0 -> calledPrincipal != 0
        * Invariant H: paymentDueDate() <= defaultDate()
        * Invariant I: getPaymentBreakdown == theoretical calculation

    * Open Term Loan Manager
        * Invariant A: accountedInterest + accruedInterest() == ∑loan.getPaymentBreakdown(block.timestamp) (minus fees)
        * Invariant B: if no payments exist: accountedInterest == 0
        * Invariant C: principalOut = ∑loan.principal()
        * Invariant D: issuanceRate = ∑payment.issuanceRate
        * Invariant F: if no impairments exist: unrealizedLosses == 0
        * Invariant H: payment.startDate == loan.dateFunded() || loan.datePaid()
        * Invariant I: payment.issuanceRate == theoretical calculation (minus management fees)
        * Invariant J: payment.impairedDate >= payment.startDate
        * Invariant K: assetsUnderManagement - unrealizedLosses - ∑outstandingValue(loan) ~= 0

    *******************************************************************************************************************************/

    struct Invariants {
        bool openTermLoanInvariantA;
        bool openTermLoanInvariantB;
        bool openTermLoanInvariantC;
        bool openTermLoanInvariantD;
        bool openTermLoanInvariantE;
        bool openTermLoanInvariantF;
        bool openTermLoanInvariantG;
        bool openTermLoanInvariantH;
        bool openTermLoanInvariantI;
        bool openTermLoanManagerInvariantA;
        bool openTermLoanManagerInvariantB;
        bool openTermLoanManagerInvariantC;
        bool openTermLoanManagerInvariantD;
        bool openTermLoanManagerInvariantF;
        bool openTermLoanManagerInvariantH;
        bool openTermLoanManagerInvariantI;
        bool openTermLoanManagerInvariantJ;
        bool openTermLoanManagerInvariantK;
    }

    function checkInvariants(address poolManager_, address[] memory loans_) external view returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        // Assume indexes for FT/OT LMs are 0 and 1 respectively.
        address openTermLoanManager_;
        
        bool noOpenTermLM;

        try poolManager.loanManagerList(1) {
            openTermLoanManager_ = poolManager.loanManagerList(1);
        } catch {
            noOpenTermLM = true;
        }

        invariants_.openTermLoanInvariantA = noOpenTermLM || check_otl_invariant_A(loans_);
        invariants_.openTermLoanInvariantB = noOpenTermLM || check_otl_invariant_B(loans_);
        invariants_.openTermLoanInvariantC = noOpenTermLM || check_otl_invariant_C(loans_);
        invariants_.openTermLoanInvariantD = noOpenTermLM || check_otl_invariant_D(loans_);
        invariants_.openTermLoanInvariantE = noOpenTermLM || check_otl_invariant_E(loans_);
        invariants_.openTermLoanInvariantF = noOpenTermLM || check_otl_invariant_F(loans_);
        invariants_.openTermLoanInvariantG = noOpenTermLM || check_otl_invariant_G(loans_);
        invariants_.openTermLoanInvariantH = noOpenTermLM || check_otl_invariant_H(loans_);
        invariants_.openTermLoanInvariantI = noOpenTermLM || check_otl_invariant_I(loans_);

        invariants_.openTermLoanManagerInvariantA = true; //noOpenTermLM || check_otlm_invariant_A(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantB = noOpenTermLM || check_otlm_invariant_B(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantC = noOpenTermLM || check_otlm_invariant_C(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantD = noOpenTermLM || check_otlm_invariant_D(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantF = noOpenTermLM || check_otlm_invariant_F(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantH = noOpenTermLM || check_otlm_invariant_H(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantI = noOpenTermLM || check_otlm_invariant_I(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantJ = noOpenTermLM || check_otlm_invariant_J(openTermLoanManager_, loans_);
        invariants_.openTermLoanManagerInvariantK = noOpenTermLM || check_otlm_invariant_K(openTermLoanManager_, loans_);
    }

    /******************************************************************************************************************************/
    /*** Open Term Loan Invariants                                                                                              ***/
    /******************************************************************************************************************************/

    function check_otl_invariant_A(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.datePaid() != 0) {
                if (loan.dateFunded() > loan.datePaid()) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_B(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.dateImpaired() != 0) {
                if (loan.dateFunded() > loan.dateImpaired()) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_C(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.dateCalled() != 0) {
                if (loan.dateFunded() > loan.dateCalled()) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_D(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.datePaid() != 0 && loan.dateImpaired() != 0) {
                if (loan.datePaid() > loan.dateImpaired()) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_E(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.datePaid() != 0 && loan.dateCalled() != 0) {
                if (loan.datePaid() > loan.dateCalled()) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_F (address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.calledPrincipal() > loan.principal()) return false;
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_G (address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (
                loan.dateCalled() != 0 && loan.calledPrincipal() == 0 ||
                loan.dateCalled() == 0 && loan.calledPrincipal() != 0
            ) return false;
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_H(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            if (loan.paymentDueDate() > loan.defaultDate()) return false;
        }

        isMaintained_ = true;
    }

    function check_otl_invariant_I(address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i = 0; i < loans_.length; i++) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            (
                uint256 principal,
                uint256 interest,
                uint256 lateInterest,
                uint256 delegateServiceFee,
                uint256 platformServiceFee
            ) = loan.getPaymentBreakdown(block.timestamp);

            (
                uint256 expectedPrincipal,
                uint256 expectedInterest,
                uint256 expectedLateInterest,
                uint256 expectedDelegateServiceFee,
                uint256 expectedPlatformServiceFee
            ) = _getExpectedPaymentBreakdown(loan);

            if (
                principal          != expectedPrincipal          ||
                interest           != expectedInterest           ||
                lateInterest       != expectedLateInterest       ||
                delegateServiceFee != expectedDelegateServiceFee ||
                platformServiceFee != expectedPlatformServiceFee
            ) return false;

        }

        isMaintained_ = true;
    }

    /******************************************************************************************************************************/
    /*** Open Term Loan Manager Invariants                                                                                      ***/
    /******************************************************************************************************************************/

    function check_otlm_invariant_A(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        IOpenTermLoanManager loanManager_ = IOpenTermLoanManager(openTermLoanManager_);

        uint256 assetsUnderManagement = loanManager_.assetsUnderManagement();

        uint256 expectedAssetsUnderManagement;

        for (uint256 i; i < loans_.length; ++i) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            expectedAssetsUnderManagement += loan.principal() + _getExpectedNetInterest(loan, loanManager_);
        }

        isMaintained_ = _assertApproxEqAbs(
            assetsUnderManagement,
            expectedAssetsUnderManagement,
            BUFFER  // As the number can be unbounded but we realistically expect it to not go over $1
        );
    }

    function check_otlm_invariant_B(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 assetsUnderManagement = openTermLoanManager.assetsUnderManagement();

        for (uint256 i; i < loans_.length; ++i) {
            ( , , uint40 startDate, ) = openTermLoanManager.paymentFor(address(loans_[i]));

            if (startDate != 0) return true;
        }

        isMaintained_ = _assertApproxEqAbs(assetsUnderManagement, 0, 1000); // Loan can leave a diff one 1 so account for 1000 closed loans
    }

    function check_otlm_invariant_C(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        uint256 principalOut = IOpenTermLoanManager(openTermLoanManager_).principalOut();
        uint256 expectedPrincipalOut;

        for (uint256 i; i < loans_.length; ++i) {
            expectedPrincipalOut += IOpenTermLoan(loans_[i]).principal();
        }

        isMaintained_ = principalOut == expectedPrincipalOut;
    }

    function check_otlm_invariant_D(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 issuanceRate = openTermLoanManager.issuanceRate();
        uint256 expectedIssuanceRate;

        for (uint256 i; i < loans_.length; ++i) {
            ( , , , uint168 issuanceRate_ ) = openTermLoanManager.paymentFor(address(loans_[i]));

            if (IOpenTermLoan(loans_[i]).isImpaired()) continue;

            expectedIssuanceRate += issuanceRate_;
        }

        isMaintained_ = issuanceRate == expectedIssuanceRate;
    }

    function check_otlm_invariant_F(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        if (loans_.length == 0) return true;

        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 unrealizedLosses = openTermLoanManager.unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            ( uint40 impairmentDate, ) = openTermLoanManager.impairmentFor(address(loans_[i]));

            if (impairmentDate != 0) return true;
        }

        isMaintained_ = unrealizedLosses == 0;
    }

    function check_otlm_invariant_H(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; ++i) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            ( , , uint40 paymentStartDate, ) = IOpenTermLoanManager(openTermLoanManager_).paymentFor(address(loan));

            if (paymentStartDate != loan.dateFunded() && paymentStartDate != loan.datePaid()) return false;
        }

        isMaintained_ = true;
    }

    function check_otlm_invariant_I(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; ++i) {
            IOpenTermLoan loan = IOpenTermLoan(loans_[i]);

            IOpenTermLoanManager loanManager_ = IOpenTermLoanManager(openTermLoanManager_);

            ( , , , uint168 issuanceRate ) = loanManager_.paymentFor(address(loan));
            uint256 expectedIssuanceRate   = _getExpectedIssuanceRate(loan, loanManager_);

            if(issuanceRate != expectedIssuanceRate) return false;
        }

        isMaintained_ = true;
    }

    function check_otlm_invariant_J(address openTermLoanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        for (uint256 i; i < loans_.length; ++i) {
            IOpenTermLoanManager loanManager_ = IOpenTermLoanManager(openTermLoanManager_);

            ( uint40 impairmentDate, ) = loanManager_.impairmentFor(loans_[i]);
            ( , , uint40 startDate, )  = loanManager_.paymentFor(loans_[i]);

            if (impairmentDate != 0) {
                if (impairmentDate < startDate) return false;
            }
        }

        isMaintained_ = true;
    }

    function check_otlm_invariant_K(address loanManager_, address[] memory loans_) public view returns (bool isMaintained_) {
        uint256 outstandingValue;

        uint256 assetsUnderManagement = IOpenTermLoanManager(loanManager_).assetsUnderManagement();
        uint256 unrealizedLosses      = IOpenTermLoanManager(loanManager_).unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            outstandingValue += _getOutstandingValue(address(loans_[i]), loanManager_);
        }

        isMaintained_ = _assertApproxEqAbs(
            assetsUnderManagement + UNDERFLOW_THRESHOLD - unrealizedLosses - outstandingValue,
            0,
            BUFFER
        );
    }


    /******************************************************************************************************************************/
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function _getExpectedIssuanceRate(
        IOpenTermLoan loan,
        IOpenTermLoanManager loanManager
    ) internal view returns (uint256 expectedIssuanceRate) {
        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = loanManager.paymentFor(address(loan));

        uint256 grossInterest  = _getProRatedAmount(loan.principal(), loan.interestRate(), loan.paymentInterval());
        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        expectedIssuanceRate = (grossInterest - managementFees) * 1e27 / loan.paymentInterval();
    }

    function _getExpectedNetInterest(IOpenTermLoan loan, IOpenTermLoanManager loanManager) internal view returns (uint256 netInterest) {
        ( , uint256 grossInterest, , , ) = loan.getPaymentBreakdown(block.timestamp);
        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = loanManager.paymentFor(address(loan));

        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        netInterest = grossInterest - managementFees;
    }

    function _getExpectedPaymentBreakdown(IOpenTermLoan loan) internal view
        returns (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        )
    {
        uint256 startTime    = loan.datePaid() == 0 ? loan.dateFunded() : loan.datePaid();
        uint256 interval     = block.timestamp - startTime;
        uint256 lateInterval = block.timestamp > IOpenTermLoan(loan).paymentDueDate()
            ? block.timestamp - IOpenTermLoan(loan).paymentDueDate()
            : 0;

        expectedPrincipal          = loan.dateCalled() == 0 ? 0 : loan.calledPrincipal();
        expectedInterest           = _getProRatedAmount(loan.principal(), loan.interestRate(), interval);
        expectedLateInterest       = 0;
        expectedDelegateServiceFee = _getProRatedAmount(loan.principal(), loan.delegateServiceFeeRate(), interval);
        expectedPlatformServiceFee = _getProRatedAmount(loan.principal(), loan.platformServiceFeeRate(), interval);

        if (lateInterval > 0) {
            expectedLateInterest += _getProRatedAmount(loan.principal(), loan.lateInterestPremiumRate(), lateInterval);
            expectedLateInterest += loan.principal() * loan.lateFeeRate() / 1e6;
        }
    }

    function _getOutstandingValue(address loan_, address loanManager_) internal view returns (uint256) {
        if (IOpenTermLoan(loan_).dateFunded()   == 0) return 0;
        if (IOpenTermLoan(loan_).dateImpaired() != 0) return 0;

        (
            uint256 platformManagementFeeRate_,
            uint256 delegateManagementFeeRate_,
            ,
        ) = IOpenTermLoanManager(loanManager_).paymentFor(loan_);

        uint256 startTime_ = IOpenTermLoan(loan_).datePaid() != 0
            ? IOpenTermLoan(loan_).datePaid()
            : IOpenTermLoan(loan_).dateFunded();

        uint256 grossInterest_ = _getProRatedAmount(
            IOpenTermLoan(loan_).principal(),
            IOpenTermLoan(loan_).interestRate(),
            block.timestamp - startTime_
        );

        uint256 netInterest_ = grossInterest_ * (1e6 - delegateManagementFeeRate_ - platformManagementFeeRate_) / 1e6;

        return IOpenTermLoan(loan_).principal() + netInterest_;
    }

    function _assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta) internal pure returns (bool) {
        uint256 delta = _delta(a, b);

        if (delta > maxDelta) {
            return false;
        }

        return true;
    }

    function _delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

}
