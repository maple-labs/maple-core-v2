// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../contracts/utilities/TestBase.sol";

import { Address, console  } from "../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract RequestWithdrawTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_requestWithdraw() external {
        depositLiquidity(lp, 1_000e6);

        vm.startPrank(lp);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 shares = pool.requestWithdraw(1_000e6, lp);

        assertEq(shares, 1_000e6);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
    }

    function test_requestWithdraw_withApproval() external {
        depositLiquidity(lp, 1_000e6);

        address sender = address(new Address());

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        vm.prank(sender);
        uint256 shares = pool.requestWithdraw(1_000e6, lp);

        assertEq(shares, 1_000e6);

        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.balanceOf(wm),         1_000e6);
        assertEq(pool.allowance(lp, sender), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
    }


    function testFuzz_requestWithdraw(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = constrictToRange(depositAmount,  1, 1e30);
        withdrawAmount = constrictToRange(withdrawAmount, 1, depositAmount);

        depositLiquidity(lp, depositAmount);

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 shares = pool.requestWithdraw(withdrawAmount, lp);

        assertEq(shares, withdrawAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - withdrawAmount);
        assertEq(pool.balanceOf(wm), withdrawAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    withdrawAmount);
        assertEq(withdrawalManager.totalCycleShares(3), withdrawAmount);
    }

}

contract SingleUserWithdrawTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_withdraw_singleUser_fullLiquidity_oneToOne() external {
        depositLiquidity(lp, 1_000e6);

        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 shares = pool.withdraw(1_000e6, lp, lp);

        assertEq(shares, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function testFuzz_withdraw_singleUser_fullLiquidity_oneToOne(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = constrictToRange(depositAmount,  1, 1e30);
        withdrawAmount = constrictToRange(withdrawAmount, 1, depositAmount);

        depositLiquidity(lp, depositAmount);

        vm.startPrank(lp);

        pool.requestWithdraw(withdrawAmount, lp);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - withdrawAmount);
        assertEq(pool.balanceOf(wm), withdrawAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    withdrawAmount);
        assertEq(withdrawalManager.totalCycleShares(3), withdrawAmount);

        uint256 shares = pool.withdraw(withdrawAmount, lp, lp);

        assertEq(shares, withdrawAmount);

        assertEq(fundsAsset.balanceOf(address(lp)),   withdrawAmount);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount - withdrawAmount);

        assertEq(pool.totalSupply(), depositAmount - withdrawAmount);
        assertEq(pool.balanceOf(lp), depositAmount - withdrawAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function test_withdraw_singleUser_fullLiquidity_raiseAmount() external {
        depositLiquidity(lp, 1_000e6);

        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6, lp);  // Transfers 1000 shares to the WM.

        // Transfer cash into pool to increase totalAssets
        fundsAsset.mint(address(pool), 250e6);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_250e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 shares = pool.withdraw(1_250e6, lp, lp);

        assertEq(shares, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_250e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);  // 1000 withdrawal redeemed 80% of shares
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function test_withdraw_singleUser_withApprovals() external {
        address sender = address(new Address());

        depositLiquidity(lp, 1_000e6);

        // Transfer cash into pool to increase totalAssets
        fundsAsset.mint(address(pool), 250e6);

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.allowance(lp, sender), 1_000e6);

        vm.prank(sender);
        pool.requestWithdraw(1_250e6, lp);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_250e6);

        assertEq(pool.totalSupply(),         1_000e6);
        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.balanceOf(wm),         1_000e6);
        assertEq(pool.allowance(lp, sender), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        // Needs a second approval
        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.allowance(lp, sender), 1_000e6);

        vm.prank(sender);
        uint256 shares = pool.withdraw(1_250e6, lp, lp);

        assertEq(shares, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_250e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(),         0);
        assertEq(pool.balanceOf(lp),         0);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

}

contract RequestWithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);
    }

    function test_requestWithdraw_failIfInsufficientApproval() external {
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.requestWithdraw(1_000e6, lp);

        vm.prank(lp);
        pool.approve(address(this), 1_000e6 - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_failIfZeroShares() external {
        vm.expectRevert("P:RR:ZERO_SHARES");
        pool.requestWithdraw(0, lp);
    }

    function test_requestWithdraw_failIfNotPool() external {
        vm.expectRevert("PM:RR:NOT_POOL");
        poolManager.requestRedeem(0, address(lp));
    }

    function test_requestWithdraw_failIfNotPM() external {
        vm.expectRevert("WM:AS:NOT_POOL_MANAGER");
        withdrawalManager.addShares(0, address(lp));
    }

    function test_requestWithdraw_failIfAlreadyLockedShares() external {
        vm.prank(lp);
        pool.requestWithdraw(1e6, lp);

        vm.prank(lp);
        vm.expectRevert("WM:AS:WITHDRAWAL_PENDING");
        pool.requestWithdraw(1e6, lp);
    }

}

contract WithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);
    }

    function test_withdraw_failIfNotPool() external {
        vm.expectRevert("PM:PR:NOT_POOL");
        poolManager.processRedeem(1, lp);
    }

    function test_withdraw_failIfNotPoolManager() external {
        vm.expectRevert("WM:PE:NOT_PM");
        withdrawalManager.processExit(address(lp), 1_000e6);
    }

    function test_withdraw_failWithInvalidAmountOfShares() external {
        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.expectRevert("WM:PE:INVALID_SHARES");
        pool.withdraw(1_000e6 - 1, lp, lp);

        vm.expectRevert("WM:PE:INVALID_SHARES");
        pool.withdraw(1_000e6 + 1, lp, lp);
    }

    function test_withdraw_failIfNoRequest() external {
        vm.expectRevert("WM:PR:NO_REQUEST");
        pool.withdraw(0, lp, lp);
    }

    function test_withdraw_failIfNotInWindow() external {
        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 1 weeks);

        vm.expectRevert("WM:PR:NOT_IN_WINDOW");
        pool.withdraw(1_000e6, lp, lp);

        // Warping to a second after window close
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("WM:PR:NOT_IN_WINDOW");
        pool.withdraw(1_000e6, lp, lp);
    }

    function test_withdraw_failIfNoBalanceOnWM() external {
        vm.prank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        // Manually remove tokens from the withdrawal manager.
        vm.prank(address(withdrawalManager));
        pool.transfer(address(0), 1_000e6);

        vm.expectRevert("WM:PE:TRANSFER_FAIL");
        pool.withdraw(1_000e6, lp, lp);
    }

    function test_withdraw_failWithZeroReceiver() external {
        vm.prank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.expectRevert("P:B:ZERO_RECEIVER");
        pool.withdraw(1_000e6, address(0), lp);
    }

    function test_withdraw_failIfNoApprove() external {
        vm.prank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.withdraw(1_000e6, lp, lp);
    }

    function test_withdraw_failWithInsufficientApproval() external {
        vm.prank(lp);

        pool.requestWithdraw(1_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.prank(lp);
        pool.approve(address(this), 1_000e6 - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.withdraw(1_000e6, lp, lp);
    }

}
