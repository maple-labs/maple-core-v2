// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPool } from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract DelayedWithdrawalStartTests is TestBase {

    address lp = makeAddr("lp");
    address wm;

    uint256 assets = 125_000e6;
    uint256 shares = assets;
    uint256 withdrawalStart;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
    }

    function setupTest(uint256 withdrawalDelay) internal {
        withdrawalDelay = bound(withdrawalDelay, 10 days, 100 days);
        withdrawalStart = start + withdrawalDelay;

        _createAndConfigurePool(withdrawalStart, 1 weeks, 2 days);

        wm = address(withdrawalManager);

        openPool(address(poolManager));
        deposit(address(pool), lp, assets);

        vm.startPrank(lp);
    }

    /**************************************************************************************************************************************/
    /*** Redeem Tests                                                                                                                   ***/
    /**************************************************************************************************************************************/

    function testFuzz_requestRedeem_beforeStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart - 1 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart);
        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 1 days);
        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.redeem(shares, lp, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_requestRedeem_onStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 1 days);
        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.redeem(shares, lp, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_requestRedeem_afterStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 1 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.redeem(shares, lp, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_requestRedeem_nextCycle(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 10 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  4);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:PE:NOT_IN_WINDOW");
        pool.redeem(shares, lp, lp);

        vm.warp(withdrawalStart + 3 weeks);
        pool.redeem(shares, lp, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    /**************************************************************************************************************************************/
    /*** Withdraw Tests                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function testFuzz_requestWithdraw_beforeStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart - 1 days);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);

        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function testFuzz_requestWithdraw_onStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);

        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function testFuzz_requestWithdraw_afterStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 1 days);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);

        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function testFuzz_requestWithdraw_nextCycle(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 10 days);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);

        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    /**************************************************************************************************************************************/
    /*** RemoveShares Tests                                                                                                             ***/
    /**************************************************************************************************************************************/

    function testFuzz_removeShares_beforeStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart - 1 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart);
        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 1 days);
        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp), shares);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_removeShares_onStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 1 days);
        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp), shares);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_removeShares_afterStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 1 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.exitCycleId(lp),  3);
        assertEq(withdrawalManager.lockedShares(lp), shares);

        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 2 weeks);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp), shares);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    function testFuzz_removeShares_nextCycle(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 10 days);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), shares);

        assertEq(withdrawalManager.lockedShares(lp), shares);
        assertEq(withdrawalManager.exitCycleId(lp),  4);

        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(shares, lp);

        vm.warp(withdrawalStart + 3 weeks);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp), shares);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),  0);
        assertEq(withdrawalManager.lockedShares(lp), 0);
    }

    /**************************************************************************************************************************************/
    /*** SetExitConfig Tests                                                                                                            ***/
    /**************************************************************************************************************************************/

    function testFuzz_setExitConfig_beforeStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart - 1 days);
        vm.stopPrank();
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(2 weeks, 2 days);

        ( uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration ) = withdrawalManager.cycleConfigs(1);

        assertEq(initialCycleId,   4);
        assertEq(initialCycleTime, withdrawalStart + 3 weeks);
        assertEq(cycleDuration,    2 weeks);
        assertEq(windowDuration,   2 days);
    }

    function testFuzz_setExitConfig_onStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart);
        vm.stopPrank();
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(2 weeks, 2 days);

        ( uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration ) = withdrawalManager.cycleConfigs(1);

        assertEq(initialCycleId,   4);
        assertEq(initialCycleTime, withdrawalStart + 3 weeks);
        assertEq(cycleDuration,    2 weeks);
        assertEq(windowDuration,   2 days);
    }

    function testFuzz_setExitConfig_afterStart(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 1 days);
        vm.stopPrank();
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(2 weeks, 2 days);

        ( uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration ) = withdrawalManager.cycleConfigs(1);

        assertEq(initialCycleId,   4);
        assertEq(initialCycleTime, withdrawalStart + 3 weeks);
        assertEq(cycleDuration,    2 weeks);
        assertEq(windowDuration,   2 days);
    }

    function testFuzz_setExitConfig_nextCycle(uint256 withdrawalDelay) external {
        setupTest(withdrawalDelay);

        vm.warp(withdrawalStart + 10 days);
        vm.stopPrank();
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(2 weeks, 2 days);

        ( uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration ) = withdrawalManager.cycleConfigs(1);

        assertEq(initialCycleId,   5);
        assertEq(initialCycleTime, withdrawalStart + 4 weeks);
        assertEq(cycleDuration,    2 weeks);
        assertEq(windowDuration,   2 days);
    }

}
