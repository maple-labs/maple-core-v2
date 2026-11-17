// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { FuzzBase } from "../FuzzBase.sol";

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

    function testDeepFuzz_redeem_all(address[3] memory addresses, uint256[7] memory amounts) external {
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

        if (owner == address(0)) owner = address(1);
        if (caller == address(0)) caller = address(1);
        if (receiver == address(0)) receiver = address(1);

        vm.assume(owner != address(pool));
        vm.assume(caller != address(pool));
        vm.assume(receiver != address(pool));
        vm.assume(receiver != address(this));
        vm.assume(owner != address(queueWM));
        vm.assume(caller != address(queueWM));
        vm.assume(receiver != address(queueWM));

        totalSupply      = bound(totalSupply, 1, 1e30);
        totalAssets      = bound(totalAssets, 0, 1e30);
        unrealizedLosses = bound(unrealizedLosses, 0, totalAssets);
        ownerShares      = bound(ownerShares, 1, totalSupply);
        sharesToRedeem   = bound(sharesToRedeem, 1, ownerShares);
        receiverAssets   = bound(receiverAssets, 0, 1e30);

        uint256 assetsToWithdraw = sharesToRedeem * (totalAssets - unrealizedLosses) / totalSupply;

        availableAssets = bound(availableAssets, assetsToWithdraw, totalAssets - unrealizedLosses);

        mintShares(owner, ownerShares, totalSupply);
        mintAssets(receiver, receiverAssets);
        setupPool(totalAssets, unrealizedLosses, availableAssets);

        bool sameCaller = caller == owner;

        uint256 lpStartingBalance = pool.balanceOf(owner);

        setManualWithdrawal(address(poolManager), owner, true);

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        assertEq(pool.allowance(owner, caller),    sharesToRedeem);
        assertEq(pool.balanceOf(owner),            lpStartingBalance);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        vm.prank(caller);
        pool.requestRedeem(sharesToRedeem, owner);

        assertEq(pool.allowance(owner, caller),    sameCaller ? sharesToRedeem : 0);
        assertEq(pool.balanceOf(owner),            lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(queueWM)), sharesToRedeem);

        // Pool delegate processes the request, making the shares available for manual withdrawal.
        processRedemptions(address(pool), sharesToRedeem);

        assertEq(queueWM.manualSharesAvailable(owner), sharesToRedeem);
        assertEq(pool.balanceOf(address(queueWM)),     sharesToRedeem);
        assertEq(pool.totalSupply(),                   totalSupply);

        vm.prank(owner);
        pool.approve(caller, sharesToRedeem);

        vm.prank(caller);
        uint256 withdrawnAssets = pool.redeem(sharesToRedeem, receiver, owner);

        assertEq(withdrawnAssets, assetsToWithdraw);

        assertEq(pool.allowance(owner, caller), sameCaller ? sharesToRedeem : 0);

        assertEq(pool.totalSupply(),                   totalSupply - sharesToRedeem);
        assertEq(pool.balanceOf(owner),                lpStartingBalance - sharesToRedeem);
        assertEq(pool.balanceOf(address(queueWM)),     0);
        assertEq(queueWM.manualSharesAvailable(owner), 0);
        assertEq(fundsAsset.balanceOf(receiver),       receiverAssets + withdrawnAssets);
    }

}
