// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolLike, IWithdrawalManagerQueueLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract WithdrawalManagerHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address withdrawalManager_, address[] memory lenders_) = abi.decode(input_, (address, address[]));

        results_ = new InvariantResult[](11);

        results_[0]  = _checkInvariantA(withdrawalManager_, lenders_);
        results_[1]  = _checkInvariantB(withdrawalManager_);
        results_[2]  = _checkInvariantC(withdrawalManager_, lenders_);
        results_[3]  = _checkInvariantD(withdrawalManager_);
        results_[4]  = _checkInvariantE(withdrawalManager_);
        results_[5]  = _checkInvariantF(withdrawalManager_);
        results_[6]  = _checkInvariantG(withdrawalManager_, lenders_);
        results_[7]  = _checkInvariantH(withdrawalManager_, lenders_);
        results_[8]  = _checkInvariantI(withdrawalManager_, lenders_);
        results_[9]  = _checkInvariantJ(withdrawalManager_, lenders_);
        results_[10] = _checkInvariantK(withdrawalManager_, lenders_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: sum(request.shares) + sum(owner.manualSharesAvailable) == totalShares                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        (uint256 nextRequestId_, uint256 lastRequestId_) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        uint256 sumRequestShares_;

        for (uint256 requestId_ = nextRequestId_; requestId_ <= lastRequestId_; ++requestId_) {
            (, uint256 shares_) = IWithdrawalManagerQueueLike(withdrawalManager_).requests(requestId_);

            sumRequestShares_ += shares_;
        }

        uint256 sumManualShares_;

        for (uint256 i; i < lenders_.length; ++i) {
            sumManualShares_ += IWithdrawalManagerQueueLike(withdrawalManager_).manualSharesAvailable(lenders_[i]);
        }

        uint256 totalShares_ = IWithdrawalManagerQueueLike(withdrawalManager_).totalShares();

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant A",
            output: abi.encode(totalShares_, sumRequestShares_, sumManualShares_),
            valid:  totalShares_ == sumRequestShares_ + sumManualShares_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: balanceOf(this) >= totalShares                                                                                    ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address withdrawalManager_) internal view returns (InvariantResult memory result_) {
        address pool_ = IWithdrawalManagerQueueLike(withdrawalManager_).pool();

        uint256 poolBalance_ = IPoolLike(pool_).balanceOf(withdrawalManager_);
        uint256 totalShares_ = IWithdrawalManagerQueueLike(withdrawalManager_).totalShares();

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant B",
            output: abi.encode(poolBalance_, totalShares_),
            valid:  poolBalance_ >= totalShares_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: requestId(owner) != 0 -> request.shares > 0 && request.owner == owner                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        for (uint256 i; i < lenders_.length; ++i) {
            address lender_ = lenders_[i];

            uint256 requestId_ = IWithdrawalManagerQueueLike(withdrawalManager_).requestIds(lender_);

            if (requestId_ == 0) continue;

            (address owner_, uint256 shares_) = IWithdrawalManagerQueueLike(withdrawalManager_).requests(requestId_);

            if (shares_ == 0 || owner_ != lender_) {
                return InvariantResult({
                    name:   "WithdrawalManager Invariant C",
                    output: abi.encode(lender_, requestId_, owner_, shares_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant C",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: nextRequestId <= lastRequestId + 1                                                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address withdrawalManager_) internal view returns (InvariantResult memory result_) {
        (uint256 nextRequestId_, uint256 lastRequestId_) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant D",
            output: abi.encode(nextRequestId_, lastRequestId_),
            valid:  nextRequestId_ <= lastRequestId_ + 1
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: nextRequestId != 0                                                                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address withdrawalManager_) internal view returns (InvariantResult memory result_) {
        (uint256 nextRequestId_,) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant E",
            output: abi.encode(nextRequestId_),
            valid:  nextRequestId_ != 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: requests(0) == (0, 0)                                                                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address withdrawalManager_) internal view returns (InvariantResult memory result_) {
        (address owner_, uint256 shares_) = IWithdrawalManagerQueueLike(withdrawalManager_).requests(0);

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant F",
            output: abi.encode(owner_, shares_),
            valid:  owner_ == address(0) && shares_ == 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: requestId[lender] in [0, lastRequestId], for every lender                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        (, uint256 lastRequestId_) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        for (uint256 i; i < lenders_.length; ++i) {
            address lender_ = lenders_[i];

            uint256 requestId_ = IWithdrawalManagerQueueLike(withdrawalManager_).requestIds(lender_);

            if (requestId_ > lastRequestId_) {
                return InvariantResult({
                    name:   "WithdrawalManager Invariant G",
                    output: abi.encode(lender_, requestId_, lastRequestId_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant G",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: requestId is unique across lenders                                                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        (uint256 nextRequestId_, uint256 lastRequestId_) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        if (nextRequestId_ <= lastRequestId_) {
            address[] memory ownerOf_ = new address[](lastRequestId_ + 1 - nextRequestId_);

            for (uint256 i; i < lenders_.length; ++i) {
                address lender_ = lenders_[i];

                uint256 requestId_ = IWithdrawalManagerQueueLike(withdrawalManager_).requestIds(lender_);

                if (requestId_ == 0) continue;

                // NOTE: Guards against indexing `ownerOf_` out of bounds below.
                if (requestId_ < nextRequestId_ || requestId_ > lastRequestId_) continue;

                if (ownerOf_[requestId_ - nextRequestId_] != address(0)) {
                    return InvariantResult({
                        name:   "WithdrawalManager Invariant H",
                        output: abi.encode(requestId_, ownerOf_[requestId_ - nextRequestId_], lender_),
                        valid:  false
                    });
                }

                ownerOf_[requestId_ - nextRequestId_] = lender_;
            }
        }

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant H",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: userEscrowedShares(owner) == sum(requestsByOwner(owner).shares), for every owner                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        for (uint256 i; i < lenders_.length; ++i) {
            address owner_ = lenders_[i];

            (, uint256[] memory shares_) = IWithdrawalManagerQueueLike(withdrawalManager_).requestsByOwner(owner_);

            uint256 sumRequestShares_;

            for (uint256 j; j < shares_.length; ++j) {
                sumRequestShares_ += shares_[j];
            }

            uint256 userEscrowedShares_ = IWithdrawalManagerQueueLike(withdrawalManager_).userEscrowedShares(owner_);

            if (userEscrowedShares_ != sumRequestShares_) {
                return InvariantResult({
                    name:   "WithdrawalManager Invariant I",
                    output: abi.encode(owner_, userEscrowedShares_, sumRequestShares_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant I",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant J: sum(owner.userEscrowedShares) + sum(owner.manualSharesAvailable) == totalShares                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantJ(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 sumEscrowed_;
        uint256 sumManual_;

        for (uint256 i; i < lenders_.length; ++i) {
            address owner_ = lenders_[i];

            sumEscrowed_ += IWithdrawalManagerQueueLike(withdrawalManager_).userEscrowedShares(owner_);
            sumManual_   += IWithdrawalManagerQueueLike(withdrawalManager_).manualSharesAvailable(owner_);
        }

        uint256 totalShares_ = IWithdrawalManagerQueueLike(withdrawalManager_).totalShares();

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant J",
            output: abi.encode(totalShares_, sumEscrowed_, sumManual_),
            valid:  totalShares_ == sumEscrowed_ + sumManual_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant K: requestsByOwner lists are strictly increasing, and each id is in (0, lastRequestId]                               ***/
    /**************************************************************************************************************************************/

    function _checkInvariantK(address withdrawalManager_, address[] memory lenders_)
        internal
        view
        returns (InvariantResult memory result_)
    {
        (, uint256 lastRequestId_) = IWithdrawalManagerQueueLike(withdrawalManager_).queue();

        for (uint256 i; i < lenders_.length; ++i) {
            address owner_ = lenders_[i];

            (uint256[] memory requestIds_,) = IWithdrawalManagerQueueLike(withdrawalManager_).requestsByOwner(owner_);

            for (uint256 j; j < requestIds_.length; ++j) {
                uint256 requestId_ = requestIds_[j];

                bool inRange_      = requestId_ > 0 && requestId_ <= lastRequestId_;
                bool isIncreasing_ = j == 0 || requestId_ > requestIds_[j - 1];

                if (!inRange_ || !isIncreasing_) {
                    return InvariantResult({
                        name:   "WithdrawalManager Invariant K",
                        output: abi.encode(owner_, requestId_, j == 0 ? uint256(0) : requestIds_[j - 1]),
                        valid:  false
                    });
                }
            }
        }

        result_ = InvariantResult({
            name:   "WithdrawalManager Invariant K",
            output: "",
            valid:  true
        });
    }

}
