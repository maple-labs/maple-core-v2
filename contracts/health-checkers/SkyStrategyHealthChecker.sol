// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IPSMLike, ISkyStrategyLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract SkyStrategyHealthChecker is IHealthChecker {

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        address strategy_ = abi.decode(input_, (address));

        results_ = new InvariantResult[](7);

        results_[0] = _checkInvariantC(strategy_);
        results_[1] = _checkInvariantD(strategy_);
        results_[2] = _checkInvariantE(strategy_);
        results_[3] = _checkInvariantF(strategy_);
        results_[4] = _checkInvariantG(strategy_);
        results_[5] = _checkInvariantH(strategy_);
        results_[6] = _checkInvariantI(strategy_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: allowance(strategy, psm) == 0 && allowance(strategy, savingsUsds) == 0                                            ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(address strategy_) internal view returns (InvariantResult memory result_) {
        address usds_        = ISkyStrategyLike(strategy_).usds();
        address psm_         = ISkyStrategyLike(strategy_).psm();
        address savingsUsds_ = ISkyStrategyLike(strategy_).savingsUsds();

        uint256 psmAllowance_         = IERC20(usds_).allowance(strategy_, psm_);
        uint256 savingsUsdsAllowance_ = IERC20(usds_).allowance(strategy_, savingsUsds_);

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant C",
            output: abi.encode(psmAllowance_, savingsUsdsAllowance_),
            valid:  psmAllowance_ == 0 && savingsUsdsAllowance_ == 0
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant D: gemForUsds(usdsForGem(x)) ~= x, using assetsUnderManagement() as x, tolerance of 2                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantD(address strategy_) internal view returns (InvariantResult memory result_) {
        address psm_ = ISkyStrategyLike(strategy_).psm();

        uint256 gemAmount_    = ISkyStrategyLike(strategy_).assetsUnderManagement();
        uint256 usdsAmount_   = _usdsForGem(strategy_, psm_, gemAmount_);
        uint256 roundTripGem_ = _gemForUsds(strategy_, psm_, usdsAmount_);

        uint256 diff_ = roundTripGem_ > gemAmount_ ? roundTripGem_ - gemAmount_ : gemAmount_ - roundTripGem_;

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant D",
            output: abi.encode(gemAmount_, roundTripGem_),
            valid:  diff_ <= 2
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant E: assetsUnderManagement() >= lastRecordedTotalAssets                                                                ***/
    /**************************************************************************************************************************************/

    function _checkInvariantE(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 assetsUnderManagement_   = ISkyStrategyLike(strategy_).assetsUnderManagement();
        uint256 lastRecordedTotalAssets_ = ISkyStrategyLike(strategy_).lastRecordedTotalAssets();

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant E",
            output: abi.encode(assetsUnderManagement_, lastRecordedTotalAssets_),
            valid:  assetsUnderManagement_ >= lastRecordedTotalAssets_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant F: availableToWithdraw() <= assetsUnderManagement()                                                                  ***/
    /**************************************************************************************************************************************/

    function _checkInvariantF(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 availableToWithdraw_   = ISkyStrategyLike(strategy_).availableToWithdraw();
        uint256 assetsUnderManagement_ = ISkyStrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant F",
            output: abi.encode(availableToWithdraw_, assetsUnderManagement_),
            valid:  availableToWithdraw_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant G: availableToWithdraw() <= fundsAsset.balanceOf(psm.pocket())                                                       ***/
    /**************************************************************************************************************************************/

    function _checkInvariantG(address strategy_) internal view returns (InvariantResult memory result_) {
        address fundsAsset_ = ISkyStrategyLike(strategy_).fundsAsset();
        address psm_        = ISkyStrategyLike(strategy_).psm();

        uint256 pocketBalance_       = IERC20(fundsAsset_).balanceOf(IPSMLike(psm_).pocket());
        uint256 availableToWithdraw_ = ISkyStrategyLike(strategy_).availableToWithdraw();

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant G",
            output: abi.encode(availableToWithdraw_, pocketBalance_),
            valid:  availableToWithdraw_ <= pocketBalance_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant H: unrealizedLosses() <= assetsUnderManagement()                                                                     ***/
    /**************************************************************************************************************************************/

    function _checkInvariantH(address strategy_) internal view returns (InvariantResult memory result_) {
        uint256 unrealizedLosses_      = ISkyStrategyLike(strategy_).unrealizedLosses();
        uint256 assetsUnderManagement_ = ISkyStrategyLike(strategy_).assetsUnderManagement();

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant H",
            output: abi.encode(unrealizedLosses_, assetsUnderManagement_),
            valid:  unrealizedLosses_ <= assetsUnderManagement_
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant I: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6                                                          ***/
    /**************************************************************************************************************************************/

    function _checkInvariantI(address strategy_) internal view returns (InvariantResult memory result_) {
        uint32 delegateFeeRate_ = ISkyStrategyLike(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate_ = ISkyStrategyLike(strategy_).strategyProtocolFeeRate();

        result_ = InvariantResult({
            name:   "SkyStrategy Invariant I",
            output: abi.encode(delegateFeeRate_, protocolFeeRate_),
            valid:  delegateFeeRate_ + protocolFeeRate_ <= 1e6
        });
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _gemForUsds(address strategy_, address psm_, uint256 usdsAmount_) internal view returns (uint256 gemAmount_) {
        uint256 tout_ = _resolveTout(strategy_, psm_);
        uint256 to18_ = IPSMLike(psm_).to18ConversionFactor();

        gemAmount_ = (usdsAmount_ * 1e18) / (to18_ * (1e18 + tout_));
    }

    function _resolveTout(address strategy_, address psm_) internal view returns (uint256 tout_) {
        tout_ = IPSMLike(psm_).tout();

        if (tout_ == type(uint256).max) tout_ = ISkyStrategyLike(strategy_).fallbackTout();
    }

    function _usdsForGem(address strategy_, address psm_, uint256 gemAmount_) internal view returns (uint256 usdsAmount_) {
        uint256 tout_     = _resolveTout(strategy_, psm_);
        uint256 to18_     = IPSMLike(psm_).to18ConversionFactor();
        uint256 gemAmt18_ = gemAmount_ * to18_;

        usdsAmount_ = gemAmt18_ + gemAmt18_ * tout_ / 1e18;
    }

}
