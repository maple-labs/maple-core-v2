// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract UpdateRoleTests is GovernorTimelockTestBase {

    function test_updateRole_revert_notSelf() public {
        vm.expectRevert("GT:NOT_SELF");
        timelock.updateRole(bytes32(0), makeAddr("account"), true);
    }

    function test_updateRole_success_revokeRole() public {
        bytes32[] memory roles       = new bytes32[](1);
        address[] memory accounts    = new address[](1);
        bool[] memory    shouldGrant = new bool[](1);

        roles[0]       = timelock.PROPOSER_ROLE();
        accounts[0]    = proposer;
        shouldGrant[0] = false;

        assertEq(timelock.latestProposalId(),             1);
        assertEq(timelock.hasRole(accounts[0], roles[0]), true);

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);

        (,,, uint32 delayedUntil,) = timelock.proposals(2);

        uint256[] memory proposalIds = new uint256[](1);
        address[] memory targets     = new address[](1);
        bytes[] memory   data        = new bytes[](1);

        proposalIds[0] = 2;
        targets[0]     = address(timelock);
        data[0]        = abi.encodeWithSelector(timelock.updateRole.selector, roles[0], accounts[0], shouldGrant[0]);

        vm.warp(delayedUntil);
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(timelock.hasRole(accounts[0], roles[0]), false);
    }

    function test_updateRole_success_grantRole() public {
        bytes32[] memory roles       = new bytes32[](1);
        address[] memory accounts    = new address[](1);
        bool[] memory    shouldGrant = new bool[](1);

        roles[0]       = timelock.PROPOSER_ROLE();
        accounts[0]    = securityAdmin;
        shouldGrant[0] = true;

        assertEq(timelock.latestProposalId(),             1);
        assertEq(timelock.hasRole(accounts[0], roles[0]), false);

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);

        (,,, uint32 delayedUntil,) = timelock.proposals(2);

        uint256[] memory proposalIds = new uint256[](1);
        address[] memory targets     = new address[](1);
        bytes[] memory   datas       = new bytes[](1);

        proposalIds[0] = 2;
        targets[0]     = address(timelock);
        datas[0]       = abi.encodeWithSelector(timelock.updateRole.selector, roles[0], accounts[0], shouldGrant[0]);

        vm.warp(delayedUntil);
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, datas);

        assertEq(timelock.hasRole(accounts[0], roles[0]), true);
    }

}
