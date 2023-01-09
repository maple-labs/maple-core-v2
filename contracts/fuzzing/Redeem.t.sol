// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { FuzzBase } from "../utilities/FuzzBase.sol";

contract RedeemFuzzTests is FuzzBase {

    // Avoid stack too deep in tests
    address internal caller;
    address internal owner;
    address internal receiver;

    uint256 internal totalSupply;
    uint256 internal totalAssets;
    uint256 internal unrealizedLosses;
    uint256 internal ownerShares;
    uint256 internal sharesToRedeem;
    uint256 internal receiverAssets;
    uint256 internal availableAssets;
    uint256 internal withdrawalDelay;

    function testDeepFuzz_redeem_all(address[3] memory addresses, uint256[8] memory amounts) external {
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

        totalSupply      = constrictToRange(totalSupply,      1, 1e30);
        totalAssets      = constrictToRange(totalAssets,      0, 1e30);
        unrealizedLosses = constrictToRange(unrealizedLosses, 0, totalAssets);
        ownerShares      = constrictToRange(ownerShares,      1, totalSupply);
        sharesToRedeem   = constrictToRange(sharesToRedeem,   1, ownerShares);
        receiverAssets   = constrictToRange(receiverAssets,   0, 1e30);
        availableAssets  = constrictToRange(availableAssets,  0, totalAssets - unrealizedLosses);
        withdrawalDelay  = constrictToRange(withdrawalDelay,  0, 4 weeks);

        mintShares(owner, ownerShares, totalSupply);
        mintAssets(receiver, receiverAssets);
        setupPool(totalAssets, unrealizedLosses, availableAssets);

        bool sameCaller = caller == owner;

        uint256 lpStartingBalance = pool.balanceOf(address(owner));

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        assertEq(pool.allowance(owner, caller),              sharesToRedeem);
        assertEq(pool.balanceOf(address(owner)),             lpStartingBalance);
        assertEq(pool.balanceOf(address(withdrawalManager)), 0);

        vm.prank(caller);
        pool.requestRedeem(sharesToRedeem, owner);

        assertEq(pool.allowance(owner, caller),              sameCaller ? sharesToRedeem : 0);
        assertEq(pool.balanceOf(address(owner)),             lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem);

        vm.warp(start + withdrawalDelay);

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        // TODO: Fuzz durations of withdrawal cycle and window.
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

        assertEq(pool.totalSupply(),                         totalSupply);
        assertEq(pool.balanceOf(address(owner)),             lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem);
        assertEq(fundsAsset.balanceOf(receiver),             receiverAssets);

        assertEq(withdrawalManager.lockedShares(owner), sharesToRedeem);
        assertEq(withdrawalManager.exitCycleId(owner),  3);

        vm.prank(caller);
        uint256 withdrawnAssets = pool.redeem(sharesToRedeem, receiver, owner);

        assertEq(withdrawnAssets, withdrawableAssets);

        assertEq(pool.allowance(owner, caller), sameCaller ? sharesToRedeem : sharesToRedeem - redeemableShares);

        assertEq(pool.totalSupply(),                         totalSupply       - redeemableShares);
        assertEq(pool.balanceOf(address(owner)),             lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem    - redeemableShares);
        assertEq(fundsAsset.balanceOf(receiver),             receiverAssets    + withdrawnAssets);

        assertEq(withdrawalManager.lockedShares(owner), sharesToRedeem - redeemableShares);
        assertEq(withdrawalManager.exitCycleId(owner),  redeemableShares < sharesToRedeem ? 4 : 0);
    }

}
