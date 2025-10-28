// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../../../modules/forge-std/src/console2.sol";

import { IERC20, IPool, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract RemoveSharesTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_removeShares_revert_zeroShares() external {
        vm.expectRevert("WM:RS:ZERO_SHARES");
        IPool(syrupUSDCPool).removeShares(0, address(0));
    }

    function testFork_removeShares_partialRemoval_oneRequest() external {
        ( uint256 nextRequestId, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        uint256 sharesToRemove      = 0.4e6;
        uint256 sharesBalanceBefore = IERC20(syrupUSDCPool).balanceOf(owner);

        removeShares(syrupUSDCPool, owner, sharesToRemove);

        assertEq(IERC20(syrupUSDCPool).balanceOf(owner), sharesBalanceBefore + sharesToRemove);

        ( address ownerAfter, uint256 sharesAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(ownerAfter,  owner);
        assertEq(sharesAfter, shares - sharesToRemove);

        ( uint256 nextRequestIdAfter, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        assertEq(nextRequestIdAfter, nextRequestId);
    }

    function testFork_removeShares_partialRemoval_multipleRequests() external {
        address user             = makeAddr("user");
        uint256 depositAmount    = 3e6;
        uint256 sharesToRequest1 = 1e6;
        uint256 sharesToRequest2 = 0.4e6;
        uint256 sharesToRemove   = 1.1e6;

        deposit(syrupUSDCPool, user, depositAmount);

        requestRedeem(syrupUSDCPool, user, sharesToRequest1);
        requestRedeem(syrupUSDCPool, user, sharesToRequest2);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId - 1);

        assertEq(owner,  user);
        assertEq(shares, sharesToRequest1);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);

        assertEq(owner,  user);
        assertEq(shares, sharesToRequest2);

        removeShares(syrupUSDCPool, user, sharesToRemove);

        uint256 expectedSharesLeftRequest1 = 0.3e6;
        uint256 expectedSharesLeftRequest2 = 0;

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId - 1);

        assertEq(owner,  user);
        assertEq(shares, expectedSharesLeftRequest1);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);

        assertEq(owner,  address(0));
        assertEq(shares, expectedSharesLeftRequest2);
    }

    function testFork_removeShares_completeRemoval_multipleRequests() external {
        address user = makeAddr("user");

        uint256 depositAmount    = 3e6;
        uint256 sharesToRequest1 = 1e6;
        uint256 sharesToRequest2 = 0.4e6;

        deposit(syrupUSDCPool, user, depositAmount);

        requestRedeem(syrupUSDCPool, user, sharesToRequest1);
        requestRedeem(syrupUSDCPool, user, sharesToRequest2);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId - 1);

        assertEq(owner,  user);
        assertEq(shares, sharesToRequest1);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);

        assertEq(owner,  user);
        assertEq(shares, sharesToRequest2);

        removeShares(syrupUSDCPool, user, sharesToRequest1 + sharesToRequest2);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId - 1);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( , uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        assertEq(lastRequestIdAfter, lastRequestId);
    }

}
