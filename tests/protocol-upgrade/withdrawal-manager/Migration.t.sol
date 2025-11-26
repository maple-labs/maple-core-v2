// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract MigrateTest is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_withdrawalManagers_migrate_success() external view {
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
