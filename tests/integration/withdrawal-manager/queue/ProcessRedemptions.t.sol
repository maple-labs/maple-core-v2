// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract ProcessRedemptionsTests is TestBaseWithAssertions {

    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");
    address lp3 = makeAddr("lp3");
    address lp4 = makeAddr("lp4");
    address lp5 = makeAddr("lp5");
    address lp6 = makeAddr("lp6");

    address wm;  // Helper to avoid casting

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

        deposit(lp1, 1_000e6);
        deposit(lp2, 2_000e6);
        deposit(lp3, 3_000e6);
        deposit(lp4, 4_000e6);

        wm = address(queueWM);
    }

    function test_processRedemptions_revert_zeroRequests() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:ZERO_REQUESTS");
        queueWM.processRedemptions(new uint256[](0));
    }

    function test_processRedemptions_revert_lowLiquidity() external {
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        // Need to fund a loan so the exchange rate isn't affected by funds in the pool
        address loan = createOpenTermLoan({
            borrower:  makeAddr("borrower"),
            lender:    poolManager.strategyList(0),
            asset:     address(fundsAsset),
            principal: 10_000e6,
            terms:     [gracePeriod, noticePeriod, paymentInterval],
            rates:     [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        });

        fundLoan(address(loan));

        // Request redemptions
        requestRedeem(lp1, 1_000e6);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = queueWM.requestIds(lp1);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        queueWM.processRedemptions(requestIds);
    }

    function test_processRedemptions_revert_batchLowLiquidityButProcessSingleLiquidRequest() external {
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        address loan = createOpenTermLoan({
            borrower:  makeAddr("borrower"),
            lender:    poolManager.strategyList(0),
            asset:     address(fundsAsset),
            principal: 8_500e6,
            terms:     [gracePeriod, noticePeriod, paymentInterval],
            rates:     [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        });

        fundLoan(address(loan));

        // pool has enough liquidity for request 1, but not for requests 1 and 2 together.
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_500e6);

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(wm),    3_000e6);
        assertEq(queueWM.totalShares(), 3_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        queueWM.processRedemptions(array(1, 2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_500e6);

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(wm),    3_000e6);
        assertEq(queueWM.totalShares(), 3_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

        // first request remains independently processable after the failed batch
        processRedemptionByIds(address(pool), array(1));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(fundsAsset.balanceOf(lp1),           1_000e6);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), 500e6);

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
    }

    function test_processRedemptions_processOutOfOrder() external {
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(pool.balanceOf(wm),    6_000e6);
        assertEq(queueWM.totalShares(), 6_000e6);

        // process the last request first, earlier requests should remain pending
        processRedemptionByIds(address(pool), array(3));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp1), 0);
        assertEq(fundsAsset.balanceOf(lp2), 0);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 0);

        assertEq(pool.balanceOf(wm),    3_000e6);
        assertEq(queueWM.totalShares(), 3_000e6);

        // process the first request next, queue should now point to the middle request
        processRedemptionByIds(address(pool), array(1));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp1), 1_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 0);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 0);

        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        // process the remaining request, queue should advance past the tail
        processRedemptionByIds(address(pool), array(2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp1), 1_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);

        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);
    }

    function test_processRedemptions_singleLpMultipleRequests_processOutOfOrder() external {
        requestRedeem(lp4, 1_000e6);
        requestRedeem(lp4, 1_500e6);
        requestRedeem(lp4, 1_500e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp4, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp4, shares: 1_500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp4, shares: 1_500e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp4), 0);
        assertEq(pool.balanceOf(lp4),       0);
        assertEq(pool.balanceOf(wm),        4_000e6);
        assertEq(queueWM.totalShares(),     4_000e6);

        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        processRedemptionByIds(address(pool), array(3));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp4,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp4,        shares: 1_500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp4), 1_500e6);
        assertEq(pool.balanceOf(wm),        2_500e6);
        assertEq(queueWM.totalShares(),     2_500e6);

        assertEq(queueWM.userEscrowedShares(lp4), 2_500e6);

        processRedemptionByIds(address(pool), array(1));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp4,        shares: 1_500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp4), 2_500e6);
        assertEq(pool.balanceOf(wm),        1_500e6);
        assertEq(queueWM.totalShares(),     1_500e6);

        assertEq(queueWM.userEscrowedShares(lp4), 1_500e6);

        processRedemptionByIds(address(pool), array(2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(pool.balanceOf(lp4),       0);
        assertEq(pool.balanceOf(wm),        0);
        assertEq(queueWM.totalShares(),     0);

        assertEq(queueWM.userEscrowedShares(lp4), 0);
    }

    function test_processRedemptions_processChunks_processOutOfOrder() external {
        deposit(lp5, 5_000e6);
        deposit(lp6, 6_000e6);

        requestRedeem(lp1, 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);

        requestRedeem(lp2, 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

        requestRedeem(lp3, 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);

        requestRedeem(lp4, 4_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        requestRedeem(lp5, 5_000e6);
        assertEq(queueWM.userEscrowedShares(lp5), 5_000e6);

        requestRedeem(lp6, 6_000e6);
        assertEq(queueWM.userEscrowedShares(lp6), 6_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp5, shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 6, owner: lp6, shares: 6_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 6 });

        assertEq(pool.balanceOf(wm),    21_000e6);
        assertEq(queueWM.totalShares(), 21_000e6);

        // process chunks out of order, head should remain blocked by request 1
        processRedemptionByIds(address(pool), array(4, 2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3,        shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp5,        shares: 5_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 6, owner: lp6,        shares: 6_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 6 });

        assertEq(fundsAsset.balanceOf(lp1), 0);
        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 0);
        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(fundsAsset.balanceOf(lp5), 0);
        assertEq(fundsAsset.balanceOf(lp6), 0);

        assertEq(pool.balanceOf(wm),    15_000e6);
        assertEq(queueWM.totalShares(), 15_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 0);
        assertEq(queueWM.userEscrowedShares(lp5), 5_000e6);
        assertEq(queueWM.userEscrowedShares(lp6), 6_000e6);

        // process another middle chunk, head should still remain blocked by request 1
        processRedemptionByIds(address(pool), array(3, 5));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 6, owner: lp6,        shares: 6_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 6 });

        assertEq(fundsAsset.balanceOf(lp1), 0);
        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);
        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(fundsAsset.balanceOf(lp5), 5_000e6);
        assertEq(fundsAsset.balanceOf(lp6), 0);

        assertEq(pool.balanceOf(wm),    7_000e6);
        assertEq(queueWM.totalShares(), 7_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);
        assertEq(queueWM.userEscrowedShares(lp5), 0);
        assertEq(queueWM.userEscrowedShares(lp6), 6_000e6);

        // process the head and tail together, queue should advance past all cleared requests
        processRedemptionByIds(address(pool), array(1, 6));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 6, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 7, lastRequestId: 6 });

        assertEq(fundsAsset.balanceOf(lp1), 1_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);
        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(fundsAsset.balanceOf(lp5), 5_000e6);
        assertEq(fundsAsset.balanceOf(lp6), 6_000e6);

        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);
        assertEq(queueWM.userEscrowedShares(lp5), 0);
        assertEq(queueWM.userEscrowedShares(lp6), 0);
    }

    function test_processRedemptions_processHeadAfterCompletingMiddle_advancesToLatestRequest() external {
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        processRedemptionByIds(address(pool), array(2, 3, 4));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(wm),    1_000e6);
        assertEq(queueWM.totalShares(), 1_000e6);

        deposit(lp5, 5_000e6);
        requestRedeem(lp5, 5_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp5, shares: 5_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 5 });

        assertEq(pool.balanceOf(wm),    6_000e6);
        assertEq(queueWM.totalShares(), 6_000e6);

        processRedemptionByIds(address(pool), array(1));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 5, owner: lp5,        shares: 5_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 5 });

        assertEq(fundsAsset.balanceOf(lp1), 1_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);
        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(fundsAsset.balanceOf(lp5), 0);

        assertEq(pool.balanceOf(wm),    5_000e6);
        assertEq(queueWM.totalShares(), 5_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp5), 5_000e6);
    }

    function test_processRedemptions_blacklistedRequestsStayPending_processOthers() external {
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        // simulate USDC refusing to transfer to a blacklisted receiver
        vm.mockCall(
            address(fundsAsset),
            abi.encodeWithSignature("transfer(address,uint256)", lp2, 2_000e6),
            abi.encode(false)
        );

        vm.prank(poolDelegate);
        vm.expectRevert("P:B:TRANSFER");
        queueWM.processRedemptions(array(1, 2, 3, 4));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        processRedemptionByIds(address(pool), array(1, 3, 4));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 4 });

        assertEq(fundsAsset.balanceOf(lp1),           1_000e6);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           3_000e6);
        assertEq(fundsAsset.balanceOf(lp4),           4_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 2_000e6);

        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        vm.clearMockedCalls();

        processRedemptionByIds(address(pool), array(2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(pool.balanceOf(wm),        0);
        assertEq(queueWM.totalShares(),     0);

        assertEq(queueWM.userEscrowedShares(lp2), 0);
    }

    function test_processRedemptions_multipleLps_processInOrder() external {
        // Request all redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        // Transfer funds into the pool so exchange rate is different than 1
        // 10_000e6 shares for 11_000e6 assets -> Exchange = 11_000e6 / 10_000e6 = 1.1
        fundsAsset.mint(address(pool), 1_000e6);

        // Pre-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    10_000e6);
        assertEq(queueWM.totalShares(), 10_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 11_000e6);

        // Process full liquidity
        processRedemptionByIds(address(pool), array(1, 2, 3, 4));

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);  // assets = shares * 1.1 (exchange rate) = 1_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp2),           2_200e6);  // assets = shares * 1.1 (exchange rate) = 2_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp3),           3_300e6);  // assets = shares * 1.1 (exchange rate) = 3_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp4),           4_400e6);  // assets = shares * 1.1 (exchange rate) = 4_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);
    }

    function test_processRedemptions_differentExchangeRate_processInOrder() external {
        // Request all redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        // Exchange rate = 10_000e6 shares for 11_000e6 assets = 11_000e6 / 10_000e6 = 1.1
        fundsAsset.mint(address(pool), 1_000e6);

        // Pre-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    10_000e6);
        assertEq(queueWM.totalShares(), 10_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 11_000e6);

        // Process 1st request.
        processRedemptionByIds(address(pool), array(1));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3,        shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4,        shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    9_000e6);
        assertEq(queueWM.totalShares(), 9_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);  // 1_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 9_900e6);  // 11_000e6 - 1_100e6

        // Exchange rate = 9_000e6 shares for 9_900e6 + 900e6 assets = 10_800e6 / 9_000e6 = 1.2.
        fundsAsset.mint(address(pool), 900e6);

        // Process 2nd and 3rd requests.
        processRedemptionByIds(address(pool), array(2, 3));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4,        shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    4_000e6);
        assertEq(queueWM.totalShares(), 4_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);
        assertEq(fundsAsset.balanceOf(lp2),           2_400e6);  // 2_000e6 * 1.2
        assertEq(fundsAsset.balanceOf(lp3),           3_600e6);  // 3_000e6 * 1.2
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 4_800e6);  // 10_800e6 - 2_400e6 - 3_600e6

        // Exchange rate = 4_000e6 shares for 4_800e6 + 800e6 assets = 5_600e6 / 4_000e6 = 1.4.
        fundsAsset.mint(address(pool), 800e6);

        // Process 4th request.
        processRedemptionByIds(address(pool), array(4));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);
        assertEq(fundsAsset.balanceOf(lp2),           2_400e6);
        assertEq(fundsAsset.balanceOf(lp3),           3_600e6);
        assertEq(fundsAsset.balanceOf(lp4),           5_600e6);  // 4_000e6 * 1.4
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);
    }

    function test_processRedemptions_manualWithDifferentExchangeRates_processInOrder() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        // Request all redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        // Exchange rate = 10_000e6 shares for 9_000e6 assets = 9_000e6 / 10_000e6 = 0.9
        fundsAsset.burn(address(pool), 1_000e6);

        // Pre-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    10_000e6);
        assertEq(queueWM.totalShares(), 10_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 9_000e6);

        // Process full liquidity
        processRedemptionByIds(address(pool), array(1, 2, 3, 4));

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           900e6);    // shares * 0.9
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           2_700e6);  // shares * 0.9
        assertEq(fundsAsset.balanceOf(lp4),           3_600e6);  // shares * 0.9
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_800e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        // Change the exchange rate after requests have been processed
        // Exchange rate = 2_000e6 shares for 1_800e6 + 1_000e6 assets = 2_800e6 / 2_000e6 = 1.4
        fundsAsset.mint(address(pool), 1_000e6);

        redeem(lp2, 2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2),  0);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp2),           2_800e6);  // 2_000e6 * 1.4
    }

    function test_processRedemptions_multipleManualBatched_processInOrder() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        // Manual user will request and be serviced many times over before redeeming
        for (uint256 i = 0; i < 5; i++) {
            deposit(lp2, 2_000e6);
            requestRedeem(lp2, 2_000e6);

            assertRequest({ poolManager: address(poolManager), requestId: uint128(i + 1), owner: lp2, shares: 2_000e6});
            assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);

            processRedemptionByIds(address(pool), array(i + 1));

            assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6 * (i + 1));
        }

        // Finally redeem all
        redeem(lp2, 10_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }

    function test_processRedemptions_singleLpMultipleManualRequests_processIndividuallyAndBatch() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp4, true);

        requestRedeem(lp4, 500e6);
        requestRedeem(lp4, 700e6);
        requestRedeem(lp4, 1_300e6);
        requestRedeem(lp4, 1_500e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp4, shares: 500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp4, shares: 700e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp4, shares: 1_300e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 1_500e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    4_000e6);
        assertEq(queueWM.totalShares(), 4_000e6);

        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);
        assertEq(queueWM.manualSharesAvailable(lp4), 0);

        processRedemptionByIds(address(pool), array(2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp4,        shares: 500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp4,        shares: 1_300e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4,        shares: 1_500e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(queueWM.userEscrowedShares(lp4), 3_300e6);
        assertEq(queueWM.manualSharesAvailable(lp4), 700e6);
        assertEq(queueWM.totalShares(), 4_000e6);

        processRedemptionByIds(address(pool), array(4));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp4,        shares: 500e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp4,        shares: 1_300e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(queueWM.userEscrowedShares(lp4), 1_800e6);
        assertEq(queueWM.manualSharesAvailable(lp4), 2_200e6);
        assertEq(queueWM.totalShares(), 4_000e6);

        processRedemptionByIds(address(pool), array(1, 3));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(fundsAsset.balanceOf(lp4), 0);
        assertEq(pool.balanceOf(lp4),       0);
        assertEq(pool.balanceOf(wm),        4_000e6);
        assertEq(queueWM.totalShares(),     4_000e6);

        assertEq(queueWM.userEscrowedShares(lp4), 0);
        assertEq(queueWM.manualSharesAvailable(lp4), 4_000e6);

        redeem(lp4, 4_000e6);

        assertEq(fundsAsset.balanceOf(lp4), 4_000e6);
        assertEq(pool.balanceOf(lp4),       0);
        assertEq(pool.balanceOf(wm),        0);
        assertEq(queueWM.totalShares(),     0);

        assertEq(queueWM.manualSharesAvailable(lp4), 0);
    }

    function test_processRedemptions_manualSharesStayAvailableWhenOwnerBlacklistedAfterProcessing() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);

        processRedemptionByIds(address(pool), array(1, 2, 3));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 3 });

        assertEq(fundsAsset.balanceOf(lp1), 1_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 0);
        assertEq(fundsAsset.balanceOf(lp3), 3_000e6);

        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(queueWM.userEscrowedShares(lp2),    0);
        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        // Simulate the owner becoming blacklisted after their request has already been processed into manual shares.
        vm.mockCall(
            address(fundsAsset),
            abi.encodeWithSignature("transfer(address,uint256)", lp2, 2_000e6),
            abi.encode(false)
        );

        vm.prank(lp2);
        vm.expectRevert("P:B:TRANSFER");
        pool.redeem(2_000e6, lp2, lp2);

        assertEq(fundsAsset.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),        2_000e6);
        assertEq(queueWM.totalShares(),     2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        vm.clearMockedCalls();

        redeem(lp2, 2_000e6);

        assertEq(fundsAsset.balanceOf(lp2), 2_000e6);
        assertEq(pool.balanceOf(wm),        0);
        assertEq(queueWM.totalShares(),     0);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }

    function test_processRedemptions_withCancelledRequest_processInOrder() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        // Request all redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        // 10_000e6 shares for 11_000e6 assets -> Exchange = 11_000e6 / 10_000e6 = 1.1
        fundsAsset.mint(address(pool), 1_000e6);

        // Pre-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    10_000e6);
        assertEq(queueWM.totalShares(), 10_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 11_000e6);

        uint256[] memory requestIds = array(1, 2, 3, 4);

        // LP3 cancels their request
        removeShares(address(pool), lp3, 3_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(wm),    7_000e6);
        assertEq(queueWM.totalShares(), 7_000e6);

        // Process full liquidity
        processRedemptionByIds(address(pool), requestIds);

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   3_000e6);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);  // assets = shares * 1.1 (exchange rate) = 1_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           4_400e6);  // assets = shares * 1.1 (exchange rate) = 4_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 5_500e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);
    }

    function test_processRedemptions_cancelledRequests_noOp() external {
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(wm),    3_000e6);
        assertEq(queueWM.totalShares(), 3_000e6);

        removeShares(address(pool), lp1, 1_000e6);
        removeShares(address(pool), lp2, 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 2 });

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), 10_000e6);

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(lp2),   2_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        processRedemptionByIds(address(pool), array(1, 2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 2 });

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), 10_000e6);

        assertEq(pool.balanceOf(lp1),   1_000e6);
        assertEq(pool.balanceOf(lp2),   2_000e6);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);
    }

    function test_processRedemptions_processMoreRequestsThanPending_processInOrder() external {
        // Request all withdrawals.
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);
        requestRedeem(lp4, 4_000e6);

        // Deposit extra liquidity.
        deposit(lp5, 100_000e6);

        // Pre assertions.
        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 110_000e6);

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(lp3), 0);
        assertEq(pool.balanceOf(lp4), 0);
        assertEq(pool.balanceOf(wm),  10_000e6);

        assertEq(queueWM.totalShares(), 10_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4, shares: 4_000e6 });

        assertEq(queueWM.userEscrowedShares(lp1), 1_000e6);
        assertEq(queueWM.userEscrowedShares(lp2), 2_000e6);
        assertEq(queueWM.userEscrowedShares(lp3), 3_000e6);
        assertEq(queueWM.userEscrowedShares(lp4), 4_000e6);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        // Process requested ids, including a missing request.
        processRedemptionByIds(address(pool), array(1, 2, 3, 4, 5));

        // Post assertions.
        assertEq(fundsAsset.balanceOf(lp1),           1_000e6);
        assertEq(fundsAsset.balanceOf(lp2),           2_000e6);
        assertEq(fundsAsset.balanceOf(lp3),           3_000e6);
        assertEq(fundsAsset.balanceOf(lp4),           4_000e6);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 100_000e6);

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(lp3), 0);
        assertEq(pool.balanceOf(lp4), 0);
        assertEq(pool.balanceOf(wm),  0);

        assertEq(queueWM.totalShares(), 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);
        assertEq(queueWM.userEscrowedShares(lp4), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });
    }

    function test_processRedemptions_withImpairment_processInOrder() external {
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        // Need to fund a loan so the exchange rate isn't affected by funds in the pool
        address loan = createOpenTermLoan({
            borrower:  makeAddr("borrower"),
            lender:    poolManager.strategyList(0),
            asset:     address(fundsAsset),
            principal: 1_000e6,
            terms:     [gracePeriod, noticePeriod, paymentInterval],
            rates:     [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        });

        fundLoan(address(loan));

        // Request redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);

        // Impair loan
        impairLoan(address(loan));

        processRedemptionByIds(address(pool), array(1, 2, 3));

        // Post assertions.
        assertEq(fundsAsset.balanceOf(lp1),           900e6);
        assertEq(fundsAsset.balanceOf(lp2),           1_800e6);
        assertEq(fundsAsset.balanceOf(lp3),           2_700e6);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 3_600e6);

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(lp3), 0);
        assertEq(pool.balanceOf(wm),  0);

        assertEq(queueWM.totalShares(), 0);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });

        assertEq(queueWM.userEscrowedShares(lp1), 0);
        assertEq(queueWM.userEscrowedShares(lp2), 0);
        assertEq(queueWM.userEscrowedShares(lp3), 0);

        assertQueue({poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 3 });
    }

}
