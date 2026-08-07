// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterRemoveRequestsTests is SyrupBitcoinTestBase {

    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");

    uint256 assetsToDeposit1 = 137.545e8;
    uint256 assetsToDeposit2 = 93.11674e8;
    uint256 assetsToDeposit3 = 288.4356e8;

    uint256 requestId1;
    uint256 requestId2;
    uint256 requestId3;

    uint256 sharesToRedeem1;
    uint256 sharesToRedeem2;
    uint256 sharesToRedeem3;

    uint256 sharesToProcess;

    uint256[] firstRequest;
    uint256[] twoRequests;

    function setUp() public virtual override {
        super.setUp();

        ( sharesToRedeem1, requestId1 ) = requestRouterRedeem(lp1, assetsToDeposit1);
        ( sharesToRedeem2, requestId2 ) = requestRouterRedeem(lp2, assetsToDeposit2);
        ( sharesToRedeem3, requestId3 ) = requestRouterRedeem(lp1, assetsToDeposit3);

        sharesToProcess = sharesToRedeem1 / 3;

        firstRequest.push(requestId1);
        twoRequests.push(requestId1);
        twoRequests.push(requestId3);
    }

    function test_removeRequests_routerPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(bitcoinRouter), true);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_notAuthorized() external {
        vm.expectRevert("SBR:NOT_REDEEMER");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_zeroAddress() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:NO_OWNER");
        bitcoinRouter.removeRequests(address(0), twoRequests);
    }

    function test_removeRequests_emptyArray() external {
        uint256[] memory noRequests = new uint256[](0);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:NO_REQUESTS");
        bitcoinRouter.removeRequests(lp1, noRequests);
    }

    function test_removeRequests_zeroRequest() external {
        uint256[] memory zeroRequest = new uint256[](1);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:INVALID_OWNER");
        bitcoinRouter.removeRequests(lp1, zeroRequest);
    }

    function test_removeRequests_nonExistingRequest() external {
        uint256[] memory missingRequest = new uint256[](1);

        missingRequest[0] = requestId3 + 1;

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:INVALID_OWNER");
        bitcoinRouter.removeRequests(lp1, missingRequest);
    }

    function test_removeRequests_cancelledRequest() external {
        vm.prank(lp1);
        bitcoinRouter.removeSharesById(requestId1, sharesToRedeem1);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:INVALID_OWNER");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_redeemedRequest() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(twoRequests);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:INVALID_OWNER");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_invalidOwner() external {
        uint256[] memory incompatibleRequests = new uint256[](2);

        incompatibleRequests[0] = requestId1;
        incompatibleRequests[1] = requestId2;

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:INVALID_OWNER");
        bitcoinRouter.removeRequests(lp1, incompatibleRequests);
    }

    function test_removeRequests_fullyProcessedRequest() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToRedeem1);

        vm.prank(operationalAdmin);
        vm.expectRevert("SBR:RR:ZERO_SHARES");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_withdrawalManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(withdrawalManager), true);

        vm.prank(operationalAdmin);
        vm.expectRevert("WM:PAUSED");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_transferFail() external {
        vm.prank(address(withdrawalManager));
        pool.transfer(address(0), sharesToRedeem1 + sharesToRedeem2);

        vm.prank(operationalAdmin);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        bitcoinRouter.removeRequests(lp1, twoRequests);
    }

    function test_removeRequests_unprocessedRequest() external {
        assertEq(pool.balanceOf(address(lp1)),               0);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        assertRequestOnRouter(requestId1, address(depositAsset), address(lp1), sharesToRedeem1);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(depositAsset), address(lp1), sharesToRedeem3);

        assertEq(withdrawalManager.totalShares(),                              sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        ( , uint256 sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , uint256 sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , uint256 sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, sharesToRedeem1);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, sharesToRedeem3);

        vm.prank(operationalAdmin);
        bitcoinRouter.removeRequests(lp1, firstRequest);

        assertEq(pool.balanceOf(address(lp1)),               sharesToRedeem1);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem2 + sharesToRedeem3);

        assertRequestOnRouter(requestId1, address(0),            address(0),   0);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(depositAsset), address(lp1), sharesToRedeem3);

        assertEq(withdrawalManager.totalShares(),                              sharesToRedeem2 + sharesToRedeem3);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), sharesToRedeem2 + sharesToRedeem3);

        ( , sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, 0);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, sharesToRedeem3);
    }

    function test_removeRequests_multipleRequests() external {
        assertEq(pool.balanceOf(address(lp1)),               0);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        assertRequestOnRouter(requestId1, address(depositAsset), address(lp1), sharesToRedeem1);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(depositAsset), address(lp1), sharesToRedeem3);

        assertEq(withdrawalManager.totalShares(),                              sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        ( , uint256 sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , uint256 sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , uint256 sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, sharesToRedeem1);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, sharesToRedeem3);

        vm.prank(operationalAdmin);
        bitcoinRouter.removeRequests(lp1, twoRequests);

        assertEq(pool.balanceOf(address(lp1)),               sharesToRedeem1 + sharesToRedeem3);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem2);

        assertRequestOnRouter(requestId1, address(0),            address(0),   0);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(0),            address(0),   0);

        assertEq(withdrawalManager.totalShares(),                              sharesToRedeem2);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), sharesToRedeem2);

        ( , sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, 0);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, 0);
    }

    function test_removeRequests_partiallyProcessed() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToProcess);

        assertEq(pool.balanceOf(address(lp1)),               0);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3);

        assertRequestOnRouter(requestId1, address(depositAsset), address(lp1), sharesToRedeem1);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(depositAsset), address(lp1), sharesToRedeem3);

        uint256 totalShares = sharesToRedeem1 + sharesToRedeem2 + sharesToRedeem3;

        assertEq(withdrawalManager.totalShares(),                              totalShares);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), totalShares - sharesToProcess);

        ( , uint256 sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , uint256 sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , uint256 sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, sharesToRedeem1 - sharesToProcess);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, sharesToRedeem3);

        vm.prank(operationalAdmin);
        bitcoinRouter.removeRequests(lp1, firstRequest);

        assertEq(pool.balanceOf(address(lp1)),               sharesToRedeem1 - sharesToProcess);
        assertEq(pool.balanceOf(address(lp2)),               0);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem2 + sharesToRedeem3 + sharesToProcess);

        assertRequestOnRouter(requestId1, address(depositAsset), address(lp1), sharesToProcess);
        assertRequestOnRouter(requestId2, address(depositAsset), address(lp2), sharesToRedeem2);
        assertRequestOnRouter(requestId3, address(depositAsset), address(lp1), sharesToRedeem3);

        assertEq(withdrawalManager.totalShares(),                              sharesToRedeem2 + sharesToRedeem3 + sharesToProcess);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), sharesToRedeem2 + sharesToRedeem3);

        ( , sharesLocked1 ) = withdrawalManager.requests(requestId1);
        ( , sharesLocked2 ) = withdrawalManager.requests(requestId2);
        ( , sharesLocked3 ) = withdrawalManager.requests(requestId3);

        assertEq(sharesLocked1, 0);
        assertEq(sharesLocked2, sharesToRedeem2);
        assertEq(sharesLocked3, sharesToRedeem3);
    }

}
