// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../contracts/TestBase.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

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
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 shares = pool.requestWithdraw(1_000e6);

        assertEq(shares, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
    }

    function testFuzz_requestWithdraw(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = constrictToRange(depositAmount,  1, 1e30);
        withdrawAmount = constrictToRange(withdrawAmount, 1, depositAmount);

        depositLiquidity({
            lp:        lp,
            liquidity: depositAmount
        });

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 shares = pool.requestWithdraw(withdrawAmount);

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
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6);

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

        depositLiquidity({
            lp:        lp,
            liquidity: depositAmount
        });

        vm.startPrank(lp);

        pool.requestWithdraw(withdrawAmount);

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
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        pool.requestWithdraw(1_000e6);  // Transfers 1000 shares to the WM.

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

}
