// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../../TestBase.sol";

contract RequestWithdrawTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        _setupPoolWithCyclicalWM();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);
    }

    function test_requestWithdraw() external {
        deposit(lp, 1_000e6);

        vm.startPrank(lp);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_withApproval() external {
        deposit(lp, 1_000e6);

        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 1_000e6);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        vm.prank(sender);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_premature() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.warp(start - 10 days);
        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(1_000e6, lp);
    }

    function testDeepFuzz_requestWithdraw(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = bound(depositAmount,  1, 1e30);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        deposit(lp, depositAmount);

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(withdrawAmount, lp);
    }

}

contract RequestWithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        _setupPoolWithCyclicalWM();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);
    }

    function test_requestWithdraw_failIfInsufficientApproval() external {
        vm.expectRevert(arithmeticError);
        pool.requestWithdraw(1_000e6, lp);

        vm.prank(lp);
        pool.approve(address(this), 1_000e6 - 1);

        vm.expectRevert(arithmeticError);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.requestRedeem(0, address(lp), address(lp));
    }

    function test_requestWithdraw_failIfNotPM() external {
        vm.expectRevert("WM:AS:NOT_POOL_MANAGER");
        cyclicalWM.addShares(0, address(lp));
    }

}

contract WithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        _setupPoolWithCyclicalWM();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);
    }

    function test_withdraw_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.processRedeem(1, lp, lp);
    }

    function test_withdraw_failIfNotPoolManager() external {
        vm.expectRevert("WM:PE:NOT_PM");
        cyclicalWM.processExit(1_000e6, address(lp));
    }

    function test_withdraw_zeroAssetInput() external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(0, lp, lp);
    }

    function test_withdraw_premature() external {
        vm.warp(start - 10 days);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(0, lp, lp);
    }

    function testDeepFuzz_withdraw(uint256 assets_, address receiver_, address owner_) external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets_, receiver_, owner_);
    }

}

