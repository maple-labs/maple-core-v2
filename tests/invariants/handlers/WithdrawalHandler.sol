// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPool, IPoolManager, IWithdrawalManagerQueue as IWithdrawalManager } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract WithdrawalHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address asset;

    address[] lps;
    address[] pools;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_, address[] memory pools_, address[] memory lps_) HandlerBase(handlerName_) {
        pools = pools_;
        lps   = lps_;

        asset = IPool(pools_[0]).asset();

        for (uint256 i = 1; i < pools_.length; i++) {
            require(IPool(pools_[i]).asset() == asset, "WH:INVALID_ASSET");
        }
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function processRedemptions(uint256 seed_) external {
        (address pool_, address poolManager_, address withdrawalManager_) = _selectPool(seed_);

        uint256 sharesToProcess_ = _selectSharesToProcess(seed_, withdrawalManager_);

        if (sharesToProcess_ == 0) {
            _recordSkip();
            return;
        }

        _fundPoolLiquidity(seed_, pool_, sharesToProcess_);

        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IWithdrawalManager(withdrawalManager_).processRedemptions(sharesToProcess_);
    }

    function processEmptyRedemptions(uint256 seed_) external {
        (, address poolManager_, address withdrawalManager_) = _selectPool(seed_);

        (uint128 nextRequestId_, uint128 lastRequestId_) = IWithdrawalManager(withdrawalManager_).queue();

        if (nextRequestId_ > lastRequestId_) {
            _recordSkip();
            return;
        }

        uint256 numberOfRequestsToProcess_ = _selectNumberOfEmptyRequests(seed_, nextRequestId_, lastRequestId_);

        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IWithdrawalManager(withdrawalManager_).processEmptyRedemptions(numberOfRequestsToProcess_);
    }

    function redeem(uint256 seed_) external {
        (address pool_,, address withdrawalManager_) = _selectPool(seed_);

        address lp_              = _selectRedeemLp(seed_);
        uint256 sharesAvailable_ = IWithdrawalManager(withdrawalManager_).manualSharesAvailable(lp_);

        if (sharesAvailable_ == 0) {
            _recordSkip();
            return;
        }

        uint256 sharesToRedeem_ = _selectSharesToRedeem(seed_, sharesAvailable_);

        _fundPoolLiquidity(seed_, pool_, sharesToRedeem_);

        vm.prank(lp_);
        IPool(pool_).redeem(sharesToRedeem_, lp_, lp_);
    }

    function removeRequest(uint256 seed_) external {
        (, address poolManager_, address withdrawalManager_) = _selectPool(seed_);

        address lp_ = _selectRedeemLp(seed_);

        (uint256[] memory requestIds_,) = IWithdrawalManager(withdrawalManager_).requestsByOwner(lp_);

        if (requestIds_.length == 0) {
            _recordSkip();
            return;
        }

        (, uint256 requestIdToRemove_) = _selectRequestToRemove(seed_, requestIds_);

        uint256[] memory requestIdsToRemove_ = new uint256[](1);
        requestIdsToRemove_[0]               = requestIdToRemove_;

        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IWithdrawalManager(withdrawalManager_).removeRequest(lp_, requestIdsToRemove_);
    }

    function removeShares(uint256 seed_) external {
        (address pool_,, address withdrawalManager_) = _selectPool(seed_);

        address lp_ = _selectRedeemLp(seed_);

        (, uint256[] memory shares_) = IWithdrawalManager(withdrawalManager_).requestsByOwner(lp_);

        uint256 totalShares_ = 0;

        for (uint256 i; i < shares_.length; i++) {
            totalShares_ += shares_[i];
        }

        if (totalShares_ == 0) {
            _recordSkip();
            return;
        }

        uint256 sharesToRemove_ = _selectSharesToRemove(seed_, totalShares_);

        vm.prank(lp_);
        IPool(pool_).removeShares(sharesToRemove_, lp_);
    }

    function removeSharesById(uint256 seed_) external {
        (,, address withdrawalManager_) = _selectPool(seed_);

        address lp_ = _selectRedeemLp(seed_);

        (uint256[] memory requestIds_, uint256[] memory sharesPerRequest_) = IWithdrawalManager(withdrawalManager_).requestsByOwner(lp_);

        if (requestIds_.length == 0) {
            _recordSkip();
            return;
        }

        (uint256 indexOfRequestToRemove_, uint256 requestIdToRemove_) = _selectRequestToRemove(seed_, requestIds_);

        uint256 sharesToRemove_ = _selectSharesToRemove(seed_, sharesPerRequest_[indexOfRequestToRemove_]);

        vm.prank(lp_);
        IWithdrawalManager(withdrawalManager_).removeSharesById(requestIdToRemove_, sharesToRemove_);
    }

    function requestRedeem(uint256 seed_) external {
        (address pool_,,) = _selectPool(seed_);

        address lp_      = _selectRedeemLp(seed_);
        uint256 balance_ = IPool(pool_).balanceOf(lp_);

        if (balance_ == 0) {
            _recordSkip();
            return;
        }

        uint256 sharesToRequest_ = _selectSharesToRequest(seed_, balance_);

        vm.prank(lp_);
        IPool(pool_).requestRedeem(sharesToRequest_, lp_);
    }

    function setManualWithdrawal(uint256 seed_) external {
        (, address poolManager_, address withdrawalManager_) = _selectPool(seed_);

        address lp_ = _selectRedeemLp(seed_);

        uint256 requestId_ = IWithdrawalManager(withdrawalManager_).requestIds(lp_);

        if (requestId_ != 0) {
            _recordSkip();
            return;
        }

        bool isManualWithdrawal_ = IWithdrawalManager(withdrawalManager_).isManualWithdrawal(lp_);

        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IWithdrawalManager(withdrawalManager_).setManualWithdrawal(lp_, !isManualWithdrawal_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _fundPoolLiquidity(uint256 seed_, address pool_, uint256 shares_) internal {
        address depositLp_      = _selectDepositLp(seed_);
        uint256 assetsRequired_ = IPool(pool_).previewMint(shares_);

        erc20_mint(asset, depositLp_, assetsRequired_);
        erc20_approve(asset, depositLp_, pool_, assetsRequired_);

        vm.prank(depositLp_);
        IPool(pool_).deposit(assetsRequired_, depositLp_);
    }

    function _selectDepositLp(uint256 seed_) internal view returns (address lp_) {
        lp_ = lps[_bound(_randomize(seed_, "depositLp"), 0, lps.length - 1)];
    }

    function _selectNumberOfEmptyRequests(
        uint256 seed_,
        uint128 nextRequestId_,
        uint128 lastRequestId_
    )
        internal
        pure
        returns (uint256 numberOfRequestsToProcess_)
    {
        uint256 numberOfRequests_ = lastRequestId_ - nextRequestId_ + 1;

        numberOfRequestsToProcess_ = _bound(_randomize(seed_, "numberOfEmptyRequests"), 1, numberOfRequests_);
    }

    function _selectPool(uint256 seed_) internal view returns (address pool_, address poolManager_, address withdrawalManager_) {
        pool_ = pools[_bound(_randomize(seed_, "pool"), 0, pools.length - 1)];

        poolManager_       = IPool(pool_).manager();
        withdrawalManager_ = IPoolManager(poolManager_).withdrawalManager();
    }

    function _selectRedeemLp(uint256 seed_) internal view returns (address lp_) {
        lp_ = lps[_bound(_randomize(seed_, "redeemLp"), 0, lps.length - 1)];
    }

    function _selectRequestToRemove(uint256 seed_, uint256[] memory requestIds_)
        internal
        pure
        returns (uint256 index_, uint256 requestId_)
    {
        index_     = _bound(_randomize(seed_, "indexOfRequestToRemove"), 0, requestIds_.length - 1);
        requestId_ = requestIds_[index_];
    }

    function _selectSharesToProcess(uint256 seed_, address withdrawalManager_) internal view returns (uint256 sharesToProcess_) {
        sharesToProcess_ = _bound(_randomize(seed_, "shares"), 0, IWithdrawalManager(withdrawalManager_).totalShares());
    }

    function _selectSharesToRedeem(uint256 seed_, uint256 sharesAvailable_) internal pure returns (uint256 sharesToRedeem_) {
        sharesToRedeem_ = _bound(_randomize(seed_, "shares"), 1, sharesAvailable_);
    }

    function _selectSharesToRemove(uint256 seed_, uint256 maxShares_) internal pure returns (uint256 sharesToRemove_) {
        sharesToRemove_ = _bound(_randomize(seed_, "shares"), 1, maxShares_);
    }

    function _selectSharesToRequest(uint256 seed_, uint256 balance_) internal pure returns (uint256 sharesToRequest_) {
        sharesToRequest_ = _bound(_randomize(seed_, "shares"), 1, balance_);
    }

}
