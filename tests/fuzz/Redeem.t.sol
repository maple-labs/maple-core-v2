// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FuzzBase } from "./FuzzBase.sol";

contract RedeemFuzzTests is FuzzBase {

    // Avoid stack too deep in tests
    address caller;
    address owner;
    address receiver;

    uint256 totalSupply;
    uint256 totalAssets;
    uint256 unrealizedLosses;
    uint256 ownerShares;
    uint256 sharesToRedeem;
    uint256 receiverAssets;
    uint256 availableAssets;
    uint256 withdrawalDelay;

    // TODO: This test is showing inconsistent behavior running locally vs on CI, even with same parameters.
    function skip_testDeepFuzz_redeem_all(address[3] memory addresses, uint256[8] memory amounts) external {
        caller   = addresses[0];
        owner    = addresses[1];
        receiver = addresses[2];

        totalSupply      = amounts[0];
        totalAssets      = amounts[1];
        unrealizedLosses = amounts[2];
        ownerShares      = amounts[3];
        sharesToRedeem   = amounts[4];
        receiverAssets   = amounts[5];
        availableAssets  = amounts[6];
        withdrawalDelay  = amounts[7];

        if (owner    == address(0)) owner    = address(1);
        if (caller   == address(0)) caller   = address(1);
        if (receiver == address(0)) receiver = address(1);

        vm.assume(owner    != address(pool));
        vm.assume(caller   != address(pool));
        vm.assume(receiver != address(pool));
        vm.assume(receiver != address(this));

        totalSupply      = bound(totalSupply,      1, 1e30);
        totalAssets      = bound(totalAssets,      0, 1e30);
        unrealizedLosses = bound(unrealizedLosses, 0, totalAssets);
        ownerShares      = bound(ownerShares,      1, totalSupply);
        sharesToRedeem   = bound(sharesToRedeem,   1, ownerShares);
        receiverAssets   = bound(receiverAssets,   0, 1e30);
        availableAssets  = bound(availableAssets,  0, totalAssets - unrealizedLosses);
        withdrawalDelay  = bound(withdrawalDelay,  0, 4 weeks);

        mintShares(owner, ownerShares, totalSupply);
        mintAssets(receiver, receiverAssets);
        setupPool(totalAssets, unrealizedLosses, availableAssets);

        bool sameCaller = caller == owner;

        uint256 lpStartingBalance = pool.balanceOf(address(owner));

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        assertEq(pool.allowance(owner, caller),       sharesToRedeem);
        assertEq(pool.balanceOf(address(owner)),      lpStartingBalance);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        vm.prank(caller);
        pool.requestRedeem(sharesToRedeem, owner);

        assertEq(pool.allowance(owner, caller),       sameCaller ? sharesToRedeem : 0);
        assertEq(pool.balanceOf(address(owner)),      lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRedeem);

        vm.warp(start + withdrawalDelay);

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        if (withdrawalDelay < 2 weeks || withdrawalDelay >= 2 weeks + 2 days) {
            vm.prank(caller);
            vm.expectRevert("WM:PE:NOT_IN_WINDOW");
            pool.redeem(sharesToRedeem, receiver, owner);
            return;
        }

        uint256 assetsToWithdraw = sharesToRedeem * (totalAssets - unrealizedLosses) / totalSupply;

        uint256 redeemableShares =
            availableAssets < assetsToWithdraw
                ? sharesToRedeem * availableAssets / assetsToWithdraw
                : sharesToRedeem;

       uint256 withdrawableAssets = (totalAssets - unrealizedLosses) * redeemableShares / totalSupply;

        assertEq(pool.allowance(owner, caller), sharesToRedeem);

        assertEq(pool.totalSupply(),                  totalSupply);
        assertEq(pool.balanceOf(address(owner)),      lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRedeem);
        assertEq(fundsAsset.balanceOf(receiver),      receiverAssets);

        assertEq(cyclicalWM.lockedShares(owner), sharesToRedeem);
        assertEq(cyclicalWM.exitCycleId(owner),  3);

        vm.prank(caller);
        uint256 withdrawnAssets = pool.redeem(sharesToRedeem, receiver, owner);

        assertEq(withdrawnAssets, withdrawableAssets);

        assertEq(pool.allowance(owner, caller), sameCaller ? sharesToRedeem : sharesToRedeem - redeemableShares);

        assertEq(pool.totalSupply(),                  totalSupply       - redeemableShares);
        assertEq(pool.balanceOf(address(owner)),      lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRedeem    - redeemableShares);
        assertEq(fundsAsset.balanceOf(receiver),      receiverAssets    + withdrawnAssets);

        assertEq(cyclicalWM.lockedShares(owner), sharesToRedeem - redeemableShares);
        assertEq(cyclicalWM.exitCycleId(owner),  redeemableShares < sharesToRedeem ? 4 : 0);
    }

}
