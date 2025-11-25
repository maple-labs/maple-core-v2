// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IMockERC20,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract DepositHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] lps;

    IMockERC20 asset;
    IPool      pool;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address pool_, address[] memory lps_) {
        pool  = IPool(pool_);
        asset = IMockERC20(pool.asset());
        lps   = lps_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deposit(uint256 seed_) external {
        console.log("depositHandler.deposit(%s)", seed_);
        numberOfCalls["depositHandler.deposit"]++;

        // Set to max resolution / 10 of LM
        uint256 totalAssets_  = pool.totalAssets();
        uint256 liquidityCap_ = IPoolManager(pool.manager()).liquidityCap();
        uint256 maxDeposit_   = 1_000_000e6;

        if (liquidityCap_ - totalAssets_ < maxDeposit_) {
            maxDeposit_ = liquidityCap_ - totalAssets_;
        }

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 100, maxDeposit_);
        address lp_     = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];

        vm.startPrank(lp_);
        asset.mint(lp_, assets_);
        asset.approve(address(pool), assets_);

        pool.deposit(assets_, lp_);
        vm.stopPrank();
    }

    function mint(uint256 seed_) external {
        console.log("depositHandler.mint(%s)", seed_);
        numberOfCalls["depositHandler.mint"]++;

        // The first mint needs to be large enough to not lock mints if total assets eventually become zero due to defaults.
        address lp_     = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];
        uint256 shares_ = _bound(_randomize(seed_, "shares"), 10, 1_000_000e6);
        uint256 assets_ = pool.totalSupply() == 0 ? shares_ : shares_ * pool.totalAssets() / pool.totalSupply() + 100;

        vm.startPrank(lp_);
        asset.mint(lp_, assets_);
        asset.approve(address(pool), assets_);

        pool.mint(shares_, lp_);
        vm.stopPrank();
    }

}
