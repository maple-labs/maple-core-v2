// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IOpenTermLoanLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract OpenTermLoanHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        address loan_ = abi.decode(input_, (address));

        results_ = new InvariantResult[](7);

        results_[0] = _checkInvariantA(loan_);
        results_[1] = _checkInvariantB(loan_);
        results_[2] = _checkInvariantC(loan_);
        results_[3] = _checkInvariantD(loan_);
        results_[4] = _checkInvariantE(loan_);
        results_[5] = _checkInvariantF(loan_);
        results_[6] = _checkInvariantG(loan_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: dateFunded <= datePaid, dateFunded <= dateCalled, dateFunded <= dateImpaired (if non-zero)                        ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address loan_) internal view returns (InvariantResult memory result_) {
        uint40 dateFunded_   = IOpenTermLoanLike(loan_).dateFunded();
        uint40 datePaid_     = IOpenTermLoanLike(loan_).datePaid();
        uint40 dateCalled_   = IOpenTermLoanLike(loan_).dateCalled();
        uint40 dateImpaired_ = IOpenTermLoanLike(loan_).dateImpaired();

        bool valid_ = true;

        if (datePaid_ != 0 && dateFunded_ > datePaid_) valid_ = false;
        if (dateCalled_ != 0 && dateFunded_ > dateCalled_) valid_ = false;
        if (dateImpaired_ != 0 && dateFunded_ > dateImpaired_) valid_ = false;

        result_ = InvariantResult({
            name:   "OTL Invariant A",
            output: abi.encode(dateFunded_, datePaid_, dateCalled_, dateImpaired_),
            valid:  valid_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: datePaid <= dateImpaired (if both non-zero)                                                                       ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address loan_) internal view returns (InvariantResult memory result_) {
        uint40 datePaid_     = IOpenTermLoanLike(loan_).datePaid();
        uint40 dateImpaired_ = IOpenTermLoanLike(loan_).dateImpaired();

        result_ = InvariantResult({
            name:   "OTL Invariant B",
            output: abi.encode(datePaid_, dateImpaired_),
            valid:  dateImpaired_ == 0 || datePaid_ <= dateImpaired_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: datePaid <= dateCalled (if both non-zero)                                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(address loan_) internal view returns (InvariantResult memory result_) {
        uint40 datePaid_   = IOpenTermLoanLike(loan_).datePaid();
        uint40 dateCalled_ = IOpenTermLoanLike(loan_).dateCalled();

        result_ = InvariantResult({
            name:   "OTL Invariant C",
            output: abi.encode(datePaid_, dateCalled_),
            valid:  dateCalled_ == 0 || datePaid_ <= dateCalled_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: calledPrincipal <= principal                                                                                      ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address loan_) internal view returns (InvariantResult memory result_) {
        uint256 calledPrincipal_ = IOpenTermLoanLike(loan_).calledPrincipal();
        uint256 principal_       = IOpenTermLoanLike(loan_).principal();

        result_ = InvariantResult({
            name:   "OTL Invariant D",
            output: abi.encode(calledPrincipal_, principal_),
            valid:  calledPrincipal_ <= principal_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: dateCalled != 0 <=> calledPrincipal != 0                                                                          ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address loan_) internal view returns (InvariantResult memory result_) {
        uint40  dateCalled_      = IOpenTermLoanLike(loan_).dateCalled();
        uint256 calledPrincipal_ = IOpenTermLoanLike(loan_).calledPrincipal();

        result_ = InvariantResult({
            name:   "OTL Invariant E",
            output: abi.encode(dateCalled_, calledPrincipal_),
            valid:  (dateCalled_ == 0) == (calledPrincipal_ == 0)
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: paymentDueDate() <= defaultDate()                                                                                 ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address loan_) internal view returns (InvariantResult memory result_) {
        uint40 paymentDueDate_ = IOpenTermLoanLike(loan_).paymentDueDate();
        uint40 defaultDate_    = IOpenTermLoanLike(loan_).defaultDate();

        result_ = InvariantResult({
            name:   "OTL Invariant F",
            output: abi.encode(paymentDueDate_, defaultDate_),
            valid:  paymentDueDate_ <= defaultDate_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: getPaymentBreakdown(block.timestamp) == theoretical calculation                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address loan_) internal view returns (InvariantResult memory result_) {
        (
            uint256 actualPrincipal_,
            uint256 actualInterest_,
            uint256 actualLateInterest_,
            uint256 actualDelegateServiceFee_,
            uint256 actualPlatformServiceFee_
        ) = IOpenTermLoanLike(loan_).getPaymentBreakdown(block.timestamp);

        (
            uint256 expectedPrincipal_,
            uint256 expectedInterest_,
            uint256 expectedLateInterest_,
            uint256 expectedDelegateServiceFee_,
            uint256 expectedPlatformServiceFee_
        ) = _getExpectedPaymentBreakdown(loan_);

        bool valid_ = actualPrincipal_ == expectedPrincipal_ && actualInterest_ == expectedInterest_
            && actualLateInterest_ == expectedLateInterest_ && actualDelegateServiceFee_ == expectedDelegateServiceFee_
            && actualPlatformServiceFee_ == expectedPlatformServiceFee_;

        uint256[5] memory actual_ =
            [actualPrincipal_, actualInterest_, actualLateInterest_, actualDelegateServiceFee_, actualPlatformServiceFee_];

        uint256[5] memory expected_ =
            [expectedPrincipal_, expectedInterest_, expectedLateInterest_, expectedDelegateServiceFee_, expectedPlatformServiceFee_];

        result_ = InvariantResult({
            name:   "OTL Invariant G",
            output: abi.encode(actual_, expected_),
            valid:  valid_
        });
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _getExpectedPaymentBreakdown(address loan_)
        internal
        view
        returns (
            uint256 expectedPrincipal_,
            uint256 expectedInterest_,
            uint256 expectedLateInterest_,
            uint256 expectedDelegateServiceFee_,
            uint256 expectedPlatformServiceFee_
        )
    {
        uint256 startTime_ = IOpenTermLoanLike(loan_).datePaid() == 0
            ? IOpenTermLoanLike(loan_).dateFunded()
            : IOpenTermLoanLike(loan_).datePaid();

        if (startTime_ == 0 || block.timestamp <= startTime_) {
            expectedPrincipal_ = IOpenTermLoanLike(loan_).dateCalled() == 0 ? 0 : IOpenTermLoanLike(loan_).calledPrincipal();

            return (expectedPrincipal_, 0, 0, 0, 0);
        }

        uint256 interval_ = block.timestamp - startTime_;
        uint256 lateInterval_ =
            block.timestamp > IOpenTermLoanLike(loan_).paymentDueDate() ? block.timestamp - IOpenTermLoanLike(loan_).paymentDueDate() : 0;

        uint256 principal_ = IOpenTermLoanLike(loan_).principal();

        expectedPrincipal_          = IOpenTermLoanLike(loan_).dateCalled() == 0 ? 0 : IOpenTermLoanLike(loan_).calledPrincipal();
        expectedInterest_           = _getProRatedAmount(principal_, IOpenTermLoanLike(loan_).interestRate(), interval_);
        expectedLateInterest_       = 0;
        expectedDelegateServiceFee_ = _getProRatedAmount(principal_, IOpenTermLoanLike(loan_).delegateServiceFeeRate(), interval_);
        expectedPlatformServiceFee_ = _getProRatedAmount(principal_, IOpenTermLoanLike(loan_).platformServiceFeeRate(), interval_);

        if (lateInterval_ > 0) {
            expectedLateInterest_ += _getProRatedAmount(principal_, IOpenTermLoanLike(loan_).lateInterestPremiumRate(), lateInterval_);
            expectedLateInterest_ += principal_ * IOpenTermLoanLike(loan_).lateFeeRate() / 1e6;
        }
    }

    function _getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

}
