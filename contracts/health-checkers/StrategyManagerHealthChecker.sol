// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManagerLike, IUnderlyingStrategyLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract StrategyManagerHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address strategyManager_, address[] memory poolManagers_) = abi.decode(input_, (address, address[]));

        results_ = new InvariantResult[](9);

        results_[0] = _checkInvariantA(strategyManager_);
        results_[1] = _checkInvariantB(strategyManager_);
        results_[2] = _checkInvariantC(strategyManager_, poolManagers_);
        results_[3] = _checkInvariantD(strategyManager_, poolManagers_);
        results_[4] = _checkInvariantE(strategyManager_, poolManagers_);
        results_[5] = _checkInvariantF(strategyManager_);
        results_[6] = _checkInvariantG(strategyManager_);
        results_[7] = _checkInvariantH(strategyManager_, poolManagers_);
        results_[8] = _checkInvariantI(strategyManager_, poolManagers_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: assetsUnderManagement()/unrealizedLosses() pass through to the underlying strategy                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address strategyManager_) internal view returns (InvariantResult memory result_) {
        address underlyingStrategy_ = IStrategyManagerLike(strategyManager_).underlyingStrategy();

        uint256 smAum_         = IStrategyManagerLike(strategyManager_).assetsUnderManagement();
        uint256 underlyingAum_ = IUnderlyingStrategyLike(underlyingStrategy_).assetsUnderManagement();

        uint256 smLosses_         = IStrategyManagerLike(strategyManager_).unrealizedLosses();
        uint256 underlyingLosses_ = IUnderlyingStrategyLike(underlyingStrategy_).unrealizedLosses();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant A",
            output: abi.encode(smAum_, underlyingAum_, smLosses_, underlyingLosses_),
            valid:  (smAum_ == underlyingAum_) && (smLosses_ == underlyingLosses_)
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: unrealizedLosses <= assetsUnderManagement                                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address strategyManager_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_      = IStrategyManagerLike(strategyManager_).unrealizedLosses();
        uint256 assetsUnderManagement_ = IStrategyManagerLike(strategyManager_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant B",
            output: abi.encode(unrealizedLosses_, assetsUnderManagement_),
            valid:  unrealizedLosses_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: totalShares == sum(sharesOf(pm)), including sharesOf(address(0)) from the bootstrap deposit                       ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(
        address strategyManager_,
        address[] memory poolManagers_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 sumShares_ = IStrategyManagerLike(strategyManager_).sharesOf(address(0));

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumShares_ += IStrategyManagerLike(strategyManager_).sharesOf(poolManagers_[i]);
        }

        uint256 totalShares_ = IStrategyManagerLike(strategyManager_).totalShares();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant C",
            output: abi.encode(totalShares_, sumShares_),
            valid:  totalShares_ == sumShares_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: totalPendingShares == sum(pendingSharesOf(pm))                                                                    ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(
        address strategyManager_,
        address[] memory poolManagers_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 sumPendingShares_;

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumPendingShares_ += IStrategyManagerLike(strategyManager_).pendingSharesOf(poolManagers_[i]);
        }

        uint256 totalPendingShares_ = IStrategyManagerLike(strategyManager_).totalPendingShares();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant D",
            output: abi.encode(totalPendingShares_, sumPendingShares_),
            valid:  totalPendingShares_ == sumPendingShares_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: pendingSharesOf(pm) <= sharesOf(pm), for every pm in poolManagers_                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(
        address strategyManager_,
        address[] memory poolManagers_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        for (uint256 i; i < poolManagers_.length; ++i) {
            address poolManager_ = poolManagers_[i];

            uint256 pendingSharesOf_ = IStrategyManagerLike(strategyManager_).pendingSharesOf(poolManager_);
            uint256 sharesOf_        = IStrategyManagerLike(strategyManager_).sharesOf(poolManager_);

            if (pendingSharesOf_ > sharesOf_) {
                return InvariantResult({
                    name:   "StrategyManager Invariant E",
                    output: abi.encode(poolManager_, pendingSharesOf_, sharesOf_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "StrategyManager Invariant E",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: totalShares >= sharesOf(address(0))                                                                               ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address strategyManager_) internal view returns (InvariantResult memory result_) {
        uint256 totalShares_  = IStrategyManagerLike(strategyManager_).totalShares();
        uint256 sharesOfZero_ = IStrategyManagerLike(strategyManager_).sharesOf(address(0));

        result_ = InvariantResult({
            name:   "StrategyManager Invariant F",
            output: abi.encode(totalShares_, sharesOfZero_),
            valid:  totalShares_ >= sharesOfZero_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: convertToExitAssets(totalShares) <= convertToAssets(totalShares)                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address strategyManager_) internal view returns (InvariantResult memory result_) {
        uint256 shares_ = IStrategyManagerLike(strategyManager_).totalShares();

        uint256 convertToExitAssets_ = IStrategyManagerLike(strategyManager_).convertToExitAssets(shares_);
        uint256 convertToAssets_     = IStrategyManagerLike(strategyManager_).convertToAssets(shares_);

        result_ = InvariantResult({
            name:   "StrategyManager Invariant G",
            output: abi.encode(convertToExitAssets_, convertToAssets_),
            valid:  convertToExitAssets_ <= convertToAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: sum(assetsOf(pm)) <= assetsUnderManagement                                                                        ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(
        address strategyManager_,
        address[] memory poolManagers_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 sumAssetsOf_;

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumAssetsOf_ += IStrategyManagerLike(strategyManager_).assetsOf(poolManagers_[i]);
        }

        uint256 assetsUnderManagement_ = IStrategyManagerLike(strategyManager_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant H",
            output: abi.encode(sumAssetsOf_, assetsUnderManagement_),
            valid:  sumAssetsOf_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: sum(unrealizedLossesOf(pm)) >= unrealizedLosses, including unrealizedLossesOf(address(0))                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(
        address strategyManager_,
        address[] memory poolManagers_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        uint256 sumUnrealizedLossesOf_ = IStrategyManagerLike(strategyManager_).unrealizedLossesOf(address(0));

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumUnrealizedLossesOf_ += IStrategyManagerLike(strategyManager_).unrealizedLossesOf(poolManagers_[i]);
        }

        uint256 unrealizedLosses_ = IStrategyManagerLike(strategyManager_).unrealizedLosses();

        result_ = InvariantResult({
            name:   "StrategyManager Invariant I",
            output: abi.encode(sumUnrealizedLossesOf_, unrealizedLosses_),
            valid:  sumUnrealizedLossesOf_ >= unrealizedLosses_
        });
    }

}
