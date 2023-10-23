// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IMapleProxyFactory,
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike
} from "../../contracts/interfaces/Interfaces.sol";

import { PoolManagerWMMigrator, PoolManager, WithdrawalManagerQueue } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract QueueRedeemBase is TestBaseWithAssertions {

    function setUp() public override virtual {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
    }

}

contract ManualRedeemTests is QueueRedeemBase {

    address borrower = makeAddr("borrower");
    address lp1      = makeAddr("lp1");
    address lp2      = makeAddr("lp2");
    address lp3      = makeAddr("lp3");
    address wm;

    function setUp() public override {
        super.setUp();

        wm = address(queueWM);

        deposit(lp1, 2_000e6);
        deposit(lp2, 2_000e6);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp2, true);
    }

    function test_manualRedeem_noShares() external {
        vm.expectRevert("WM:PE:NO_SHARES");
        redeem(address(pool), address(lp2), 0);
    }

    function test_manualRedeem_tooManyShares() external {
        requestRedeem(address(pool), lp2, 2_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_000e6);

        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        redeem(address(pool), address(lp2), 2_000e6 + 1);

        redeem(address(pool), address(lp2), 2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }

    function test_manualRedeem_fullLiquidity() external {
        assertEq(pool.balanceOf(lp1), 2_000e6);
        assertEq(pool.balanceOf(lp2), 2_000e6);
        assertEq(pool.balanceOf(wm), 0);
        assertEq(pool.totalSupply(), 4_000e6);

        // Both LP's request withdrawals
        requestRedeem(address(pool), lp1, 2_000e6);
        requestRedeem(address(pool), lp2, 2_000e6);

        // Assert WM State
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm), 4_000e6);
        assertEq(pool.totalSupply(), 4_000e6);

        // LP2 tries to withdraw
        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        redeem(address(pool), address(lp2), 2_000e6);

        // Pool Delegate's process redemptions
        vm.prank(poolDelegate);
        queueWM.processRedemptions(4_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        // Lp2 does manual redemption
        redeem(address(pool), address(lp2), 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  0);
        assertEq(pool.totalSupply(),  0);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }
    function test_manualRedeem_partialLiquidity() external {
        assertEq(pool.balanceOf(lp1), 2_000e6);
        assertEq(pool.balanceOf(lp2), 2_000e6);
        assertEq(pool.balanceOf(wm), 0);
        assertEq(pool.totalSupply(), 4_000e6);

        // Both LP's request withdrawals
        requestRedeem(address(pool), lp1, 2_000e6);
        requestRedeem(address(pool), lp2, 2_000e6);

        // Assert WM State
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp1, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm), 4_000e6);
        assertEq(pool.totalSupply(), 4_000e6);

        // LP2 tries to withdraw
        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        redeem(address(pool), address(lp2), 2_000e6);

        // Pool Delegate's process redemptions
        vm.prank(poolDelegate);
        queueWM.processRedemptions(3_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 1_000e6 });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6);

        assertQueue({ poolManager: address(poolManager), nextRequestId: 3, lastRequestId: 2 });

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        redeem(address(pool), address(lp2), 2_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  0);
        assertEq(pool.totalSupply(),  0);

        assertEq(queueWM.manualSharesAvailable(lp2), 0);
    }

    function test_manualRedeem_insufficientLiquidity() external {
        requestRedeem(address(pool), lp2, 2_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_000e6);

        // Fund a loan with all the cash on the pool
        uint32 gracePeriod     = 200_000;
        uint32 noticePeriod    = 100_000;
        uint32 paymentInterval = 1_000_000;
        uint64 interestRate    = 0.31536e6;

        // Need to fund a loan so the exchange rate isn't affected by funds in the pool
        address loan = createOpenTermLoan(
            address(makeAddr("borrower")),
            address(poolManager.loanManagerList(1)),
            address(fundsAsset),
            4_000e6,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        );

        fundLoan(address(loan));

        vm.expectRevert("WM:PE:NOT_ENOUGH_LIQUIDITY");
        redeem(lp2, 2_000e6);
    }

}
