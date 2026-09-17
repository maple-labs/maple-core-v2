// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IPoolManager,
    IStrategyHandler,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

// TODO: Add action that performs an atomic withdrawal.
contract StrategyManagerHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public strategyManagers;
    address[] public poolManagers;

    mapping(address => address) public strategyHandlerOf;

    mapping(address => uint256) public totalFundingsOf;
    mapping(address => uint256) public totalWithdrawalsOf;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        string    memory handlerName_,
        address[] memory strategyManagers_,
        address[] memory poolManagers_,
        address[] memory strategyHandlers_
    )
        HandlerBase(handlerName_)
    {
        require(strategyHandlers_.length == strategyManagers_.length, "SMH:CONSTRUCTOR:LENGTH_MISMATCH");

        strategyManagers = strategyManagers_;
        poolManagers     = poolManagers_;

        for (uint256 i; i < strategyManagers_.length; ++i) {
            strategyHandlerOf[strategyManagers_[i]] = strategyHandlers_[i];
        }
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function fundStrategyManager(uint256 seed_) external {
        address strategyManager_ = _selectStrategyManager(seed_);

        ( address poolManager_, uint256 maxAssets_ ) = _selectFundablePoolManager(seed_);

        if (poolManager_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 1, maxAssets_);

        _syncYieldAndFees(strategyManager_);

        fundStrategyManager(poolManager_, strategyManager_, assets_);

        totalFundingsOf[strategyManager_] += assets_;
    }

    function requestRedeem(uint256 seed_) external {
        address strategyManager_ = _selectStrategyManager(seed_);

        ( address poolManager_, uint256 freeShares_ ) = _selectPoolManagerWithFreeShares(strategyManager_, seed_);

        if (poolManager_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 shares_ = _bound(_randomize(seed_, "shares"), 1, freeShares_);

        requestRedeemFromStrategyManager(poolManager_, strategyManager_, shares_);
    }

    function cancelRedemption(uint256 seed_) external {
        address strategyManager_ = _selectStrategyManager(seed_);

        ( address poolManager_, uint256 pendingShares_ ) = _selectPoolManagerWithPendingShares(strategyManager_, seed_);

        if (poolManager_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 shares_ = _bound(_randomize(seed_, "shares"), 1, pendingShares_);

        cancelRedemptionFromStrategyManager(poolManager_, strategyManager_, shares_);
    }

    function processRedemption(uint256 seed_) external {
        address strategyManager_ = _selectStrategyManager(seed_);

        ( address poolManager_, uint256 pendingShares_ ) = _selectPoolManagerWithPendingShares(strategyManager_, seed_);

        if (poolManager_ == address(0)) {
            _recordSkip();
            return;
        }

        ( uint256 shares_, uint256 assets_ ) = _boundProcessableRedemption(strategyManager_, pendingShares_, seed_, "shares");

        if (shares_ == 0) {
            _recordSkip();
            return;
        }

        _syncYieldAndFees(strategyManager_);

        processRedemptionFromStrategyManager(poolManager_, strategyManager_, shares_);

        totalWithdrawalsOf[strategyManager_] += assets_;
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _boundProcessableRedemption(
        address strategyManager_,
        uint256 pendingShares_,
        uint256 seed_,
        string memory salt_
    )
        internal view returns (uint256 shares_, uint256 assets_)
    {
        uint256 assetsUnderManagement_ = IStrategyManager(strategyManager_).assetsUnderManagement();
        uint256 unrealizedLosses_      = IStrategyManager(strategyManager_).unrealizedLosses();

        if (unrealizedLosses_ >= assetsUnderManagement_) return (0, 0);

        uint256 availableAssets_  = IStrategyManager(strategyManager_).availableToWithdraw();
        uint256 redeemableShares_ = _min(pendingShares_, IStrategyManager(strategyManager_).convertToExitShares(availableAssets_));

        if (redeemableShares_ == 0) return (0, 0);

        shares_ = _bound(_randomize(seed_, salt_), 1, redeemableShares_);
        assets_ = IStrategyManager(strategyManager_).convertToExitAssets(shares_);

        if (assets_ == 0) return (0, 0);
    }

    function _maxFundableAssets(address poolManager_) internal view returns (uint256 maxAssets_) {
        address asset_ = IPoolManager(poolManager_).asset();
        address pool_  = IPoolManager(poolManager_).pool();

        maxAssets_ = IERC20(asset_).balanceOf(pool_);
    }

    function _selectFundablePoolManager(uint256 seed_) internal view returns (address poolManager_, uint256 maxAssets_) {
        uint256 count_;

        address[] memory candidates_ = new address[](poolManagers.length);
        uint256[] memory assets_     = new uint256[](poolManagers.length);

        for (uint256 i; i < poolManagers.length; ++i) {
            uint256 asset_ = _maxFundableAssets(poolManagers[i]);

            if (asset_ == 0) continue;

            candidates_[count_] = poolManagers[i];
            assets_[count_]     = asset_;
            count_++;
        }

        if (count_ == 0) return (address(0), 0);

        uint256 index_ = _bound(_randomize(seed_, "poolManager"), 0, count_ - 1);

        poolManager_ = candidates_[index_];
        maxAssets_   = assets_[index_];
    }

    function _selectPoolManagerWithFreeShares(
        address strategyManager_,
        uint256 seed_
    )
        internal view returns (address poolManager_, uint256 freeShares_)
    {
        uint256 count_;

        address[] memory candidates_ = new address[](poolManagers.length);
        uint256[] memory amounts_    = new uint256[](poolManagers.length);

        for (uint256 i; i < poolManagers.length; ++i) {
            address candidate_ = poolManagers[i];

            uint256 totalShares_   = IStrategyManager(strategyManager_).sharesOf(candidate_);
            uint256 pendingShares_ = IStrategyManager(strategyManager_).pendingSharesOf(candidate_);

            if (totalShares_ <= pendingShares_) continue;

            candidates_[count_] = candidate_;
            amounts_[count_]    = totalShares_ - pendingShares_;
            count_++;
        }

        if (count_ == 0) return (address(0), 0);

        uint256 index_ = _bound(_randomize(seed_, "poolManager"), 0, count_ - 1);

        poolManager_ = candidates_[index_];
        freeShares_  = amounts_[index_];
    }

    function _selectPoolManagerWithPendingShares(
        address strategyManager_,
        uint256 seed_
    )
        internal view returns (address poolManager_, uint256 pendingShares_)
    {
        uint256 count_;

        address[] memory candidates_ = new address[](poolManagers.length);
        uint256[] memory amounts_    = new uint256[](poolManagers.length);

        for (uint256 i; i < poolManagers.length; ++i) {
            address candidate_ = poolManagers[i];

            uint256 shares_ = IStrategyManager(strategyManager_).pendingSharesOf(candidate_);

            if (shares_ == 0) continue;

            candidates_[count_] = candidate_;
            amounts_[count_]    = shares_;
            count_++;
        }

        if (count_ == 0) return (address(0), 0);

        uint256 index_ = _bound(_randomize(seed_, "poolManager"), 0, count_ - 1);

        poolManager_   = candidates_[index_];
        pendingShares_ = amounts_[index_];
    }

    function _selectStrategyManager(uint256 seed_) internal view returns (address strategyManager_) {
        strategyManager_ = strategyManagers[_bound(_randomize(seed_, "strategyManager"), 0, strategyManagers.length - 1)];
    }

    function _syncYieldAndFees(address strategyManager_) internal {
        address handler_ = strategyHandlerOf[strategyManager_];

        if (handler_ == address(0)) return;

        IStrategyHandler(handler_)._syncYieldAndFees();
    }

}
