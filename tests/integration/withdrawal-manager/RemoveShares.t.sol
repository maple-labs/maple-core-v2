// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase, TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract RemoveSharesCyclicalTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_removeShares_success() public {
        // Warp to post withdrawal period
        vm.warp(start + 2 weeks + 1);

        // Pre state assertions
        assertEq(pool.balanceOf(lp),             0);
        assertEq(pool.balanceOf(wm),             1_000e6);
        assertEq(cyclicalWM.totalCycleShares(3), 1_000e6);
        assertEq(cyclicalWM.lockedShares(lp),    1_000e6);
        assertEq(cyclicalWM.exitCycleId(lp),     3);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        // Pre state assertions
        assertEq(sharesReturned,                 1_000e6);
        assertEq(pool.balanceOf(lp),             1_000e6);
        assertEq(pool.balanceOf(wm),             0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.exitCycleId(lp),     0);
    }

    function test_removeShares_withApproval() public {
        // Warp to post withdrawal period
        vm.warp(start + 2 weeks + 1);

        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        // Pre state assertions
        assertEq(pool.balanceOf(lp),             0);
        assertEq(pool.balanceOf(wm),             1_000e6);
        assertEq(pool.allowance(lp, sender),     1_000e6);
        assertEq(cyclicalWM.totalCycleShares(3), 1_000e6);
        assertEq(cyclicalWM.lockedShares(lp),    1_000e6);
        assertEq(cyclicalWM.exitCycleId(lp),     3);

        vm.prank(sender);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        // Post state assertions
        assertEq(sharesReturned,                 1_000e6);
        assertEq(pool.balanceOf(lp),             1_000e6);
        assertEq(pool.balanceOf(wm),             0);
        assertEq(pool.allowance(lp, sender),     0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.exitCycleId(lp),     0);
    }

    function test_removeShares_prematurelyAddedShares() public {
        lp = makeAddr("lp2");

        deposit(lp, 2_000e6);

        vm.warp(start - 10 days);
        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 2_000e6);

        assertEq(cyclicalWM.totalCycleShares(3), 2_000e6);
        assertEq(cyclicalWM.lockedShares(lp),    1_000e6);
        assertEq(cyclicalWM.exitCycleId(lp),     3);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        assertEq(sharesReturned, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(cyclicalWM.totalCycleShares(3), 1_000e6);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.exitCycleId(lp),     0);
    }

    function test_removeShares_pastTheRedemptionWindow() public {
        // Warp to way after the period closes
        vm.warp(start + 50 weeks);

        // Pre state assertions
        assertEq(pool.balanceOf(lp),             0);
        assertEq(pool.balanceOf(wm),             1_000e6);
        assertEq(cyclicalWM.totalCycleShares(3), 1_000e6);
        assertEq(cyclicalWM.lockedShares(lp),    1_000e6);
        assertEq(cyclicalWM.exitCycleId(lp),     3);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        // Pre state assertions
        assertEq(sharesReturned,                 1_000e6);
        assertEq(pool.balanceOf(lp),             1_000e6);
        assertEq(pool.balanceOf(wm),             0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.exitCycleId(lp),     0);
    }

    function test_removeShares_sameAddressCallingTwice() external {
        address sender = makeAddr("sender");

        uint256 senderShares = deposit(sender, 1_000e6);

        vm.prank(sender);
        pool.requestRedeem(senderShares, sender);

        // Warp to redemption period
        vm.warp(start + 2 weeks + 1);

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        // Pre state assertions
        assertEq(pool.balanceOf(sender),          0);
        assertEq(pool.balanceOf(lp),              0);
        assertEq(pool.balanceOf(wm),              1_000e6 + senderShares);
        assertEq(pool.allowance(lp, sender),      1_000e6);
        assertEq(cyclicalWM.totalCycleShares(3),  1_000e6 + senderShares);
        assertEq(cyclicalWM.lockedShares(lp),     1_000e6);
        assertEq(cyclicalWM.exitCycleId(lp),      3);
        assertEq(cyclicalWM.lockedShares(sender), senderShares);
        assertEq(cyclicalWM.exitCycleId(sender),  3);

        vm.prank(sender);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        // Intermediary assertions
        assertEq(sharesReturned,                  1_000e6);
        assertEq(pool.balanceOf(sender),          0);
        assertEq(pool.balanceOf(lp),              1_000e6);
        assertEq(pool.balanceOf(wm),              senderShares);
        assertEq(pool.allowance(lp, sender),      0);
        assertEq(cyclicalWM.totalCycleShares(3),  senderShares);
        assertEq(cyclicalWM.lockedShares(lp),     0);
        assertEq(cyclicalWM.exitCycleId(lp),      0);
        assertEq(cyclicalWM.lockedShares(sender), senderShares);
        assertEq(cyclicalWM.exitCycleId(sender),  3);

        // Sender redeems their own shares
        vm.prank(sender);
        sharesReturned = pool.removeShares(senderShares, sender);

        assertEq(sharesReturned,                  senderShares);
        assertEq(pool.balanceOf(sender),          senderShares);
        assertEq(pool.balanceOf(lp),              1_000e6);
        assertEq(pool.balanceOf(wm),              0);
        assertEq(pool.allowance(lp, sender),      0);
        assertEq(cyclicalWM.totalCycleShares(3),  0);
        assertEq(cyclicalWM.lockedShares(lp),     0);
        assertEq(cyclicalWM.exitCycleId(lp),      0);
        assertEq(cyclicalWM.lockedShares(sender), 0);
        assertEq(cyclicalWM.exitCycleId(sender),  0);
    }

}

contract RemoveSharesCyclicalFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);
    }

    function test_removeShares_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PAUSED");
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfNotPoolManager() external {
        vm.expectRevert("WM:RS:NOT_POOL_MANAGER");
        cyclicalWM.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfInsufficientApproval() external {
        vm.warp(start + 2 weeks);

        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6 - 1);

        vm.prank(sender);
        vm.expectRevert(arithmeticError);
        pool.removeShares(1_000e6, lp);

        // With enough approval
        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        vm.prank(sender);
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfRemovedTwice() external {
        vm.warp(start + 2 weeks);

        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        vm.prank(sender);
        pool.removeShares(1_000e6, lp);

        // Try removing again, now lp calling directly
        vm.prank(lp);
        vm.expectRevert(arithmeticError);
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfWithdrawalIsPending() external {
        vm.warp(start + 2 weeks - 1);

        vm.prank(lp);
        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(1_000e6, lp);

        // Success call
        vm.prank(lp);
        vm.warp(start + 2 weeks);
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfInvalidShares() external {
        vm.warp(start + 2 weeks);

        vm.prank(lp);
        vm.expectRevert("WM:RS:SHARES_OOB");
        pool.removeShares(1_000e6 + 1, lp);
    }

    function test_removeShares_failIfInvalidSharesWithZero() external {
        vm.warp(start + 2 weeks);

        vm.prank(lp);
        vm.expectRevert("WM:RS:SHARES_OOB");
        pool.removeShares(0, lp);
    }

    function test_removeShares_failIfTransferFail() external {
        vm.warp(start + 2 weeks);

        // Forcefully remove shares from wm
        vm.prank(wm);
        pool.transfer(address(1), 1_000e6);

        vm.prank(lp);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        pool.removeShares(1_000e6, lp);
    }

}

contract RemoveSharesQueueTests is TestBaseWithAssertions {

    address borrower;
    address lp;
    address lp2;
    address wm;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        lp2      = makeAddr("lp2");
        wm       = address(queueWM);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_removeShares_success() external {
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp),     0);
        assertEq(pool.balanceOf(wm),     1_000e6);
        assertEq(queueWM.totalShares(),  1_000e6);
        assertEq(queueWM.requestIds(lp), 1);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(sharesReturned,         1_000e6);
        assertEq(pool.balanceOf(lp),     1_000e6);
        assertEq(pool.balanceOf(wm),     0);
        assertEq(queueWM.totalShares(),  0);
        assertEq(queueWM.requestIds(lp), 0);
    }

    function test_removeShares_withApproval() external {
        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.balanceOf(wm),         1_000e6);
        assertEq(pool.allowance(lp, sender), 1_000e6);
        assertEq(queueWM.totalShares(),      1_000e6);
        assertEq(queueWM.requestIds(lp),     1);

        vm.prank(sender);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(sharesReturned,             1_000e6);
        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 0);
        assertEq(queueWM.totalShares(),      0);
        assertEq(queueWM.requestIds(lp),     0);
    }

    function test_removeShares_partiallyProcessed() external {
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp),                0);
        assertEq(pool.balanceOf(wm),                1_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)), 0);
        assertEq(queueWM.requestIds(lp),            1);
        assertEq(queueWM.totalShares(),             1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(500e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 500e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(lp),                0);
        assertEq(pool.balanceOf(wm),                500e6);
        assertEq(fundsAsset.balanceOf(address(lp)), 1_000e6);
        assertEq(queueWM.requestIds(lp),            1);
        assertEq(queueWM.totalShares(),             500e6);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(500e6, lp);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(sharesReturned,                    500e6);
        assertEq(pool.balanceOf(lp),                500e6);
        assertEq(pool.balanceOf(wm),                0);
        assertEq(fundsAsset.balanceOf(address(lp)), 1_000e6);
        assertEq(queueWM.requestIds(lp),            0);
        assertEq(queueWM.totalShares(),             0);
    }

    function test_removeShares_manual_partiallyProcessed() external {
        deposit(lp2, 4_000e6);  // LP2 will get only 2_000e6 shares due to the exchange rate

        vm.prank(lp2);
        pool.requestRedeem(2_000e6, lp2);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp2),     0);
        assertEq(pool.balanceOf(wm),      3_000e6);  // 1_000e6 from lp1 and 2_000e6 from lp2
        assertEq(queueWM.totalShares(),   3_000e6);
        assertEq(queueWM.requestIds(lp2), 2);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_500e6);  // 1000e6 from lp1 and 1_500e6 from lp2

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 500e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(queueWM.manualSharesAvailable(lp2), 1_500e6);

        vm.prank(lp2);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
        pool.removeShares(2_000e6, lp2);

        vm.prank(lp2);
        uint256 sharesReturned = pool.removeShares(500e6, lp2);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(sharesReturned,          500e6);
        assertEq(pool.balanceOf(lp2),     500e6);
        assertEq(pool.balanceOf(wm),      1_500e6);
        assertEq(queueWM.totalShares(),   1_500e6);
        assertEq(queueWM.requestIds(lp2), 0);
    }

    function test_removeShares_sameAddressCallingTwice() external {
        address sender = makeAddr("sender");

        uint256 senderShares = deposit(sender, 1_000e6);

        vm.prank(sender);
        pool.requestRedeem(senderShares, sender);

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,     shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: sender, shares: senderShares });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.balanceOf(wm),         1_000e6 + senderShares);
        assertEq(pool.balanceOf(sender),     0);
        assertEq(pool.allowance(lp, sender), 1_000e6);
        assertEq(queueWM.totalShares(),      1_000e6 + senderShares);
        assertEq(queueWM.requestIds(lp),     1);

        vm.prank(sender);
        uint256 sharesReturned = pool.removeShares(1_000e6, lp);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: sender,     shares: senderShares });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         senderShares);
        assertEq(pool.balanceOf(sender),     0);
        assertEq(pool.allowance(lp, sender), 0);
        assertEq(queueWM.totalShares(),      senderShares);
        assertEq(queueWM.requestIds(lp),     0);

        vm.prank(sender);
        sharesReturned = pool.removeShares(senderShares, sender);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.balanceOf(sender),     senderShares);
        assertEq(pool.allowance(lp, sender), 0);
        assertEq(queueWM.totalShares(),      0);
        assertEq(queueWM.requestIds(lp),     0);
    }

}

