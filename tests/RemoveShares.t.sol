pragma solidity 0.8.7;

import { TestBase } from "../contracts/utilities/TestBase.sol";

import { Address  } from "../modules/contract-test-utils/contracts/test.sol";

contract RemoveSharesTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6);

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_removeShares_success() public {
        // Warp to post withdrawal period
        vm.warp(start + 2 weeks + 1);

        // Pre state assertions
        assertEq(pool.balanceOf(lp),                    0); 
        assertEq(pool.balanceOf(wm),                    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6); 
        assertEq(withdrawalManager.exitCycleId(lp),     3);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6);

        // Pre state assertions
        assertEq(sharesReturned,                        1_000e6);   
        assertEq(pool.balanceOf(lp),                    1_000e6); 
        assertEq(pool.balanceOf(wm),                    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
        assertEq(withdrawalManager.lockedShares(lp),    0); 
        assertEq(withdrawalManager.exitCycleId(lp),     0);
    }

    function test_removeShares_pastTheRedemptionWindow() public {
        // Warp to way after the period closes
        vm.warp(start + 50 weeks);

        // Pre state assertions
        assertEq(pool.balanceOf(lp),                    0); 
        assertEq(pool.balanceOf(wm),                    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6); 
        assertEq(withdrawalManager.exitCycleId(lp),     3);

        vm.prank(lp);
        uint256 sharesReturned = pool.removeShares(1_000e6);

        // Pre state assertions
        assertEq(sharesReturned,                        1_000e6);   
        assertEq(pool.balanceOf(lp),                    1_000e6); 
        assertEq(pool.balanceOf(wm),                    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
        assertEq(withdrawalManager.lockedShares(lp),    0); 
        assertEq(withdrawalManager.exitCycleId(lp),     0);
    }

}

contract RemoveSharesFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6);
    }

    function test_removeShares_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.removeShares(1_000e6);
    }

    function test_removeShares_failIfNotPool() external {
        vm.expectRevert("PM:RS:NOT_POOL");
        poolManager.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfNotPoolManager() external {
        vm.expectRevert("WM:RS:NOT_POOL_MANAGER");
        withdrawalManager.removeShares(1_000e6, address(lp));
    }

    function test_removeShares_failIfWithdrawalIsPending() external {
        vm.warp(start + 2 weeks - 1);
        
        vm.prank(lp);
        vm.expectRevert("WM:RS:WITHDRAWAL_PENDING");
        pool.removeShares(1_000e6);

        // Success call
        vm.prank(lp);
        vm.warp(start + 2 weeks);
        pool.removeShares(1_000e6);
    }

    function test_removeShares_failIfInvalidShares() external {
        vm.warp(start + 2 weeks);

        vm.prank(lp);
        vm.expectRevert("WM:RS:SHARES_OOB");
        pool.removeShares(1_000e6 + 1);
    }

    function test_removeShares_failIfInvalidSharesWithZero() external {
        vm.warp(start + 2 weeks);

        vm.prank(lp);
        vm.expectRevert("WM:RS:SHARES_OOB");
        pool.removeShares(0);
    }

    function test_removeShares_failIfTransferFail() external {
        vm.warp(start + 2 weeks);

        // Forcefully remove shares from wm
        vm.prank(wm);
        pool.transfer(address(1), 1_000e6);

        vm.prank(lp);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        pool.removeShares(1_000e6);
    }

}
