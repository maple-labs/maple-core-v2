// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IPool, IWithdrawalManagerQueue } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.t.sol";

contract MapleWithdrawalManagerUpgradeTest is ProtocolUpgradeBase, ProtocolActions {

    address accountA                = makeAddr("accountA");
    address accountB                = makeAddr("accountB");
    address cancelledRequestAccount = makeAddr("cancelledRequestAccount");

    uint256 accountARequestAmount        = 2e6;
    uint256 accountBRequestAmount        = 4e6;
    uint256 cancelledRequestAmount       = 9e6;
    uint256 accountAPartialProcessAmount = 1e6;

    mapping(address => QueueState) internal queueStateBefore;

    struct QueueState {
        uint256 nextRequestId;
        uint256 lastRequestId;
        uint256 accountARequestId;
        uint256 accountBRequestId;
    }

    function setUp() public {
        // Block 23211261 has no pending redemption requests.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23211261);

        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            address wm      = withdrawalManagerQueuesToUpgrade[i];
            address pool    = IWithdrawalManagerQueue(wm).pool();
            uint256 version = IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(IWithdrawalManagerQueue(wm).implementation());

            assertEq(version, 100);

            queueStateBefore[wm] = _seedQueueRequests(pool, wm);
        }

        upgradeProtocol();
    }

    function _seedQueueRequests(address pool_, address wmQueue_) internal returns (QueueState memory queueState) {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(wmQueue_);
        address poolManager        = wm.poolManager();
        uint256 totalSharesLocked  = wm.totalShares();

        openPool(poolManager);
        setLiquidityCap(poolManager, type(uint256).max);

        // Clear Queue before seeding
        if (totalSharesLocked > 0) {
            // mint pool underlying to pool to cover share processing
            uint256 assetAmount = IPool(pool_).convertToExitAssets(totalSharesLocked);
            address asset       = IPool(pool_).asset();

            erc20_mint(asset, pool_, assetAmount);

            processRedemptions(pool_, totalSharesLocked);
        }

        mint(pool_, accountA,                accountARequestAmount);
        mint(pool_, cancelledRequestAccount, cancelledRequestAmount);
        mint(pool_, accountB,                accountBRequestAmount);

        ( uint256 nextRequestIdBefore, uint256 lastRequestIdBefore ) = wm.queue();

        requestRedeem(pool_, accountA, accountARequestAmount);

        uint256 sharesToCancel = requestRedeem(pool_, cancelledRequestAccount, cancelledRequestAmount);

        removeShares(pool_, cancelledRequestAccount, sharesToCancel);

        requestRedeem(pool_, accountB, accountBRequestAmount);

        ( queueState.nextRequestId, queueState.lastRequestId ) = wm.queue();

        queueState.accountARequestId = wm.requestIds(accountA);
        queueState.accountBRequestId = wm.requestIds(accountB);

        assertEq(queueState.nextRequestId, nextRequestIdBefore);
        assertEq(queueState.lastRequestId, lastRequestIdBefore + 3);  // Note: +3 as 3 new requests were created during seeding.

        processRedemptions(pool_, accountAPartialProcessAmount);
    }

    function testFork_withdrawalManagers_migrate_success() external {
        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            address wmAddress                         = withdrawalManagerQueuesToUpgrade[i];
            IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(wmAddress);

            assertEq(
                IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(withdrawalManager.implementation()),
                200
            );

            ( uint256 nextRequestIdAfter, uint256 lastRequestIdAfter ) = withdrawalManager.queue();

            assertEq(nextRequestIdAfter, queueStateBefore[wmAddress].nextRequestId);
            assertEq(lastRequestIdAfter, queueStateBefore[wmAddress].lastRequestId);

            assertEq(withdrawalManager.userEscrowedShares(accountA),                accountARequestAmount - accountAPartialProcessAmount);
            assertEq(withdrawalManager.userEscrowedShares(accountB),                accountBRequestAmount);
            assertEq(withdrawalManager.userEscrowedShares(cancelledRequestAccount), 0);

            assertEq(withdrawalManager.requestIds(accountA),                queueStateBefore[wmAddress].accountARequestId);
            assertEq(withdrawalManager.requestIds(cancelledRequestAccount), 0);
            assertEq(withdrawalManager.requestIds(accountB),                queueStateBefore[wmAddress].accountBRequestId);
            assertEq(withdrawalManager.requestIds(accountB),                queueStateBefore[wmAddress].lastRequestId);

            uint256[] memory ids;
            uint256[] memory shares;

            ( ids, shares ) = withdrawalManager.requestsByOwner(accountA);

            assertEq(ids.length,    1);
            assertEq(shares.length, 1);
            assertEq(ids[0],        queueStateBefore[wmAddress].accountARequestId);
            assertEq(shares[0],     accountARequestAmount - accountAPartialProcessAmount);

            ( ids, shares ) = withdrawalManager.requestsByOwner(accountB);

            assertEq(ids.length,    1);
            assertEq(shares.length, 1);
            assertEq(ids[0],        queueStateBefore[wmAddress].accountBRequestId);
            assertEq(shares[0],     accountBRequestAmount);

            ( ids, shares ) = withdrawalManager.requestsByOwner(cancelledRequestAccount);

            assertEq(ids.length,    0);
            assertEq(shares.length, 0);
        }
    }

}
