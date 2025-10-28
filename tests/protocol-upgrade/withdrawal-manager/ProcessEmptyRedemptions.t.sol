// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract ProcessEmptyRedemptionsTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_processEmptyRedemptions_revert_notRedeemer() external {
        vm.expectRevert("WM:NOT_REDEEMER");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processEmptyRedemptions(1);
    }

    function testFork_processEmptyRedemptions_zeroRequests_reverts() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("WM:PER:ZERO_REQUESTS");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processEmptyRedemptions(0);
    }

    function testFork_processEmptyRedemptions_success_multipleRequests() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        vm.prank(owner);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processEmptyRedemptions(2);

        ( uint256 nextRequestIdAfter, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(nextRequestIdAfter, nextRequestId + 2);
    }

    function testFork_processEmptyRedemptions_success_multipleRequests_stopsAtNonEmpty() external {
        ( uint256 nextRequestId, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        vm.prank(owner);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processEmptyRedemptions(1000);

        ( uint256 nextRequestIdAfter, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        assertEq(nextRequestIdAfter, nextRequestId + 2);
    }

    function testFork_processEmptyRedemptions_success_removesEntireQueue() external {
        ( uint256 nextRequestId, uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner1, uint256 shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( address owner2, uint256 shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( address owner3, uint256 shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertNotEq(owner1, address(0));
        assertEq(shares1, 1e6);

        assertEq(owner2, address(0));
        assertEq(shares2, 0);

        assertNotEq(owner3, address(0));
        assertEq(shares3, 4e6);

        vm.prank(owner1);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares1);

        vm.prank(owner3);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(lastRequestId, shares3);

        ( owner1, shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( owner2, shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( owner3, shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));
        assertEq(owner3, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);
        assertEq(shares3, 0);

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processEmptyRedemptions(100);

        ( uint256 nextRequestIdAfter, uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(nextRequestIdAfter, lastRequestIdAfter + 1);
        assertEq(lastRequestIdAfter, lastRequestId);
    }

}
