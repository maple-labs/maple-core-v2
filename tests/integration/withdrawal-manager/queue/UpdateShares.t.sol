
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract UpdateSharesQueueTests is TestBaseWithAssertions {

    address lp;
    address wm;

    function setUp() public override {
        start = block.timestamp;

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

        deposit(lp, 16_000e6);

        vm.startPrank(lp);
        pool.requestRedeem(1_000e6,  lp);
        pool.requestRedeem(5_000e6,  lp);
        pool.requestRedeem(10_000e6, lp);
        vm.stopPrank();

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 16_000e6);
    }

    function test_updateShares_partialDecrease() external {
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 10_000e6 });

        vm.prank(lp);
        queueWM.updateShares(3, 4_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 4_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(pool.balanceOf(lp),    6_000e6);
        assertEq(pool.balanceOf(wm),    10_000e6);
        assertEq(queueWM.totalShares(), 10_000e6);


        vm.prank(lp);
        queueWM.updateShares(2, 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 4_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(pool.balanceOf(lp),    9_000e6);
        assertEq(pool.balanceOf(wm),    7_000e6);
        assertEq(queueWM.totalShares(), 7_000e6);
    }

    function test_updateShares_removeRequest() external {
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 10_000e6 });

        vm.prank(lp);
        queueWM.updateShares(2, 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 10_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(pool.balanceOf(lp)   , 5_000e6);
        assertEq(pool.balanceOf(wm)   , 11_000e6);
        assertEq(queueWM.totalShares(), 11_000e6);

        assertLastRequestId(address(queueWM), lp, 3);

        uint256[] memory expectedUserRequests = new uint256[](2);
        expectedUserRequests[0]               = 1;
        expectedUserRequests[1]               = 3;

        assertUserRequests(address(poolManager), lp, expectedUserRequests);
    }

    function test_updateShares_increaseRequest() external {
        vm.prank(lp);
        deposit(lp, 2_000e6);

        vm.prank(lp);
        pool.approve(address(queueWM), 6_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 10_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        vm.prank(lp);
        queueWM.updateShares(2, 6_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: 10_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp, shares: 6_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertLastRequestId(address(queueWM), lp, 4);

        uint256[] memory expectedUserRequests = new uint256[](3);
        expectedUserRequests[0]               = 1;
        expectedUserRequests[1]               = 3;
        expectedUserRequests[2]               = 4;

        assertUserRequests(address(poolManager), lp, expectedUserRequests);
    }

}

contract UpdateSharesQueueFailureTests is TestBaseWithAssertions {

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

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        // Transfer funds into the pool so exchange rate is different than 1
        fundsAsset.mint(address(pool), 1_000e6);
    }

    function test_updateShares_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("WM:PAUSED");
        queueWM.updateShares(1, 1_000e6);
    }

    function test_updateShares_failIfInvalidRequest() external {
        vm.expectRevert("WM:US:INVALID_REQUEST");
        queueWM.updateShares(2, 1_000e6);
    }

    function test_updateShares_failIfNotOwner() external {
        vm.expectRevert("WM:US:NOT_OWNER");
        queueWM.updateShares(1, 1_000e6);
    }

    function test_updateShares_failIfNoChange() external {
        vm.expectRevert("WM:US:NO_CHANGE");
        vm.prank(lp);
        queueWM.updateShares(1, 1_000e6);
    }

    function test_updateShares_transferFromUserFail() external {
        vm.prank(lp);
        pool.approve(address(queueWM), 8_000e6 - 1);

        vm.expectRevert("WM:AS:FAILED_TRANSFER");
        vm.prank(lp);
        queueWM.updateShares(1, 8_000e6);
    }

    function test_updateShares_transferOnRemovalFail() external {
        vm.prank(address(queueWM));
        pool.transfer(makeAddr("randomUser"), 1);

        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        vm.prank(lp);
        queueWM.updateShares(1, 0);
    }

}
