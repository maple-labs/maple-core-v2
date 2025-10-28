// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract RemoveSharesByIdTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_removeSharesById_revert_invalidRequest_requestAlreadyRemoved() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);

        assertEq(owner, address(0));
        assertEq(shares, 0);

        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId + 1, shares);
    }

    function testFork_removeSharesById_revert_notOwner() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        vm.expectRevert("WM:RSBI:NOT_OWNER");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares);
    }

    function testFork_removeSharesById_revert_noChange() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        vm.prank(owner);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, 0);
    }

    function testFork_removeSharesById_revert_insufficientShares() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        vm.prank(owner);
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares + 1);
    }

    function testFork_removeSharesById_success_partialRemoval() external {
        ( uint256 nextRequestId, uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(nextRequestId, 4564);  // NOTE: Hardcoded values from forked block
        assertEq(lastRequestId, 4566);  // NOTE: Hardcoded values from forked block

        ( address owner1, uint256 shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( address owner2, uint256 shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( address owner3, uint256 shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertEq(owner2, address(0));  // NOTE: Canceled request in setUp()

        assertNotEq(owner1, address(0));
        assertNotEq(owner3, address(0));

        assertEq(shares1, 1e6);
        assertEq(shares2, 0);
        assertEq(shares3, 4e6);

        uint256 sharesToRemove = 0.5e6;

        uint256 owner1BalanceBefore = IERC20(syrupUSDCPool).balanceOf(owner1);
        uint256 owner3BalanceBefore = IERC20(syrupUSDCPool).balanceOf(owner3);

        vm.prank(owner1);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, sharesToRemove);

        assertEq(IERC20(syrupUSDCPool).balanceOf(owner1), owner1BalanceBefore + sharesToRemove);

        ( address owner1After, uint256 shares1After ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(owner1After,  owner1);
        assertEq(shares1After, shares1 - sharesToRemove);

        vm.prank(owner3);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(lastRequestId, sharesToRemove);

        assertEq(IERC20(syrupUSDCPool).balanceOf(owner3), owner3BalanceBefore + sharesToRemove);

        ( address owner3After, uint256 shares3After ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);
        assertEq(owner3After,  owner3);
        assertEq(shares3After, shares3 - sharesToRemove);
    }

    function testFork_removeSharesById_success_completeRemoval() external {
        ( uint256 nextRequestId, )        = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        uint256 ownerBalanceBefore = IERC20(syrupUSDCPool).balanceOf(owner);

        vm.prank(owner);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeSharesById(nextRequestId, shares);

        assertEq(IERC20(syrupUSDCPool).balanceOf(owner), ownerBalanceBefore + shares);

        ( address ownerAfter, uint256 sharesAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        assertEq(ownerAfter,  address(0));
        assertEq(sharesAfter, 0);

        ( uint256 nextRequestIdAfter, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        assertEq(nextRequestIdAfter, nextRequestId);
    }

}
