// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase, TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract RemoveRequestTests is TestBaseWithAssertions {

    address lp1;
    address lp2;
    address wm;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        wm  = address(queueWM);

        deposit(lp1, 1_000e6);
        deposit(lp2, 2_000e6);

        fundsAsset.mint(address(pool), 3_000e6);
    }

    function test_removeRequest_success() external {
        requestRedeem(lp1, 1_000e6);

        assertEq(pool.balanceOf(lp1),     0);
        assertEq(pool.balanceOf(wm),      1_000e6);
        assertEq(queueWM.totalShares(),   1_000e6);
        assertEq(queueWM.requestIds(lp1), 1);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        requestRedeem(lp2, 2_000e6);

        assertEq(pool.balanceOf(lp2),     0);
        assertEq(pool.balanceOf(wm),      3_000e6);
        assertEq(queueWM.totalShares(),   3_000e6);
        assertEq(queueWM.requestIds(lp2), 2);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp2), owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1);

        assertEq(pool.balanceOf(lp1),     1_000e6);
        assertEq(pool.balanceOf(lp2),     0);
        assertEq(pool.balanceOf(wm),      2_000e6);
        assertEq(queueWM.totalShares(),   2_000e6);
        assertEq(queueWM.requestIds(lp1), 0);
        assertEq(queueWM.requestIds(lp2), 2);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp2), owner: lp2, shares: 2_000e6 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
    }

    function test_removeRequest_forManual() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        requestRedeem(lp1, 1_000e6);

        assertEq(pool.balanceOf(lp1),     0);
        assertEq(pool.balanceOf(wm),      1_000e6);
        assertEq(queueWM.requestIds(lp1), 1);
        assertEq(queueWM.totalShares(),   1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1);

        assertEq(pool.balanceOf(lp1),     1_000e6);
        assertEq(pool.balanceOf(wm),      0);
        assertEq(queueWM.requestIds(lp1), 0);
        assertEq(queueWM.totalShares(),   0);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
    }

    function test_removeRequest_partialRedemption() external {
        requestRedeem(lp1, 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(400e6);  // partial redemption

        assertEq(pool.balanceOf(lp1),     0);
        assertEq(pool.balanceOf(wm),      600e6);
        assertEq(queueWM.requestIds(lp1), 1);
        assertEq(queueWM.totalShares(),   600e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 600e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1);

        assertEq(pool.balanceOf(lp1),     600e6);
        assertEq(pool.balanceOf(wm),      0);
        assertEq(queueWM.requestIds(lp1), 0);
        assertEq(queueWM.totalShares(),   0);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
    }

    function test_removeRequest_manualPartialRedemption() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        requestRedeem(lp1, 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(600e6);

        assertEq(pool.balanceOf(lp1),     0);
        assertEq(pool.balanceOf(wm),      1_000e6);
        assertEq(queueWM.requestIds(lp1), 1);
        assertEq(queueWM.totalShares(),   1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 400e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(queueWM.manualSharesAvailable(lp1), 600e6);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1);

        assertEq(pool.balanceOf(lp1),     400e6);
        assertEq(pool.balanceOf(wm),      600e6);
        assertEq(queueWM.requestIds(lp1), 0);
        assertEq(queueWM.totalShares(),   600e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(queueWM.manualSharesAvailable(lp1), 600e6);
    }

}

contract RemoveRequestFailureTests is TestBase {

    address lp;
    address wm;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        lp = makeAddr("lp");
        wm = address(queueWM);

        deposit(lp, 1_000e6);

        fundsAsset.mint(address(pool), 1_000e6);

        requestRedeem(lp, 1_000e6);
    }

    function test_removeRequest_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PAUSED");
        queueWM.removeRequest(lp);
    }

    function test_removeRequest_failIfNotPoolDelegate() external {
        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp);
    }

    function test_removeRequest_failIfNotGovernor() external {
        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp);

        vm.prank(governor);
        queueWM.removeRequest(lp);
    }

    function test_removeRequest_failIfNotOperationalAdmin() external {
        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp);

        vm.prank(operationalAdmin);
        queueWM.removeRequest(lp);
    }

    function test_removeRequest_failIfNotInQueue() external {
        vm.prank(poolDelegate);
        queueWM.removeRequest(lp);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:NOT_IN_QUEUE");
        queueWM.removeRequest(lp);
    }

    function test_removeRequest_failIfTransferFail() external {
        vm.prank(wm);
        pool.transfer(address(1), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:TRANSFER_FAIL");
        queueWM.removeRequest(lp);
    }

}
