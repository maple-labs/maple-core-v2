// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract AcceptTokenWithdrawerTests is GovernorTimelockTestBase {

    function test_acceptTokenWithdrawer_revert_notAuthorized() public {
        vm.expectRevert("GT:ATW:NOT_AUTHORIZED");
        timelock.acceptTokenWithdrawer();
    }

    function test_acceptTokenWithdrawer_success() public {
        address pendingTokenWithdrawer = makeAddr("pendingTokenWithdrawer");

        assertNotEq(timelock.tokenWithdrawer(), pendingTokenWithdrawer);

        assertEq(timelock.pendingTokenWithdrawer(), address(0));

        vm.prank(governor);
        timelock.setPendingTokenWithdrawer(pendingTokenWithdrawer);

        assertEq(timelock.pendingTokenWithdrawer(), pendingTokenWithdrawer);

        vm.prank(pendingTokenWithdrawer);
        timelock.acceptTokenWithdrawer();

        assertEq(timelock.tokenWithdrawer(),        pendingTokenWithdrawer);
        assertEq(timelock.pendingTokenWithdrawer(), address(0));
    }

}
