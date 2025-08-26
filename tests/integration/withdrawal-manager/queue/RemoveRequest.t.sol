// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase, TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract RemoveRequestTests is TestBaseWithAssertions {

    address lp1;
    address lp2;
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

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        wm  = address(queueWM);

        deposit(lp1, 1_000e6);
        deposit(lp2, 2_000e6);

        fundsAsset.mint(address(pool), 3_000e6);
    }

    function test_removeRequest_success() external {
        requestRedeem(lp1, 1_000e6);

        assertEq(pool.balanceOf(lp1),         0);
        assertEq(pool.balanceOf(wm),          1_000e6);
        assertEq(queueWM.totalShares(),       1_000e6);

        assertLastRequestId(address(queueWM), lp1, 1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);

        requestRedeem(lp2, 2_000e6);

        assertEq(pool.balanceOf(lp2),         0);
        assertEq(pool.balanceOf(wm),          3_000e6);
        assertEq(queueWM.totalShares(),       3_000e6);

        assertLastRequestId(address(queueWM), lp2, 2);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

        ( uint128[] memory requestIds_, ) = queueWM.requestsByOwner(lp1);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds_);

        assertEq(pool.balanceOf(lp1),         1_000e6);
        assertEq(pool.balanceOf(lp2),         0);
        assertEq(pool.balanceOf(wm),          2_000e6);
        assertEq(queueWM.totalShares(),       2_000e6);

        assertLastRequestId(address(queueWM), lp1, 0);
        assertLastRequestId(address(queueWM), lp2, 2);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
    }

    function test_removeRequest_forManual() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        requestRedeem(lp1, 1_000e6);

        assertEq(pool.balanceOf(lp1),         0);
        assertEq(pool.balanceOf(wm),          1_000e6);
        assertEq(queueWM.totalShares(),       1_000e6);

        assertLastRequestId(address(queueWM), lp1, 1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);

        ( uint128[] memory requestIds_, ) = queueWM.requestsByOwner(lp1);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds_);

        assertEq(pool.balanceOf(lp1),         1_000e6);
        assertEq(pool.balanceOf(wm),          0);
        assertEq(queueWM.totalShares(),       0);

        assertLastRequestId(address(queueWM), lp1, 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 0);
    }

    function test_removeRequest_partialRedemption() external {
        requestRedeem(lp1, 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(400e6);  // partial redemption

        assertEq(pool.balanceOf(lp1),         0);
        assertEq(pool.balanceOf(wm),          600e6);
        assertEq(queueWM.totalShares(),       600e6);

        assertLastRequestId(address(queueWM), lp1, 1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 600e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 600e6);

        ( uint128[] memory requestIds_, ) = queueWM.requestsByOwner(lp1);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds_);

        assertEq(pool.balanceOf(lp1),         600e6);
        assertEq(pool.balanceOf(wm),          0);
        assertEq(queueWM.totalShares(),       0);

        assertLastRequestId(address(queueWM), lp1, 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 0);
    }

    function test_removeRequest_manualPartialRedemption() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        requestRedeem(lp1, 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(600e6);

        assertEq(pool.balanceOf(lp1),         0);
        assertEq(pool.balanceOf(wm),          1_000e6);
        assertEq(queueWM.totalShares(),       1_000e6);

        assertLastRequestId(address(queueWM), lp1, 1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 400e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 400e6);

        assertEq(queueWM.manualSharesAvailable(lp1), 600e6);

        ( uint128[] memory requestIds_, ) = queueWM.requestsByOwner(lp1);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds_);

        assertEq(pool.balanceOf(lp1),         400e6);
        assertEq(pool.balanceOf(wm),          600e6);
        assertEq(queueWM.totalShares(),       600e6);

        assertLastRequestId(address(queueWM), lp1, 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 0);

        assertEq(queueWM.manualSharesAvailable(lp1), 600e6);
    }

    function test_removeRequest_sameAddressWithMultipleRequests() external {
        requestRedeem(lp1, 400e6);

        assertEq(pool.balanceOf(lp1),   600e6);
        assertEq(pool.balanceOf(wm),    400e6);
        assertEq(queueWM.totalShares(), 400e6);

        assertLastRequestId(address(queueWM), lp1, 1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 400e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });
        assertEq(queueWM.userEscrowedShares(lp1), 400e6);

        requestRedeem(lp1, 300e6);

        assertEq(pool.balanceOf(lp1),   300e6);
        assertEq(pool.balanceOf(wm),    700e6);
        assertEq(queueWM.totalShares(), 700e6);

        assertLastRequestId(address(queueWM), lp1, 2);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 400e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp1, shares: 300e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });
        assertEq(queueWM.userEscrowedShares(lp1), 700e6);

        requestRedeem(lp1, 200e6);

        assertEq(pool.balanceOf(lp1),   100e6);
        assertEq(pool.balanceOf(wm),    900e6);
        assertEq(queueWM.totalShares(), 900e6);

        assertLastRequestId(address(queueWM), lp1, 3);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 400e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp1, shares: 300e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp1, shares: 200e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.userEscrowedShares(lp1), 900e6);

        // remove middle request
        uint128[] memory requestIds = new uint128[](1);
        requestIds[0]               = 2;

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds);

        assertEq(pool.balanceOf(lp1),   400e6);
        assertEq(pool.balanceOf(wm),    600e6);
        assertEq(queueWM.totalShares(), 600e6);

        assertLastRequestId(address(queueWM), lp1, 3);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 400e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp1, shares: 200e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.userEscrowedShares(lp1), 600e6);

        // remove the rest of the requests
        requestIds    = new uint128[](2);
        requestIds[0] = 1;
        requestIds[1] = 3;

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp1, requestIds);

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        assertLastRequestId(address(queueWM), lp1, 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });
        assertEq(queueWM.userEscrowedShares(lp1), 0);
    }

}

