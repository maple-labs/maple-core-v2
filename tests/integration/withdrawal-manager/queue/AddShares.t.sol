// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase, TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract AddSharesQueueTests is TestBaseWithAssertions {

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

    function test_addShares_success() external {
        // assert lp1 before withdrawal request
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        requestRedeem(lp1, 1_000e6);

        // assert lp1 after withdrawal request
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(wm),    1_000e6);
        assertEq(queueWM.totalShares(), 1_000e6);

        // assert lp2 before withdrawal request
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp2), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp2),   2_000e6);
        assertEq(pool.balanceOf(wm),    1_000e6);
        assertEq(queueWM.totalShares(), 1_000e6);

        requestRedeem(lp2, 2_000e6);

        // assert lp2 after withdrawal request
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp2), owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(wm),    3_000e6);
        assertEq(queueWM.totalShares(), 3_000e6);
    }

    function test_addShares_partialRequest() external {
        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        requestRedeem(lp1, 600e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 600e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp1),   400e6);
        assertEq(pool.balanceOf(wm),    600e6);
        assertEq(queueWM.totalShares(), 600e6);
    }

    function test_addShares_manual() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        requestRedeem(lp1, 1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(wm),    1_000e6);
        assertEq(queueWM.totalShares(), 1_000e6);
    }

    function test_addShares_withApproval() external {
        address sender = makeAddr("sender");

        vm.prank(lp1);
        pool.approve(sender, 1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 0 });

        assertEq(pool.balanceOf(lp1),         1_000e6);
        assertEq(pool.balanceOf(wm),          0);
        assertEq(pool.allowance(lp1, sender), 1_000e6);
        assertEq(queueWM.totalShares(),       0);

        vm.prank(sender);
        pool.requestRedeem(1_000e6, lp1);

        assertRequest({ poolManager: address(poolManager), requestId: queueWM.requestIds(lp1), owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp1),         0);
        assertEq(pool.balanceOf(wm),          1_000e6);
        assertEq(pool.allowance(lp1, sender), 0);
        assertEq(queueWM.totalShares(),       1_000e6);
    }

}

contract AddSharesQueueFailureTests is TestBase {

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

        lp  = makeAddr("lp");

        wm  = address(queueWM);

        deposit(lp,  1_000e6);

        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_addShares_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PAUSED");
        pool.requestRedeem(1_000e6, lp);
    }

    function test_addShares_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.requestRedeem(1_000e6, address(lp), address(1));
    }

    function test_addShares_failIfNotPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        queueWM.addShares(1_000e6, address(lp));
    }

    function test_addShares_failIfInsufficientApproval() external {
        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6 - 1);

        vm.prank(sender);
        vm.expectRevert(arithmeticError);
        pool.requestRedeem(1_000e6, lp);
    }

    function test_addShares_failIfEmptyRequest() external {
        vm.expectRevert("WM:AS:ZERO_SHARES");
        requestRedeem(lp, 0);
    }

    function test_addShares_failIfAlreadyInQueue() external {
        requestRedeem(lp, 500e6);

        vm.expectRevert("WM:AS:IN_QUEUE");
        requestRedeem(lp, 500e6);
    }

    function test_addShares_failIfTransferFail() external {
        vm.prank(lp);
        pool.transfer(address(1), 1_000e6);

        vm.expectRevert(arithmeticError);
        requestRedeem(lp, 1_000e6);
    }

}
