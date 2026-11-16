// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract SetPendingTokenWithdrawerTests is GovernorTimelockTestBase {

    function test_setPendingTokenWithdrawer_revert_notTokenWithdrawer() public {
        vm.expectRevert("GT:NOT_AUTHORIZED");
        timelock.setPendingTokenWithdrawer(makeAddr("pendingTokenWithdrawer"));
    }

    function test_setPendingTokenWithdrawer_success() public {
        address pendingTokenWithdrawer = makeAddr("pendingTokenWithdrawer");

        assertNotEq(timelock.pendingTokenWithdrawer(), pendingTokenWithdrawer);

        assertEq(timelock.pendingTokenWithdrawer(), address(0));
        assertEq(timelock.tokenWithdrawer(),        governor);

        vm.prank(roleAdmin);
        timelock.setPendingTokenWithdrawer(pendingTokenWithdrawer);

        assertEq(timelock.pendingTokenWithdrawer(), pendingTokenWithdrawer);
        assertEq(timelock.tokenWithdrawer(),        governor);
    }

}
