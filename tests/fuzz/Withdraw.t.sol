// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { FuzzBase } from "./FuzzBase.sol";

contract WithdrawFuzzTests is FuzzBase {

    function testDeepFuzz_withdraw_all(
        address caller,
        address owner,
        address receiver,
        uint256 totalSupply,
        uint256 totalAssets,
        uint256 unrealizedLosses,
        uint256 assetsToWithdraw,
        uint256 receiverAssets,
        uint256 availableAssets
    ) external {
        if (owner    == address(0)) owner    = address(1);
        if (caller   == address(0)) caller   = address(1);
        if (receiver == address(0)) receiver = address(1);

        vm.assume(owner    != address(pool));
        vm.assume(caller   != address(pool));
        vm.assume(receiver != address(pool));
        vm.assume(receiver != address(this));

        totalSupply      = bound(totalSupply,      0, 1e29);
        totalAssets      = bound(totalAssets,      0, 1e20);
        unrealizedLosses = bound(unrealizedLosses, 0, totalAssets);
        assetsToWithdraw = bound(assetsToWithdraw, 1, 1e20);
        receiverAssets   = bound(receiverAssets,   0, 1e20);
        availableAssets  = bound(availableAssets,  0, totalAssets - unrealizedLosses);

        if ((totalAssets - unrealizedLosses) == 0) return;

        uint256 escrowShares = divRoundUp(assetsToWithdraw * totalSupply, totalAssets - unrealizedLosses);
        uint256 ownerShares  = escrowShares;

        if (ownerShares > totalSupply) {
            ownerShares = totalSupply;
        }

        mintShares(owner, ownerShares, totalSupply);
        mintAssets(receiver, receiverAssets);
        setupPool(totalAssets, unrealizedLosses, availableAssets);

        vm.prank(owner);
        pool.approve(caller, type(uint256).max);

        if (escrowShares > ownerShares) {
            vm.expectRevert(arithmeticError);
            pool.requestWithdraw(assetsToWithdraw, owner);
            return;
        }

        vm.startPrank(caller);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assetsToWithdraw, owner);

        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assetsToWithdraw, receiver, owner);
    }

    function divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ + divisor_ - 1) / divisor_;
    }

}
