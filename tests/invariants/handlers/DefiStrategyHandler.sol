// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IUnderlyingStrategyLike } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

abstract contract DefiStrategyHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 public totalYield;
    uint256 public totalFees;

    address public underlyingStrategy;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_, address underlyingStrategy_) HandlerBase(handlerName_) {
        underlyingStrategy = underlyingStrategy_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function impair(uint256 seed_) external {
        uint256 maxTotalImpairment_ = 2 * IUnderlyingStrategyLike(underlyingStrategy).assetsUnderManagement();
        uint256 currentImpairment_  = IUnderlyingStrategyLike(underlyingStrategy).impairedAssets();

        if (currentImpairment_ >= maxTotalImpairment_) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(seed_, 1, maxTotalImpairment_ - currentImpairment_);

        impairStrategy(underlyingStrategy, assets_);
    }

    function removeImpairment(uint256 seed_) external {
        uint256 impairedAssets_ = IUnderlyingStrategyLike(underlyingStrategy).impairedAssets();

        if (impairedAssets_ == 0) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(seed_, 1, impairedAssets_);

        removeStrategyImpairment(underlyingStrategy, assets_);
    }

    function setStrategyDelegateFeeRate(uint256 seed_) external {
        uint256 currentDelegateFeeRate_ = IUnderlyingStrategyLike(underlyingStrategy).strategyDelegateFeeRate();
        uint256 currentProtocolFeeRate_ = IUnderlyingStrategyLike(underlyingStrategy).strategyProtocolFeeRate();

        uint256 feeRate_ = _bound(seed_, 0, 1e6 - currentProtocolFeeRate_);

        if (feeRate_ == currentDelegateFeeRate_) {
            _recordSkip();
            return;
        }

        _syncYieldAndFees();

        setStrategyDelegateFeeRate(underlyingStrategy, uint32(feeRate_));
    }

    function setStrategyProtocolFeeRate(uint256 seed_) external {
        uint256 currentDelegateFeeRate_ = IUnderlyingStrategyLike(underlyingStrategy).strategyDelegateFeeRate();
        uint256 currentProtocolFeeRate_ = IUnderlyingStrategyLike(underlyingStrategy).strategyProtocolFeeRate();

        uint256 feeRate_ = _bound(seed_, 0, 1e6 - currentDelegateFeeRate_);

        if (feeRate_ == currentProtocolFeeRate_) {
            _recordSkip();
            return;
        }

        _syncYieldAndFees();

        setStrategyProtocolFeeRate(underlyingStrategy, uint32(feeRate_));
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentTotalAssets() internal view virtual returns (uint256 currentTotalAssets_);

    function _syncYieldAndFees() public {
        uint256 currentTotalAssets_ = _currentTotalAssets();
        uint256 lastRecorded_       = IUnderlyingStrategyLike(underlyingStrategy).lastRecordedTotalAssets();

        if (currentTotalAssets_ <= lastRecorded_) return;

        uint256 yieldAccrued_ = currentTotalAssets_ - lastRecorded_;
        uint256 delegateFee_  = yieldAccrued_ * IUnderlyingStrategyLike(underlyingStrategy).strategyDelegateFeeRate() / 1e6;
        uint256 protocolFee_  = yieldAccrued_ * IUnderlyingStrategyLike(underlyingStrategy).strategyProtocolFeeRate() / 1e6;

        totalYield += yieldAccrued_;
        totalFees  += delegateFee_ + protocolFee_;
    }

}
