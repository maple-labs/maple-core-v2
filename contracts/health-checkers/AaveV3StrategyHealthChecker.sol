// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAavePoolLike, IAaveV3StrategyLike, IERC20 } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract AaveV3StrategyHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        address strategy_ = abi.decode(input_, (address));

        results_ = new InvariantResult[](7);

        results_[0] = _checkInvariantD(strategy_);
        results_[1] = _checkInvariantE(strategy_);
        results_[2] = _checkInvariantF(strategy_);
        results_[3] = _checkInvariantG(strategy_);
        results_[4] = _checkInvariantH(strategy_);
        results_[5] = _checkInvariantI(strategy_);
        results_[6] = _checkInvariantJ(strategy_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: fundsAsset.allowance(strategy, aavePool) == 0                                                                     ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address strategy_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = IAaveV3StrategyLike(strategy_).fundsAsset();
        address aavePool_   = IAaveV3StrategyLike(strategy_).aavePool();

        uint256 allowance_ = IERC20(fundsAsset_).allowance(strategy_, aavePool_);

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant D",
            output: abi.encode(allowance_),
            valid:  allowance_ == 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: aToken.balanceOf(strategy) >= lastRecordedTotalAssets                                                             ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address strategy_) internal view returns (InvariantResult memory result_) {
        address aaveToken_ = IAaveV3StrategyLike(strategy_).aaveToken();

        uint256 aTokenBalance_           = IERC20(aaveToken_).balanceOf(strategy_);
        uint256 lastRecordedTotalAssets_ = IAaveV3StrategyLike(strategy_).lastRecordedTotalAssets();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant E",
            output: abi.encode(aTokenBalance_, lastRecordedTotalAssets_),
            valid:  aTokenBalance_ >= lastRecordedTotalAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: assetsUnderManagement() >= lastRecordedTotalAssets                                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 assetsUnderManagement_   = IAaveV3StrategyLike(strategy_).assetsUnderManagement();
        uint256 lastRecordedTotalAssets_ = IAaveV3StrategyLike(strategy_).lastRecordedTotalAssets();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant F",
            output: abi.encode(assetsUnderManagement_, lastRecordedTotalAssets_),
            valid:  assetsUnderManagement_ >= lastRecordedTotalAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: availableToWithdraw() <= assetsUnderManagement()                                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 availableToWithdraw_   = IAaveV3StrategyLike(strategy_).availableToWithdraw();
        uint256 assetsUnderManagement_ = IAaveV3StrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant G",
            output: abi.encode(availableToWithdraw_, assetsUnderManagement_),
            valid:  availableToWithdraw_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: availableToWithdraw() <= aaveLiquidity                                                                            ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(address strategy_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = IAaveV3StrategyLike(strategy_).fundsAsset();
        address aavePool_   = IAaveV3StrategyLike(strategy_).aavePool();
        address aaveToken_  = IAaveV3StrategyLike(strategy_).aaveToken();

        uint256 aaveLiquidity_ = IAaveV3StrategyLike(strategy_).useVirtualUnderlyingBalance()
            ? uint256(IAavePoolLike(aavePool_).getVirtualUnderlyingBalance(fundsAsset_))
            : IERC20(fundsAsset_).balanceOf(aaveToken_);

        uint256 availableToWithdraw_ = IAaveV3StrategyLike(strategy_).availableToWithdraw();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant H",
            output: abi.encode(availableToWithdraw_, aaveLiquidity_),
            valid:  availableToWithdraw_ <= aaveLiquidity_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: unrealizedLosses() <= assetsUnderManagement()                                                                     ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_      = IAaveV3StrategyLike(strategy_).unrealizedLosses();
        uint256 assetsUnderManagement_ = IAaveV3StrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant I",
            output: abi.encode(unrealizedLosses_, assetsUnderManagement_),
            valid:  unrealizedLosses_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant J: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6                                                          ***/
    /**************************************************************************************************************************************/

    function _checkInvariantJ(address strategy_) internal view returns (InvariantResult memory result_) {
        uint32 delegateFeeRate_ = IAaveV3StrategyLike(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate_ = IAaveV3StrategyLike(strategy_).strategyProtocolFeeRate();

        result_ = InvariantResult({
            name:   "AaveV3Strategy Invariant J",
            output: abi.encode(delegateFeeRate_, protocolFeeRate_),
            valid:  delegateFeeRate_ + protocolFeeRate_ <= 1e6
        });
    }

}
