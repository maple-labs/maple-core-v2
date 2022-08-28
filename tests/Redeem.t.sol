// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../contracts/TestBase.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract RequestRedeemTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_requestRedeem() external {
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

        uint256 shares = pool.requestRedeem(1_000e6);

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

    function testFuzz_requestRedeem(uint256 depositAmount, uint256 redeemAmount) external {
        depositAmount = constrictToRange(depositAmount, 1, 1e30);
        redeemAmount  = constrictToRange(redeemAmount,  1, depositAmount);

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

        uint256 assets = pool.requestRedeem(redeemAmount);

        assertEq(assets, redeemAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), redeemAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    redeemAmount);
        assertEq(withdrawalManager.totalCycleShares(3), redeemAmount);
    }

}

contract RedeemTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_redeem_singleUser_fullLiquidity_oneToOne() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        pool.requestRedeem(1_000e6);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 assets = pool.redeem(1_000e6, lp, lp);

        assertEq(assets, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function testFuzz_redeem_singleUser_fullLiquidity_oneToOne(uint256 depositAmount, uint256 redeemAmount) external {
        depositAmount = constrictToRange(depositAmount, 1, 1e30);
        redeemAmount  = constrictToRange(redeemAmount,  1, depositAmount);

        depositLiquidity({
            lp:        lp,
            liquidity: depositAmount
        });

        vm.startPrank(lp);

        pool.requestRedeem(redeemAmount);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), redeemAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    redeemAmount);
        assertEq(withdrawalManager.totalCycleShares(3), redeemAmount);

        uint256 assets = pool.redeem(redeemAmount, lp, lp);

        assertEq(assets, redeemAmount);

        assertEq(fundsAsset.balanceOf(address(lp)),   redeemAmount);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount - redeemAmount);

        assertEq(pool.totalSupply(), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function test_redeem_singleUser_fullLiquidity_fullRedeem() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        // Transfer cash into pool to increase totalAssets
        fundsAsset.mint(address(pool), 250e6);

        vm.startPrank(lp);

        pool.requestRedeem(1_000e6);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_250e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 assets = pool.redeem(1_000e6, lp, lp);

        assertEq(assets, 1_250e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_250e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

}
