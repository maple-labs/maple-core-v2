
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

contract RemoveSharesByIdQueueFailureTests is TestBaseWithAssertions {

    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
        wm = address(queueWM);

        deposit(lp, 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        assertRequest({
            poolManager: address(poolManager),
            requestId:   1,
            owner:       lp,
            shares:      1_000e6
        });
    }

    function test_removeSharesById_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("WM:PAUSED");
        queueWM.removeSharesById(1, 1_000e6);
    }

    function test_removeSharesById_failIfMaxUint128Exceeded() external {
        vm.prank(lp);
        vm.expectRevert("WM:TU:UINT256_CAST");
        queueWM.removeSharesById(type(uint256).max, 1);
    }

    function test_removeSharesById_failIfInvalidRequest() external {
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        queueWM.removeSharesById(2, 1_000e6);
    }

    function test_removeSharesById_failIfInvalidRequest_requestAlreadyRemoved() external {
        vm.prank(lp);
        queueWM.removeSharesById(1, 1_000e6);

        assertRequest({
            poolManager: address(poolManager),
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        vm.prank(lp);
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        queueWM.removeSharesById(1, 1);
    }

    function test_removeSharesById_failIfInvalidRequest_requestFullyProcessed() external {
        processRedemptionByOwners(address(pool), array(lp));

        assertRequest({
            poolManager: address(poolManager),
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        vm.prank(lp);
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        queueWM.removeSharesById(1, 1);
    }

    function test_removeSharesById_failIfNotOwner() external {
        vm.expectRevert("WM:RSBI:NOT_OWNER");
        queueWM.removeSharesById(1, 1_000e6);
    }

    function test_removeSharesById_failIfNoChange() external {
        vm.prank(lp);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        queueWM.removeSharesById(1, 0);
    }

    function test_removeSharesById_failIfInsufficientShares_requestNotProcessed() external {
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        vm.prank(lp);
        queueWM.removeSharesById(1, 1_000e6 + 1);
    }

    function test_removeSharesById_failIfInsufficientShares_requestPartiallyRemoved() external {
        vm.prank(lp);
        queueWM.removeSharesById(1, 1_000e6 - 1);

        assertRequest({
            poolManager: address(poolManager),
            requestId:   1,
            owner:       lp,
            shares:      1
        });

        vm.prank(lp);
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        queueWM.removeSharesById(1, 2);
    }

    function test_removeSharesById_failIfTransferFail() external {
        vm.prank(address(queueWM));
        pool.transfer(makeAddr("randomUser"), 1);

        vm.prank(lp);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        queueWM.removeSharesById(1, 1_000e6);
    }

}

contract RemoveSharesByIdQueueSuccessTests is TestBaseWithAssertions {

    address lp;
    address wm;

    uint256 requestedAmount1;
    uint256 requestedAmount2;
    uint256 requestedAmount3;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
        wm = address(queueWM);

        uint256 depositAmount = 16_000e6;
        deposit(lp, depositAmount);

        requestedAmount1 = 1_000e6;
        requestedAmount2 = 5_000e6;
        requestedAmount3 = 10_000e6;

        vm.startPrank(lp);
        pool.requestRedeem(requestedAmount1, lp);
        pool.requestRedeem(requestedAmount2, lp);
        pool.requestRedeem(requestedAmount3, lp);
        vm.stopPrank();

        assertRequest({
            poolManager: address(poolManager),
            requestId:   1,
            owner:       lp,
            shares:      requestedAmount1
        });

        assertRequest({
            poolManager: address(poolManager),
            requestId:   2,
            owner:       lp,
            shares:      requestedAmount2
        });

        assertRequest({
            poolManager: address(poolManager),
            requestId:   3,
            owner:       lp,
            shares:      requestedAmount3
        });

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: 1,
            lastRequestId: 3
        });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    depositAmount);
        assertEq(queueWM.totalShares(),             depositAmount);
    }

    function test_removeSharesById_sharesCompletelyRemoved_requestNotProcessed() external {
        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);
        uint256 requestIdToRemove           = 2;
        uint256 sharesToRemove              = requestedAmount2;

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(requestIdToRemove, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, 0);

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 1;
        expectedLpRequests[1] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,         shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
    }

    function test_removeSharesById_sharesCompletelyRemoved_requestNotProcessed_manualWithdrawal() external {
        assertFalse(queueWM.isManualWithdrawal(lp));

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));

        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);

        uint256 requestIdToRemove = 2;
        uint256 sharesToRemove    = requestedAmount2;

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(requestIdToRemove, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, 0);

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 1;
        expectedLpRequests[1] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,         shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
    }

    function test_removeSharesById_sharesCompletelyRemoved_afterPreviousRequestProcessed() external {
        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);
        uint256 sharesToRemove              = requestedAmount2;

        processRedemptionByIds(address(pool), array(1));

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 2;
        expectedLpRequests[1] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - requestedAmount1);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - requestedAmount1);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore - requestedAmount1); // exchange rate is 1:1
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), requestedAmount1);

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, 0);

        expectedLpRequests    = new uint256[](1);
        expectedLpRequests[0] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - requestedAmount1 - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore - requestedAmount1);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), requestedAmount1);
    }

    function test_removeSharesById_sharesCompletelyRemoved_afterPreviousRequestProcessed_manualWithdrawal() external {
        assertFalse(queueWM.isManualWithdrawal(lp));

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));

        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);
        uint256 sharesToRemove              = requestedAmount2;

        processRedemptionByIds(address(pool), array(1));

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 2;
        expectedLpRequests[1] = 3;
        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), requestedAmount1);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore); // exchange rate is 1:1
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, 0);

        expectedLpRequests    = new uint256[](1);
        expectedLpRequests[0] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), requestedAmount1);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);
    }

    function test_removeSharesById_sharesPartiallyRemoved_requestNotProcessed() external {
        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);

        uint256 sharesToRemove1 = 500e6;

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(1, sharesToRemove1);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertEq(sharesReturned,  sharesToRemove1);
        assertEq(sharesRemaining, requestedAmount1 - sharesToRemove1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 - sharesToRemove1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove1);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesReturned);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesReturned);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);

        uint256 sharesToRemove2 = 2_000e6;

        vm.prank(lp);
        ( sharesReturned, sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove2);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertEq(sharesReturned,  sharesToRemove2);
        assertEq(sharesRemaining, requestedAmount2 - sharesToRemove2);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 - sharesToRemove1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 - sharesToRemove2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove1 - sharesToRemove2);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove1 - sharesToRemove2);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove1 + sharesToRemove2);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove1 - sharesToRemove2);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);
    }

    function test_removeSharesById_sharesPartiallyRemoved_requestNotProcessed_manualWithdrawal() external {
        assertFalse(queueWM.isManualWithdrawal(lp));

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));

        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);

        uint256 sharesToRemove1 = 500e6;

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(1, sharesToRemove1);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertEq(sharesReturned,  sharesToRemove1);
        assertEq(sharesRemaining, requestedAmount1 - sharesToRemove1);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 - sharesToRemove1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove1);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesReturned);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesReturned);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);

        uint256 sharesToRemove2 = 2_000e6;

        vm.prank(lp);
        ( sharesReturned, sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove2);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertEq(sharesReturned,  sharesToRemove2);
        assertEq(sharesRemaining, requestedAmount2 - sharesToRemove2);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 - sharesToRemove1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 - sharesToRemove2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - sharesToRemove1 - sharesToRemove2);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove1 - sharesToRemove2);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove1 + sharesToRemove2);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove1 - sharesToRemove2);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);
    }

    function test_removeSharesById_sharesPartiallyRemoved_afterPreviousRequestProcessed() external {
        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);
        uint256 sharesToRemove              = 100e6;

        processRedemptionByIds(address(pool), array(1));

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 2;
        expectedLpRequests[1] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - requestedAmount1);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - requestedAmount1);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore - requestedAmount1); // exchange rate is 1:1
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), requestedAmount1);

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, requestedAmount2 - sharesToRemove);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp,         shares: sharesRemaining });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - requestedAmount1 - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore - requestedAmount1);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), requestedAmount1);
    }

    function test_removeSharesById_sharesPartiallyRemoved_afterPreviousRequestProcessed_manualWithdrawal() external {
        assertFalse(queueWM.isManualWithdrawal(lp));

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));

        uint256 totalRequestedAmountBefore = requestedAmount1 + requestedAmount2 + requestedAmount3;

        uint256[] memory expectedLpRequests = new uint256[](3);
        expectedLpRequests[0]               = 1;
        expectedLpRequests[1]               = 2;
        expectedLpRequests[2]               = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: requestedAmount1 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), 0);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        uint256 lpSharesBalanceBefore       = pool.balanceOf(lp);
        uint256 wmSharesBalanceBefore       = pool.balanceOf(wm);
        uint256 poolTotalAssetsBefore       = pool.totalAssets();
        uint256 wmDepositAssetBalanceBefore = IERC20(pool.asset()).balanceOf(wm);
        uint256 sharesToRemove              = 100e6;

        processRedemptionByIds(address(pool), array(1));

        expectedLpRequests    = new uint256[](2);
        expectedLpRequests[0] = 2;
        expectedLpRequests[1] = 3;

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp, shares: requestedAmount2 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp, shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), requestedAmount1);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);

        vm.prank(lp);
        ( uint256 sharesReturned, uint256 sharesRemaining ) = queueWM.removeSharesById(2, sharesToRemove);

        assertEq(sharesReturned,  sharesToRemove);
        assertEq(sharesRemaining, requestedAmount2 - sharesToRemove);

        assertUserRequests(address(poolManager), lp, expectedLpRequests);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp,         shares: sharesRemaining });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp,         shares: requestedAmount3 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(queueWM.manualSharesAvailable(lp), requestedAmount1);
        assertEq(queueWM.userEscrowedShares(lp),    totalRequestedAmountBefore - requestedAmount1 - sharesToRemove);
        assertEq(queueWM.totalShares(),             totalRequestedAmountBefore - sharesToRemove);

        assertEq(pool.balanceOf(lp),                 lpSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(wm),                 wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                 poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(wm), wmDepositAssetBalanceBefore);
        assertEq(IERC20(pool.asset()).balanceOf(lp), 0);
    }

}
