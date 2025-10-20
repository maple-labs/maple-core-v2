// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract ProcessEmptyRedemptionsQueueTests is TestBaseWithAssertions {

    address lp;
    address wm;

    function setUp() public override {
        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        lp = makeAddr("lp");
        wm = address(queueWM);

        deposit(lp, 10_000e8);
    }

    function test_processEmptyRedemptions_zeroRequests_reverts() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PER:ZERO_REQUESTS");
        queueWM.processEmptyRedemptions(0);
    }

    function test_processRedemptions_then_processEmptyRedemptions_skipsCancelledFront() external {
        requestRedeem(lp, 1_000e8);
        requestRedeem(lp, 2_000e8);
        requestRedeem(lp, 3_000e8);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.totalShares(), 6_000e8);
        assertEq(pool.balanceOf(wm),    6_000e8);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e8);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertEq(queueWM.totalShares(), 5_000e8);
        assertEq(pool.balanceOf(wm),    5_000e8);
        assertEq(fundsAsset.balanceOf(lp), 1_000e8);

        vm.prank(lp);
        queueWM.removeSharesById(2, 2_000e8);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });
        assertEq(queueWM.totalShares(), 3_000e8);
        assertEq(pool.balanceOf(wm),    3_000e8);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(10);  // Only 1 empty request processed

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 3 });
        assertEq(queueWM.totalShares(), 3_000e8);
        assertEq(pool.balanceOf(wm),    3_000e8);
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 3_000e8 });
    }

    function test_partialProcess_then_cancel_head_then_processEmptyRedemptions() external {
        requestRedeem(lp, 2_000e8);
        requestRedeem(lp, 3_000e8);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e8);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e8 });
        assertEq(queueWM.totalShares(), 4_000e8);
        assertEq(pool.balanceOf(wm),    4_000e8);
        assertEq(fundsAsset.balanceOf(lp), 1_000e8);

        vm.prank(lp);
        queueWM.removeSharesById(1, 1_000e8);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
        assertEq(queueWM.totalShares(), 3_000e8);
        assertEq(pool.balanceOf(wm),    3_000e8);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(1);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 3_000e8 });
        assertEq(queueWM.totalShares(), 3_000e8);
        assertEq(pool.balanceOf(wm),    3_000e8);
    }

    function test_processEmptyRedemptions_emptyQueue_noChange() external {
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });
        assertEq(queueWM.totalShares(),           0);
        assertEq(pool.balanceOf(wm),              0);
        assertEq(queueWM.userEscrowedShares(lp),  0);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(10);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });
        assertEq(queueWM.totalShares(),           0);
        assertEq(pool.balanceOf(wm),              0);
        assertEq(queueWM.userEscrowedShares(lp),  0);
    }

    function test_processEmptyRedemptions_multipleEmptyRequests() external {
        requestRedeem(lp, 100e8);
        requestRedeem(lp, 200e8);
        requestRedeem(lp, 300e8);
        requestRedeem(lp, 400e8);
        requestRedeem(lp, 500e8);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 5 });
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 100e8 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 200e8 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 300e8 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp, shares: 400e8 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp, shares: 500e8 });

        vm.startPrank(lp);
        queueWM.removeSharesById(1, 100e8);
        queueWM.removeSharesById(2, 200e8);
        queueWM.removeSharesById(3, 300e8);
        vm.stopPrank();

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 5 });
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp,        shares: 400e8 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp,        shares: 500e8 });

        assertEq(queueWM.totalShares(), 900e8);
        assertEq(pool.balanceOf(wm),    900e8);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(3);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 5 });
        assertEq(queueWM.totalShares(), 900e8);
        assertEq(pool.balanceOf(wm),    900e8);
    }

    function test_processEmptyRedemptions_stopsAtNonEmpty() external {
        requestRedeem(lp, 100e8);
        requestRedeem(lp, 200e8);
        requestRedeem(lp, 300e8);
        requestRedeem(lp, 400e8);
        requestRedeem(lp, 500e8);

        vm.startPrank(lp);
        queueWM.removeSharesById(1, 100e8);
        queueWM.removeSharesById(2, 200e8);
        vm.stopPrank();

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 5 });
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,        shares: 300e8 });

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(5);  // Should stop after processing 2 empty requests

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 5 });

        assertEq(queueWM.totalShares(), 1_200e8);
        assertEq(pool.balanceOf(wm),    1_200e8);
    }

    function test_processEmptyRedemptions_noEmptyRequests_noChange() external {
        requestRedeem(lp, 100e8);
        requestRedeem(lp, 200e8);
        requestRedeem(lp, 300e8);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.totalShares(), 600e8);
        assertEq(pool.balanceOf(wm),    600e8);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(10);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.totalShares(), 600e8);
        assertEq(pool.balanceOf(wm),    600e8);
    }

    function test_processEmptyRedemptions_fullyProcessedQueue_noChange() external {
        requestRedeem(lp, 250e8);

        vm.prank(lp);
        queueWM.removeSharesById(1, 250e8);

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(1);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 1 });

        vm.prank(poolDelegate);
        queueWM.processEmptyRedemptions(10);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 1 });
        assertEq(queueWM.totalShares(), 0);
        assertEq(pool.balanceOf(wm),    0);
    }

}
