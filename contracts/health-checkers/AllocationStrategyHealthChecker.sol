// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategyLike, IERC20 } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract AllocationStrategyHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address strategy_, address[] memory wallets_) = abi.decode(input_, (address, address[]));

        results_ = new InvariantResult[](8);

        results_[0] = _checkInvariantB(strategy_);
        results_[1] = _checkInvariantC(strategy_, wallets_);
        results_[2] = _checkInvariantE(strategy_);
        results_[3] = _checkInvariantF(strategy_);
        results_[4] = _checkInvariantG(strategy_);
        results_[5] = _checkInvariantH(strategy_);
        results_[6] = _checkInvariantI(strategy_);
        results_[7] = _checkInvariantJ(strategy_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: fundsAsset.balanceOf(strategy) >= recordedAssets                                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address strategy_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = IAllocationStrategyLike(strategy_).fundsAsset();

        uint256 balance_        = IERC20(fundsAsset_).balanceOf(strategy_);
        uint256 recordedAssets_ = IAllocationStrategyLike(strategy_).recordedAssets();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant B",
            output: abi.encode(balance_, recordedAssets_),
            valid:  balance_ >= recordedAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: totalDeployedAssets == sum(deployedAssetsOf(wallet))                                                              ***/
    /**************************************************************************************************************************************/

    // NOTE: Must include every wallet that still has deployed assets, even if it is no longer permissioned.
    function _checkInvariantC(address strategy_, address[] memory wallets_) internal view returns (InvariantResult memory result_) {
        uint256 sumDeployedAssetsOf_;

        for (uint256 i; i < wallets_.length; ++i) {
            sumDeployedAssetsOf_ += IAllocationStrategyLike(strategy_).deployedAssetsOf(wallets_[i]);
        }

        uint256 totalDeployedAssets_ = IAllocationStrategyLike(strategy_).totalDeployedAssets();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant C",
            output: abi.encode(totalDeployedAssets_, sumDeployedAssetsOf_),
            valid:  totalDeployedAssets_ == sumDeployedAssetsOf_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: availableToWithdraw() <= assetsUnderManagement()                                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 availableToWithdraw_   = IAllocationStrategyLike(strategy_).availableToWithdraw();
        uint256 assetsUnderManagement_ = IAllocationStrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant E",
            output: abi.encode(availableToWithdraw_, assetsUnderManagement_),
            valid:  availableToWithdraw_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: unrealizedLosses() <= assetsUnderManagement()                                                                     ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_      = IAllocationStrategyLike(strategy_).unrealizedLosses();
        uint256 assetsUnderManagement_ = IAllocationStrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant F",
            output: abi.encode(unrealizedLosses_, assetsUnderManagement_),
            valid:  unrealizedLosses_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: unrealizedYield() <= recordedAssets                                                                               ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedYield_ = IAllocationStrategyLike(strategy_).unrealizedYield();
        uint256 recordedAssets_  = IAllocationStrategyLike(strategy_).recordedAssets();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant G",
            output: abi.encode(unrealizedYield_, recordedAssets_),
            valid:  unrealizedYield_ <= recordedAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: unrealizedYield() <= scheduledYieldAssets()                                                                       ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedYield_      = IAllocationStrategyLike(strategy_).unrealizedYield();
        uint256 scheduledYieldAssets_ = IAllocationStrategyLike(strategy_).scheduledYieldAssets();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant H",
            output: abi.encode(unrealizedYield_, scheduledYieldAssets_),
            valid:  unrealizedYield_ <= scheduledYieldAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: yieldLastRealized <= yieldStart <= yieldDeadline                                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address strategy_) internal view returns (InvariantResult memory result_) {
        uint32 yieldStart_        = IAllocationStrategyLike(strategy_).yieldStart();
        uint32 yieldDeadline_     = IAllocationStrategyLike(strategy_).yieldDeadline();
        uint32 yieldLastRealized_ = IAllocationStrategyLike(strategy_).yieldLastRealized();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant I",
            output: abi.encode(yieldLastRealized_, yieldStart_, yieldDeadline_),
            valid:  (yieldLastRealized_ <= yieldStart_) && (yieldStart_ <= yieldDeadline_)
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant J: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6                                                          ***/
    /**************************************************************************************************************************************/

    function _checkInvariantJ(address strategy_) internal view returns (InvariantResult memory result_) {
        uint32 delegateFeeRate_ = IAllocationStrategyLike(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate_ = IAllocationStrategyLike(strategy_).strategyProtocolFeeRate();

        result_ = InvariantResult({
            name:   "AllocationStrategy Invariant J",
            output: abi.encode(delegateFeeRate_, protocolFeeRate_),
            valid:  delegateFeeRate_ + protocolFeeRate_ <= 1e6
        });
    }

}