contract RemoveRequestFailureTests is TestBase {

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

        fundsAsset.mint(address(pool), 1_000e6);

        requestRedeem(lp, 1_000e6);
    }

    function test_removeRequest_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PAUSED");
        queueWM.removeRequest(lp, new uint128[](0));
    }

    function test_removeRequest_failIfNotPoolDelegate() external {
        uint128[] memory requestIds = _createRemoveRequestIds();

        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp, requestIds);

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp, requestIds);
    }

    function test_removeRequest_failIfNotGovernor() external {
        uint128[] memory requestIds = _createRemoveRequestIds();

        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp, requestIds);

        vm.prank(governor);
        queueWM.removeRequest(lp, requestIds);
    }

    function test_removeRequest_failIfNotOperationalAdmin() external {
        uint128[] memory requestIds = _createRemoveRequestIds();

        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.removeRequest(lp, requestIds);

        vm.prank(operationalAdmin);
        queueWM.removeRequest(lp, requestIds);
    }

    function test_removeRequest_failIfNotInQueue() external {
        uint128[] memory requestIds = _createRemoveRequestIds();

        vm.prank(poolDelegate);
        queueWM.removeRequest(lp, requestIds);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:NOT_IN_QUEUE");
        queueWM.removeRequest(lp, requestIds);
    }

    function test_removeRequest_failIfTransferFail() external {
        vm.prank(wm);
        pool.transfer(address(1), 1_000e6);

        uint128[] memory requestIds = _createRemoveRequestIds();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:TRANSFER_FAIL");
        queueWM.removeRequest(lp, requestIds);
    }

    function _createRemoveRequestIds() internal view returns (uint128[] memory requestIds) {
        ( uint128[] memory requests, ) = queueWM.requestsByOwner(lp);

        requestIds    = new uint128[](1);
        requestIds[0] = requests[0];
    }

}
