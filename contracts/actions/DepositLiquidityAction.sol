// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { IERC20Like, IPoolLike, IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract DepositLiquidityAction is Action {

    address lp;

    uint256 amount;

    IERC20Like       asset;
    IPoolLike        pool;
    IPoolManagerLike poolManager;

    constructor(
        uint256 timestamp_,
        string memory description_,
        IPoolManagerLike poolManager_,
        address lp_,
        uint256 amount_
    )
        Action(timestamp_, description_)
    {
        poolManager = poolManager_;
        lp          = lp_;
        amount      = amount_;
        pool        = IPoolLike(poolManager_.pool());
        asset       = IERC20Like(poolManager_.asset());
    }

    function act() external override {
        vm.startPrank(lp);
        asset.mint(lp, amount);
        asset.approve(address(pool), amount);
        pool.deposit(amount, lp);
        vm.stopPrank();
    }

}