contract RemoveSharesQueueFailureTests is TestBaseWithAssertions {

    address borrower;
    address lp;
    address lp2;
    address wm;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        lp2      = makeAddr("lp2");
        wm       = address(queueWM);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_removeShares_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PAUSED");
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfNotPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        queueWM.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfInsufficientApproval() external {
        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6 - 1);

        vm.prank(sender);
        vm.expectRevert(arithmeticError);
        pool.removeShares(1_000e6, lp);

        // With enough approval
        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        vm.prank(sender);
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfInvalidSharesWithZero() external {
        vm.prank(lp);
        vm.expectRevert("WM:RS:ZERO_SHARES");
        pool.removeShares(0, lp);
    }

    function test_removeShares_failIfRemovedTwice() external {
        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        vm.prank(sender);
        pool.removeShares(1_000e6, lp);

        // Try removing again, now lp calling directly
        vm.prank(lp);
        vm.expectRevert("WM:RS:NOT_IN_QUEUE");
        pool.removeShares(1_000e6, lp);
    }

    function test_removeShares_failIfInvalidShares() external {
        vm.prank(lp);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
        pool.removeShares(1_000e6 + 1, lp);
    }

    function test_removeShares_failIfTransferFail() external {
        // Forcefully remove shares from wm
        vm.prank(wm);
        pool.transfer(address(1), 1_000e6);

        vm.prank(lp);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        pool.removeShares(1_000e6, lp);
    }

}
