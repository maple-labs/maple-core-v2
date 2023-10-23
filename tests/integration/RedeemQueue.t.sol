// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IMapleProxyFactory,
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike
} from "../../contracts/interfaces/Interfaces.sol";

import { PoolManagerWMMigrator, PoolManager, WithdrawalManagerQueue } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

// TODO: Refactor to deploy pool with new WM via PoolDeployer in TestBase, we don't need _setUpQueueWM
contract QueueRedeemBase is TestBase {

    function setUp() public override virtual {
        super.setUp();

        _setUpQueueWM();
    }

    // TODO: refactor to make stateless and add to TestBaseWithAssertions
    function assertRequest(uint128 requestId, address owner, uint256 shares) internal {
        ( address owner_, uint256 shares_ ) = queueWM.requests(requestId);

        assertEq(owner_,  owner);
        assertEq(shares_, shares);
    }

    // TODO: refactor to make stateless and add to TestBaseWithAssertions
    function assertQueue(uint128 nextRequestId, uint128 lastRequestId) internal {
        ( uint128 nextRequestId_, uint128 lastRequestId_ ) = queueWM.queue();

        assertEq(nextRequestId_, nextRequestId);
        assertEq(lastRequestId_, lastRequestId);
    }

    // TODO: Remove in favour of using PoolDeployer in TestBase
    function _setUpQueueWM() internal {
        address deployer = makeAddr("deployer");

        vm.prank(governor);
        globals.setCanDeployFrom(address(queueWMFactory), deployer, true);

        vm.prank(deployer);
        queueWM = WithdrawalManagerQueue(
            IMapleProxyFactory(queueWMFactory).createInstance(abi.encode(address(pool)), "SALT")
        );

        address migrator          = address(new PoolManagerWMMigrator());
        address newImplementation = address(new PoolManager());

        vm.startPrank(governor);
        IMapleProxyFactory(poolManagerFactory).registerImplementation(2, newImplementation, address(queueWMInitializer));
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(1, 2, migrator);

        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", address(queueWM),     true);
        globals.setValidInstanceOf("QUEUE_POOL_MANAGER",               address(poolManager), true);
        vm.stopPrank();

        vm.prank(governor);
        poolManager.upgrade(2, abi.encode(address(queueWM)));

        allowLender(address(poolManager), address(queueWM));
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
        assertRequest({ requestId: 1, owner: lp1, shares: 2_000e6 });
        assertRequest({ requestId: 2, owner: lp2, shares: 2_000e6 });

        assertQueue({ nextRequestId: 1, lastRequestId: 2 });

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

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        // Lp2 does manual redemption
        redeem(address(pool), address(lp2), 2_000e6);

        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

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
        assertRequest({ requestId: 1, owner: lp1, shares: 2_000e6 });
        assertRequest({ requestId: 2, owner: lp2, shares: 2_000e6 });

        assertQueue({ nextRequestId: 1, lastRequestId: 2 });

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

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: lp2, shares: 1_000e6 });

        assertQueue({ nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 1_000e6);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6);

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });

        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(wm),  2_000e6);
        assertEq(pool.totalSupply(),  2_000e6);

        assertEq(queueWM.manualSharesAvailable(lp2), 2_000e6);

        redeem(address(pool), address(lp2), 2_000e6);

        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

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
