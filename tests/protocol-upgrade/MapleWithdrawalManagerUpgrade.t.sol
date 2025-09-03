// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IWithdrawalManagerQueue } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.t.sol";

// TODO: Update to include all active pools
contract MapleWithdrawalManagerUpgradeTest is ProtocolUpgradeBase, ProtocolActions {

    address constant accountA                = 0x83900304646c01cc60007e7AEea35DbD4Eda5425;
    address constant accountB                = 0x1d6073c4C9AE246572acA12A2b270788887929eB;
    address constant cancelledRequestAccount = 0xa52090c48e88Afeac9aF137f6FB50c62f1A5a575;

    uint256 constant AccountARequestAmount  = 1e6;
    uint256 constant AccountBRequestAmount  = 4e6;
    uint256 constant CancelledRequestAmount = 9e6;

    function setUp() public {
        // Block 23211261 has no pending redemption requests.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23211261);

        ( uint256 nextRequestIdBefore, uint256 lastRequestIdBefore ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        requestRedeem(syrupUSDCPool, accountA, AccountARequestAmount);

        uint256 sharesToCancel = requestRedeem(syrupUSDCPool, cancelledRequestAccount, CancelledRequestAmount);

        removeShares(syrupUSDCPool, cancelledRequestAccount, sharesToCancel);

        requestRedeem(syrupUSDCPool, accountB, AccountBRequestAmount);

        ( uint256 nextRequestIdAfter, uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(nextRequestIdAfter, nextRequestIdBefore);
        assertEq(lastRequestIdAfter, lastRequestIdBefore + 3);  // Note: +3 as 3 new requests were created during setUp()

        upgradeProtocol();
    }

    function testFork_syrupUSDC_withdrawalManager_migrate_success() external {
        ( uint256 nextRequestId, uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).userEscrowedShares(accountA),                1e6);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).userEscrowedShares(accountB),                4e6);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).userEscrowedShares(cancelledRequestAccount), 0);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requestIds(accountA),                nextRequestId);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requestIds(cancelledRequestAccount), 0);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requestIds(accountB),                nextRequestId + 2);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requestIds(accountB),                lastRequestId);
    }

}
