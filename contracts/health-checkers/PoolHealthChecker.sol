// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IPoolLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract PoolHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address pool_, address[] memory lps_) = abi.decode(input_, (address, address[]));

        results_ = new InvariantResult[](8);

        results_[0] = _checkInvariantA(pool_);
        results_[1] = _checkInvariantB(pool_, lps_);
        results_[2] = _checkInvariantD(pool_);
        results_[3] = _checkInvariantE(pool_);
        results_[4] = _checkInvariantG(pool_, lps_);
        results_[5] = _checkInvariantI(pool_);
        results_[6] = _checkInvariantJ(pool_);
        results_[7] = _checkInvariantK(pool_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: totalAssets >= fundsAsset.balanceOf(pool)                                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address pool_) internal view returns (InvariantResult memory result_) {
        address asset_ = IPoolLike(pool_).asset();

        uint256 totalAssets_ = IPoolLike(pool_).totalAssets();
        uint256 poolBalance_ = IERC20(asset_).balanceOf(pool_);

        result_ = InvariantResult({
            name:   "Pool Invariant A",
            output: abi.encode(totalAssets_, poolBalance_),
            valid:  totalAssets_ >= poolBalance_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: sum(balanceOfAssets(lp)) == totalAssets (with rounding tolerance)                                                 ***/
    /**************************************************************************************************************************************/

    // NOTE: This computes balanceOfAssets(lp) manually in order to save gas: (balanceOf(lp) * totalAssets / totalSupply)
    function _checkInvariantB(address pool_, address[] memory lps_) internal view returns (InvariantResult memory result_) {
        address poolManager_       = IPoolLike(pool_).manager();
        address withdrawalManager_ = IPoolManagerLike(poolManager_).withdrawalManager();

        uint256 totalAssets_ = IPoolLike(pool_).totalAssets();
        uint256 totalSupply_ = IPoolLike(pool_).totalSupply();

        uint256 sumBalanceOfAssets_ = _toAssets(IPoolLike(pool_).balanceOf(address(0)), totalAssets_, totalSupply_)
            + _toAssets(IPoolLike(pool_).balanceOf(withdrawalManager_), totalAssets_, totalSupply_);

        for (uint256 i; i < lps_.length; ++i) {
            // NOTE: Skip address(0) and the withdrawal manager if they are passed in, since they are already included by default.
            if (lps_[i] == address(0) || lps_[i] == withdrawalManager_) continue;

            sumBalanceOfAssets_ += _toAssets(IPoolLike(pool_).balanceOf(lps_[i]), totalAssets_, totalSupply_);
        }

        result_ = InvariantResult({
            name:   "Pool Invariant B",
            output: abi.encode(totalAssets_, sumBalanceOfAssets_),
            valid:  totalAssets_ >= sumBalanceOfAssets_ && (totalAssets_ - sumBalanceOfAssets_) <= (lps_.length + 1)
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: convertToAssets(totalSupply) == totalAssets (rounding tolerance of 1)                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address pool_) internal view returns (InvariantResult memory result_) {
        uint256 totalSupply_     = IPoolLike(pool_).totalSupply();
        uint256 convertToAssets_ = IPoolLike(pool_).convertToAssets(totalSupply_);
        uint256 totalAssets_     = IPoolLike(pool_).totalAssets();

        result_ = InvariantResult({
            name:   "Pool Invariant D",
            output: abi.encode(totalAssets_, convertToAssets_),
            valid:  totalAssets_ >= convertToAssets_ && (totalAssets_ - convertToAssets_) <= 1
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: convertToShares(totalAssets) == totalSupply (rounding tolerance of 1)                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address pool_) internal view returns (InvariantResult memory result_) {
        uint256 totalAssets_     = IPoolLike(pool_).totalAssets();
        uint256 convertToShares_ = IPoolLike(pool_).convertToShares(totalAssets_);
        uint256 totalSupply_     = IPoolLike(pool_).totalSupply();

        result_ = InvariantResult({
            name:   "Pool Invariant E",
            output: abi.encode(totalSupply_, convertToShares_),
            valid:  convertToShares_ >= totalSupply_ && (convertToShares_ - totalSupply_) <= 1
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: sum(balanceOf(lp)) == totalSupply                                                                                 ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address pool_, address[] memory lps_) internal view returns (InvariantResult memory result_) {
        address poolManager_       = IPoolLike(pool_).manager();
        address withdrawalManager_ = IPoolManagerLike(poolManager_).withdrawalManager();

        uint256 sumBalanceOf_ = IPoolLike(pool_).balanceOf(address(0)) + IPoolLike(pool_).balanceOf(withdrawalManager_);

        for (uint256 i; i < lps_.length; ++i) {
            // NOTE: Skip address(0) and the withdrawal manager if they are passed in, since they are already included by default.
            if (lps_[i] == address(0) || lps_[i] == withdrawalManager_) continue;

            sumBalanceOf_ += IPoolLike(pool_).balanceOf(lps_[i]);
        }

        uint256 totalSupply_ = IPoolLike(pool_).totalSupply();

        result_ = InvariantResult({
            name:   "Pool Invariant G",
            output: abi.encode(totalSupply_, sumBalanceOf_),
            valid:  totalSupply_ == sumBalanceOf_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: pool.totalAssets() == poolManager.totalAssets()                                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address pool_) internal view returns (InvariantResult memory result_) {
        address poolManager_ = IPoolLike(pool_).manager();

        uint256 poolTotalAssets_        = IPoolLike(pool_).totalAssets();
        uint256 poolManagerTotalAssets_ = IPoolManagerLike(poolManager_).totalAssets();

        result_ = InvariantResult({
            name:   "Pool Invariant I",
            output: abi.encode(poolTotalAssets_, poolManagerTotalAssets_),
            valid:  poolTotalAssets_ == poolManagerTotalAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant J: pool.unrealizedLosses() == poolManager.unrealizedLosses()                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantJ(address pool_) internal view returns (InvariantResult memory result_) {
        address poolManager_ = IPoolLike(pool_).manager();

        uint256 poolUnrealizedLosses_        = IPoolLike(pool_).unrealizedLosses();
        uint256 poolManagerUnrealizedLosses_ = IPoolManagerLike(poolManager_).unrealizedLosses();

        result_ = InvariantResult({
            name:   "Pool Invariant J",
            output: abi.encode(poolUnrealizedLosses_, poolManagerUnrealizedLosses_),
            valid:  poolUnrealizedLosses_ == poolManagerUnrealizedLosses_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant K: pool.convertToExitShares() == poolManager.convertToExitShares()                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantK(address pool_) internal view returns (InvariantResult memory result_) {
        address poolManager_ = IPoolLike(pool_).manager();

        uint256 totalAssets_      = IPoolLike(pool_).totalAssets();
        uint256 unrealizedLosses_ = IPoolLike(pool_).unrealizedLosses();

        // NOTE: Skip `convertToExitShares()` (it would revert here) and return type(uint256).max when the pool is fully impaired.
        if (totalAssets_ <= unrealizedLosses_) {
            return InvariantResult({
                name:   "Pool Invariant K",
                output: abi.encode(type(uint256).max, type(uint256).max),
                valid:  true
            });
        }

        uint256 poolConvertToExitShares_        = IPoolLike(pool_).convertToExitShares(totalAssets_);
        uint256 poolManagerConvertToExitShares_ = IPoolManagerLike(poolManager_).convertToExitShares(totalAssets_);

        result_ = InvariantResult({
            name:   "Pool Invariant K",
            output: abi.encode(poolConvertToExitShares_, poolManagerConvertToExitShares_),
            valid:  poolConvertToExitShares_ == poolManagerConvertToExitShares_
        });
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                         **/
    /**************************************************************************************************************************************/

    // NOTE: Mirrors Pool.convertToAssets, given an already-fetched totalAssets_/totalSupply_.
    function _toAssets(uint256 shares_, uint256 totalAssets_, uint256 totalSupply_) internal pure returns (uint256 assets_) {
        assets_ = totalSupply_ == 0 ? shares_ : (shares_ * totalAssets_) / totalSupply_;
    }

}
