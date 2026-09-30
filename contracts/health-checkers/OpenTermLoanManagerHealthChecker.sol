// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IOpenTermLoanLike, IOpenTermLoanManagerLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract OpenTermLoanManagerHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address loanManager_, address[] memory loans_, uint256 tolerance_) = abi.decode(input_, (address, address[], uint256));

        results_ = new InvariantResult[](13);

        results_[0]  = _checkInvariantA(loanManager_, loans_, tolerance_);
        results_[1]  = _checkInvariantB(loanManager_, loans_);
        results_[2]  = _checkInvariantC(loanManager_, loans_);
        results_[3]  = _checkInvariantD(loanManager_, loans_);
        results_[4]  = _checkInvariantE(loanManager_, tolerance_);
        results_[5]  = _checkInvariantF(loanManager_, loans_);
        results_[6]  = _checkInvariantG(loanManager_);
        results_[7]  = _checkInvariantH(loanManager_, loans_);
        results_[8]  = _checkInvariantI(loanManager_, loans_);
        results_[9]  = _checkInvariantJ(loanManager_, loans_);
        results_[10] = _checkInvariantK(loanManager_, loans_, tolerance_);
        results_[11] = _checkInvariantL(loanManager_);
        results_[12] = _checkInvariantM(loanManager_, loans_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: assetsUnderManagement() ~= sum(loan.principal() + expectedNetInterest(loan)), within `tolerance`                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(
        address loanManager_,
        address[] memory loans_,
        uint256 tolerance_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 assetsUnderManagement_ = IOpenTermLoanManagerLike(loanManager_).assetsUnderManagement();

        uint256 expectedAssetsUnderManagement_;

        for (uint256 i; i < loans_.length; ++i) {
            expectedAssetsUnderManagement_ += IOpenTermLoanLike(loans_[i]).principal() + _getExpectedNetInterest(loans_[i], loanManager_);
        }

        uint256 diff_ = assetsUnderManagement_ > expectedAssetsUnderManagement_
            ? assetsUnderManagement_ - expectedAssetsUnderManagement_
            : expectedAssetsUnderManagement_ - assetsUnderManagement_;

        result_ = InvariantResult({
            name:   "OTLM Invariant A",
            output: abi.encode(assetsUnderManagement_, expectedAssetsUnderManagement_),
            valid:  diff_ <= tolerance_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: if no loan has a non-zero payment start date, assetsUnderManagement() ~= 0                                        ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        uint256 assetsUnderManagement_ = IOpenTermLoanManagerLike(loanManager_).assetsUnderManagement();

        for (uint256 i; i < loans_.length; ++i) {
            (,, uint40 startDate_,) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loans_[i]);

            if (startDate_ != 0) {
                return InvariantResult({
                    name:   "OTLM Invariant B",
                    output: abi.encode(assetsUnderManagement_),
                    valid:  true
                });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant B",
            output: abi.encode(assetsUnderManagement_),
            valid:  assetsUnderManagement_ <= loans_.length
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: principalOut == sum(loan.principal())                                                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        uint256 principalOut_ = IOpenTermLoanManagerLike(loanManager_).principalOut();

        uint256 expectedPrincipalOut_;

        for (uint256 i; i < loans_.length; ++i) {
            expectedPrincipalOut_ += IOpenTermLoanLike(loans_[i]).principal();
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant C",
            output: abi.encode(principalOut_, expectedPrincipalOut_),
            valid:  principalOut_ == expectedPrincipalOut_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: issuanceRate == sum(payment.issuanceRate), skipping every impaired loan                                           ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        uint256 issuanceRate_ = IOpenTermLoanManagerLike(loanManager_).issuanceRate();

        uint256 expectedIssuanceRate_;

        for (uint256 i; i < loans_.length; ++i) {
            (,,, uint168 loanIssuanceRate_) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loans_[i]);

            if (IOpenTermLoanLike(loans_[i]).isImpaired()) continue;

            expectedIssuanceRate_ += loanIssuanceRate_;
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant D",
            output: abi.encode(issuanceRate_, expectedIssuanceRate_),
            valid:  issuanceRate_ == expectedIssuanceRate_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: unrealizedLosses() <= assetsUnderManagement(), within `tolerance`                                                 ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address loanManager_, uint256 tolerance_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_      = IOpenTermLoanManagerLike(loanManager_).unrealizedLosses();
        uint256 assetsUnderManagement_ = IOpenTermLoanManagerLike(loanManager_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "OTLM Invariant E",
            output: abi.encode(unrealizedLosses_, assetsUnderManagement_),
            valid:  unrealizedLosses_ <= assetsUnderManagement_ + tolerance_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: if no loan is impaired, unrealizedLosses() == 0                                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_ = IOpenTermLoanManagerLike(loanManager_).unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            (uint40 impairmentDate_,) = IOpenTermLoanManagerLike(loanManager_).impairmentFor(loans_[i]);

            if (impairmentDate_ != 0) {
                return InvariantResult({
                    name:   "OTLM Invariant F",
                    output: abi.encode(unrealizedLosses_),
                    valid:  true
                });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant F",
            output: abi.encode(unrealizedLosses_),
            valid:  unrealizedLosses_ == 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: block.timestamp >= domainStart                                                                                    ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address loanManager_) internal view returns (InvariantResult memory result_) {
        uint256 domainStart_ = IOpenTermLoanManagerLike(loanManager_).domainStart();

        result_ = InvariantResult({
            name:   "OTLM Invariant G",
            output: abi.encode(block.timestamp, domainStart_),
            valid:  block.timestamp >= domainStart_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: payment.startDate == loan.dateFunded() || loan.datePaid(), for every loan                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        for (uint256 i; i < loans_.length; ++i) {
            (,, uint40 paymentStartDate_,) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loans_[i]);

            uint40 dateFunded_ = IOpenTermLoanLike(loans_[i]).dateFunded();
            uint40 datePaid_   = IOpenTermLoanLike(loans_[i]).datePaid();

            if (paymentStartDate_ != dateFunded_ && paymentStartDate_ != datePaid_) {
                return InvariantResult({
                    name:   "OTLM Invariant H",
                    output: abi.encode(loans_[i], paymentStartDate_, dateFunded_, datePaid_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant H",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: payment.issuanceRate == theoretical calculation, for every loan                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        for (uint256 i; i < loans_.length; ++i) {
            (,,, uint168 issuanceRate_) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loans_[i]);

            uint256 expectedIssuanceRate_ = _getExpectedIssuanceRate(loans_[i], loanManager_);

            if (issuanceRate_ != expectedIssuanceRate_) {
                return InvariantResult({
                    name:   "OTLM Invariant I",
                    output: abi.encode(loans_[i], issuanceRate_, expectedIssuanceRate_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant I",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant J: payment.impairedDate >= payment.startDate, for every loan                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantJ(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        for (uint256 i; i < loans_.length; ++i) {
            (uint40 impairmentDate_,) = IOpenTermLoanManagerLike(loanManager_).impairmentFor(loans_[i]);
            (,, uint40 startDate_,)   = IOpenTermLoanManagerLike(loanManager_).paymentFor(loans_[i]);

            if (impairmentDate_ != 0 && impairmentDate_ < startDate_) {
                return
                    InvariantResult({
                        name:   "OTLM Invariant J",
                        output: abi.encode(loans_[i], impairmentDate_, startDate_),
                        valid:  false
                    });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant J",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant K: assetsUnderManagement - unrealizedLosses - sum(outstandingValue(loan)) ~= 0, within `tolerance`                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantK(
        address loanManager_,
        address[] memory loans_,
        uint256 tolerance_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 assetsUnderManagement_ = IOpenTermLoanManagerLike(loanManager_).assetsUnderManagement();
        uint256 unrealizedLosses_      = IOpenTermLoanManagerLike(loanManager_).unrealizedLosses();

        uint256 outstandingValue_;

        for (uint256 i; i < loans_.length; ++i) {
            outstandingValue_ += _getOutstandingValue(loans_[i], loanManager_);
        }

        uint256 unrealizedLossesPlusOutstandingValue_ = unrealizedLosses_ + outstandingValue_;

        uint256 diff_ = assetsUnderManagement_ > unrealizedLossesPlusOutstandingValue_
            ? assetsUnderManagement_ - unrealizedLossesPlusOutstandingValue_
            : unrealizedLossesPlusOutstandingValue_ - assetsUnderManagement_;

        result_ = InvariantResult({
            name:   "OTLM Invariant K",
            output: abi.encode(assetsUnderManagement_, unrealizedLosses_, outstandingValue_),
            valid:  diff_ <= tolerance_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant L: fundsAsset.balanceOf(loanManager) == 0                                                                            ***/
    /**************************************************************************************************************************************/

    function _checkInvariantL(address loanManager_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = IOpenTermLoanManagerLike(loanManager_).fundsAsset();
        uint256 balance_    = IERC20(fundsAsset_).balanceOf(loanManager_);

        result_ = InvariantResult({
            name:   "OTLM Invariant L",
            output: abi.encode(balance_),
            valid:  balance_ == 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant M: fundsAsset.allowance(loanManager, loan) == 0, for every loan                                                      ***/
    /**************************************************************************************************************************************/

    function _checkInvariantM(address loanManager_, address[] memory loans_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = IOpenTermLoanManagerLike(loanManager_).fundsAsset();

        for (uint256 i; i < loans_.length; ++i) {
            uint256 allowance_ = IERC20(fundsAsset_).allowance(loanManager_, loans_[i]);

            if (allowance_ != 0) {
                return InvariantResult({
                    name:   "OTLM Invariant M",
                    output: abi.encode(loans_[i], allowance_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "OTLM Invariant M",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _getExpectedIssuanceRate(address loan_, address loanManager_) internal view returns (uint256 expectedIssuanceRate_) {
        (uint24 platformManagementFeeRate_, uint24 delegateManagementFeeRate_,,) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loan_);

        uint256 grossInterest_ = _getProRatedAmount(
            IOpenTermLoanLike(loan_).principal(), IOpenTermLoanLike(loan_).interestRate(), IOpenTermLoanLike(loan_).paymentInterval()
        );

        if (grossInterest_ == 0) return 0;

        uint256 managementFees_ = grossInterest_ * (delegateManagementFeeRate_ + platformManagementFeeRate_) / 1e6;

        expectedIssuanceRate_ = (grossInterest_ - managementFees_) * 1e27 / IOpenTermLoanLike(loan_).paymentInterval();
    }

    function _getExpectedNetInterest(address loan_, address loanManager_) internal view returns (uint256 netInterest_) {
        uint256 timestamp_ = IOpenTermLoanLike(loan_).isImpaired() ? IOpenTermLoanLike(loan_).dateImpaired() : block.timestamp;

        (, uint256 grossInterest_,,,)                                            = IOpenTermLoanLike(loan_).getPaymentBreakdown(timestamp_);
        (uint24 platformManagementFeeRate_, uint24 delegateManagementFeeRate_,,) = IOpenTermLoanManagerLike(loanManager_).paymentFor(loan_);

        uint256 managementFees_ = grossInterest_ * (delegateManagementFeeRate_ + platformManagementFeeRate_) / 1e6;

        netInterest_ = grossInterest_ - managementFees_;
    }

    function _getOutstandingValue(address loan_, address loanManager_) internal view returns (uint256 outstandingValue_) {
        if (IOpenTermLoanLike(loan_).dateFunded() == 0) return 0;
        if (IOpenTermLoanLike(loan_).dateImpaired() != 0) return 0;

        (uint256 platformManagementFeeRate_, uint256 delegateManagementFeeRate_,,) =
            IOpenTermLoanManagerLike(loanManager_).paymentFor(loan_);

        uint256 startTime_ =
            IOpenTermLoanLike(loan_).datePaid() != 0 ? IOpenTermLoanLike(loan_).datePaid() : IOpenTermLoanLike(loan_).dateFunded();

        uint256 grossInterest_ = _getProRatedAmount(
            IOpenTermLoanLike(loan_).principal(), IOpenTermLoanLike(loan_).interestRate(), block.timestamp - startTime_
        );

        uint256 netInterest_ = grossInterest_ * (1e6 - delegateManagementFeeRate_ - platformManagementFeeRate_) / 1e6;

        outstandingValue_ = IOpenTermLoanLike(loan_).principal() + netInterest_;
    }

    function _getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

}
