// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract RemoveRequestTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_removeRequest_revert_zeroOwner() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("WM:RR:ZERO_OWNER");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeRequest(address(0), new uint256[](0));
    }

    function testFork_removeRequest_revert_zeroRequests() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("WM:RR:ZERO_REQUESTS");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeRequest(makeAddr("owner"), new uint256[](0));
    }

    function testFork_removeRequest_revert_notInQueue() external {
        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = lastRequestId + 1;

        vm.prank(operationalAdmin);
        vm.expectRevert("WM:RR:NOT_IN_QUEUE");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeRequest(makeAddr("owner"), requestIds);
    }

    function testFork_removeRequest_revert_notOwner() external {
        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = lastRequestId;

        vm.prank(operationalAdmin);
        vm.expectRevert("WM:RR:NOT_OWNER");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeRequest(makeAddr("owner"), requestIds);
    }

    function testFork_removeRequest_success_oneRequest() external {
        ( uint256 nextRequestId, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        uint256 ownerBalanceBefore = IERC20(syrupUSDCPool).balanceOf(owner);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = nextRequestId;

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).removeRequest(owner, requestIds);

        assertEq(IERC20(syrupUSDCPool).balanceOf(owner), ownerBalanceBefore + shares);

        ( owner, shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(owner, address(0));
        assertEq(shares, 0);
    }

}
