// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IPoolManagerLike, IStrategyLike, IStrategyManagerLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract PoolManagerHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        address poolManager_ = abi.decode(input_, (address));

        results_ = new InvariantResult[](4);

        results_[0] = _checkInvariantA(poolManager_);
        results_[1] = _checkInvariantB(poolManager_);
        results_[2] = _checkInvariantD(poolManager_);
        results_[3] = _checkInvariantE(poolManager_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: totalAssets == cash + sum(assetsOf(strategy))                                                                     ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address poolManager_) internal view returns (InvariantResult memory result_) {
        uint256 sumAssetsOfStrategies_;

        uint256 strategyCount_ = IPoolManagerLike(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount_; ++i) {
            address strategy_ = IPoolManagerLike(poolManager_).strategyList(i);

            sumAssetsOfStrategies_ += IPoolManagerLike(poolManager_).isStrategyManager(strategy_)
                ? IStrategyManagerLike(strategy_).assetsOf(poolManager_)
                : IStrategyLike(strategy_).assetsUnderManagement();
        }

        address asset_ = IPoolManagerLike(poolManager_).asset();
        address pool_  = IPoolManagerLike(poolManager_).pool();

        uint256 cash_        = IERC20(asset_).balanceOf(pool_);
        uint256 totalAssets_ = IPoolManagerLike(poolManager_).totalAssets();

        result_ = InvariantResult({
            name:   "PoolManager Invariant A",
            output: abi.encode(totalAssets_, cash_, sumAssetsOfStrategies_),
            valid:  totalAssets_ == cash_ + sumAssetsOfStrategies_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: unrealizedLosses <= totalAssets                                                                                   ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address poolManager_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_ = IPoolManagerLike(poolManager_).unrealizedLosses();
        uint256 totalAssets_      = IPoolManagerLike(poolManager_).totalAssets();

        result_ = InvariantResult({
            name:   "PoolManager Invariant B",
            output: abi.encode(unrealizedLosses_, totalAssets_),
            valid:  unrealizedLosses_ <= totalAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: isStrategy(s) XOR isStrategyManager(s), for every s in strategyList                                               ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address poolManager_) internal view returns (InvariantResult memory result_) {
        uint256 strategyCount_ = IPoolManagerLike(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount_; ++i) {
            address strategy_ = IPoolManagerLike(poolManager_).strategyList(i);

            bool isStrategy_        = IPoolManagerLike(poolManager_).isStrategy(strategy_);
            bool isStrategyManager_ = IPoolManagerLike(poolManager_).isStrategyManager(strategy_);

            if (isStrategy_ == isStrategyManager_) {
                return InvariantResult({
                    name:   "PoolManager Invariant D",
                    output: abi.encode(strategy_, isStrategy_, isStrategyManager_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "PoolManager Invariant D",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: every strategyList address is unique                                                                              ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address poolManager_) internal view returns (InvariantResult memory result_) {
        uint256 strategyCount_ = IPoolManagerLike(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount_; ++i) {
            address strategy_ = IPoolManagerLike(poolManager_).strategyList(i);

            for (uint256 j = i + 1; j < strategyCount_; ++j) {
                if (IPoolManagerLike(poolManager_).strategyList(j) == strategy_) {
                    return InvariantResult({
                        name:   "PoolManager Invariant E",
                        output: abi.encode(strategy_, i, j),
                        valid:  false
                    });
                }
            }
        }

        result_ = InvariantResult({
            name:   "PoolManager Invariant E",
            output: "",
            valid:  true
        });
    }

}
