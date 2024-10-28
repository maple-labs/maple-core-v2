// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IInvariantTest,
    IMockERC20,
    IPool,
    IPoolManager,
    IWithdrawalManagerQueue as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract QueueWithdrawalHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public lps;

    IMockERC20         asset;
    IPool              pool;
    IPoolManager       pm;
    IWithdrawalManager wm;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address pool_, address[] memory lps_) {
        testContract = IInvariantTest(msg.sender);

        pool  = IPool(pool_);
        asset = IMockERC20(pool.asset());

        pm = IPoolManager(pool.manager());
        wm = IWithdrawalManager(pm.withdrawalManager());

        lps = lps_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function processRedemptions(uint256 seed_) external useTimestamps {
        console.log("qwm.processRedemptions(%s)", seed_);
        numberOfCalls["qwm.processRedemptions"]++;

        uint256 sharesToProcess_ = _bound(_randomize(seed_, "shares"), 0, wm.totalShares());

        if (sharesToProcess_ == 0) return;

        // Deposit underlying asset from random LP to ensure enough liquidity to withdraw (as opposed to loan returning funds)
        address depositLp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        uint256 assetsRequired_ = pool.previewMint(sharesToProcess_);

        vm.startPrank(depositLp_);
        asset.mint(depositLp_, assetsRequired_);
        asset.approve(address(pool), assetsRequired_);

        pool.deposit(assetsRequired_, depositLp_);
        vm.stopPrank();

        vm.prank(pm.poolDelegate());
        wm.processRedemptions(sharesToProcess_);
    }

    function redeem(uint256 seed_) external useTimestamps {
        console.log("qwm.redeem(%s)", seed_);
        numberOfCalls["qwm.redeem"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        uint256 sharesAvailable_ = wm.manualSharesAvailable(lp_);

        if (sharesAvailable_ == 0) return;

        uint256 sharesToRedeem_ = _bound(_randomize(seed_, "shares"), 1, sharesAvailable_);

        // Deposit underlying asset from random LP to ensure enough liquidity to withdraw (as opposed to loan returning funds)
        address depositLp_ = lps[_bound(_randomize(seed_, "depositLp"), 0, lps.length - 1)];

        uint256 assetsRequired_ = pool.previewMint(sharesToRedeem_);

        vm.startPrank(depositLp_);
        asset.mint(depositLp_, assetsRequired_);
        asset.approve(address(pool), assetsRequired_);

        pool.deposit(assetsRequired_, depositLp_);
        vm.stopPrank();

        vm.prank(lp_);
        pool.redeem(sharesToRedeem_, lp_, lp_);
    }

    function removeRequest(uint256 seed_) external useTimestamps {
        console.log("qwm.removeRequest(%s)", seed_);
        numberOfCalls["qwm.removeRequest"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        uint128 requestId_ = wm.requestIds(lp_);

        if (requestId_ == 0) return;

        vm.prank(pm.poolDelegate());
        wm.removeRequest(lp_);
    }

    function removeShares(uint256 seed_) external useTimestamps {
        console.log("qwm.removeShares(%s)", seed_);
        numberOfCalls["qwm.removeShares"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        uint128 requestId_ = wm.requestIds(lp_);

        if (requestId_ == 0) return;

        ( , uint256 sharesLocked_ ) = wm.requests(requestId_);

        if (sharesLocked_ == 0) return;

        uint256 sharesToRemove_ = _bound(_randomize(seed_, "shares"), 1, sharesLocked_);

        vm.prank(lp_);
        pool.removeShares(sharesToRemove_, lp_);
    }

    function requestRedeem(uint256 seed_) external useTimestamps {
        console.log("qwm.requestRedeem(%s)", seed_);
        numberOfCalls["qwm.requestRedeem"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        if (pool.balanceOf(lp_) == 0) return;

        uint128 requestId_ = wm.requestIds(lp_);

        if (requestId_ != 0) return;

        uint256 sharesToRequest_ = _bound(_randomize(seed_, "shares"), 1, pool.balanceOf(lp_));

        vm.prank(lp_);
        pool.requestRedeem(sharesToRequest_, lp_);
    }

    function setManualWithdrawal(uint256 seed_) external useTimestamps {
        console.log("qwm.setManualWithdrawal(%s)", seed_);
        numberOfCalls["qwm.setManualWithdrawal"]++;

        address lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        uint128 requestId_ = wm.requestIds(lp_);

        if (requestId_ != 0) return;

        vm.startPrank(pm.poolDelegate());
        wm.setManualWithdrawal(lp_, !wm.isManualWithdrawal(lp_));
        vm.stopPrank();
    }

}
