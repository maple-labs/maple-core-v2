// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract ProcessRedemptionsTests is TestBaseWithAssertions {

    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");
    address lp3 = makeAddr("lp3");
    address lp4 = makeAddr("lp4");
    address lp5 = makeAddr("lp5");

    address wm;  // Helper to avoid casting

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
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

    function test_processRedemptions_zeroShares() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:ZERO_SHARES");
        queueWM.processRedemptions(0);
    }

    function test_processRedemptions_lowLiquidity() external {
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        // Need to fund a loan so the exchange rate isn't affected by funds in the pool
        address loan = createOpenTermLoan(
            address(makeAddr("borrower")),
            address(poolManager.loanManagerList(1)),
            address(fundsAsset),
            10_000e6,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        );

        fundLoan(address(loan));

        // Request redemptions
        requestRedeem(lp1, 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        queueWM.processRedemptions(1_000e6);
    }

    function test_processRedemptions_multipleLps() external {
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
        vm.prank(poolDelegate);
        queueWM.processRedemptions(10_000e6);

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

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

    function test_processRedemptions_differentExchangeRate() external {
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

        // Process 1st and partially 2nd requests.
        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2,        shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3,        shares: 3_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4,        shares: 4_000e6 });

        assertQueue({poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    8_000e6);
        assertEq(queueWM.totalShares(), 8_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);  // 1_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp2),           1_100e6);  // 1_000e6 * 1.1
        assertEq(fundsAsset.balanceOf(lp3),           0);
        assertEq(fundsAsset.balanceOf(lp4),           0);
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 8_800e6);  // 10_000e6 - 2_2000e6

        // Exchange rate = 8_000e6 shares for 8_800e6 + 880e6  assets = 9_680e6 / 8_000e6 = 1.21
        fundsAsset.mint(address(pool), 880e6);

        // Process 2nd, 3rd and partially 4th requests.
        vm.prank(poolDelegate);
        queueWM.processRedemptions(6_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: lp4,        shares: 2_000e6 });

        assertQueue({poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    2_000e6);
        assertEq(queueWM.totalShares(), 2_000e6);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);
        assertEq(fundsAsset.balanceOf(lp2),           2_310e6);  // 1_100e6 (previous redemption) + (1_000e6 * 1.21 = 1_210e6)
        assertEq(fundsAsset.balanceOf(lp3),           3_630e6);  // 3_000e6 * 1.21
        assertEq(fundsAsset.balanceOf(lp4),           2_420e6);  // 2_000e6 * 1.21
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 2_420e6);  // 8_800e6 + 880e6 - 6_000e6(sum of requests)

        // Exchange rate = 2_000e6 shares for 2_420e6 +  880e6 assets = 3_300e6 / 2_000e6 = 1.65
        fundsAsset.mint(address(pool), 880e6);

        // Process 4th requests.
        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });

        assertEq(pool.balanceOf(lp1),   0);
        assertEq(pool.balanceOf(lp2),   0);
        assertEq(pool.balanceOf(lp3),   0);
        assertEq(pool.balanceOf(lp4),   0);
        assertEq(pool.balanceOf(wm),    0);
        assertEq(queueWM.totalShares(), 0);

        assertEq(fundsAsset.balanceOf(lp1),           1_100e6);
        assertEq(fundsAsset.balanceOf(lp2),           2_310e6);
        assertEq(fundsAsset.balanceOf(lp3),           3_630e6);
        assertEq(fundsAsset.balanceOf(lp4),           5_720e6);  // 2_420e6 + (2_000e6 * 1.65)
        assertEq(fundsAsset.balanceOf(wm),            0);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);
    }

    function test_processRedemptions_manualWithDifferentExchangeRates() external {
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
        vm.prank(poolDelegate);
        queueWM.processRedemptions(10_000e6);

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

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

    function test_processRedemptions_multipleManualBatched() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);

        // Manual user will request and be serviced many times over before redeeming
        for (uint256 i = 0; i < 5; i++) {
            deposit(lp2, 2_000e6);
            requestRedeem(lp2, 2_000e6);

            assertRequest({ poolManager: address(poolManager), requestId: uint128(i + 1), owner: lp2, shares: 2_000e6});

            vm.prank(poolDelegate);
            queueWM.processRedemptions(2_000e6);

            assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6 * (i + 1));
        }

        // Finally redeem all
        redeem(lp2, 10_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }

    function test_processRedemptions_withCancelledRequest() external {
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

        // LP3 cancels their request
        removeShares(address(pool), lp3, 3_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(wm),    7_000e6);
        assertEq(queueWM.totalShares(), 7_000e6);

        // Process full liquidity
        vm.prank(poolDelegate);
        queueWM.processRedemptions(7_000e6);

        // Post-assertions
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 4, owner: address(0), shares: 0 });

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

    function test_processRedemptions_overkill() external {
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

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 4 });

        // Process more than the total shares.
        vm.prank(poolDelegate);
        queueWM.processRedemptions(10_000e6 + 1_500e6);

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

        assertQueue({poolManager: address(poolManager), nextRequestId: 5, lastRequestId: 4 });
    }

     function test_processRedemptions_withImpairment() external {
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        // Need to fund a loan so the exchange rate isn't affected by funds in the pool
        address loan = createOpenTermLoan(
            address(makeAddr("borrower")),
            address(poolManager.loanManagerList(1)),
            address(fundsAsset),
            1_000e6,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        );

        fundLoan(address(loan));

        // Request redemptions
        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);

        // Impair loan
        impairLoan(address(loan));

        vm.prank(poolDelegate);
        queueWM.processRedemptions(6_000e6);

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

        assertQueue({poolManager: address(poolManager), nextRequestId: 4, lastRequestId: 3 });
    }

}
