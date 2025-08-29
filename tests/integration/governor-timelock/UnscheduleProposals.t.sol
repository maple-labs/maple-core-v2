// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract UnscheduleProposalsTests is GovernorTimelockTestBase {

    function test_unscheduleProposals_revert_notCanceller() public {
        vm.expectRevert("GT:NOT_AUTHORIZED");
        timelock.unscheduleProposals(new uint256[](0));
    }

    function test_unscheduleProposals_revert_proposalNotFound() public {
        vm.prank(canceller);
        vm.expectRevert("GT:UP:PROPOSAL_NOT_FOUND");
        timelock.unscheduleProposals(new uint256[](1));
    }

    function test_unscheduleProposals_revert_notUnschedulable() public {
        assertEq(timelock.latestProposalId(), 1);

        bytes32[] memory roles       = new bytes32[](1);
        address[] memory accounts    = new address[](1);
        bool[]    memory shouldGrant = new bool[](1);

        roles[0]       = timelock.PROPOSER_ROLE();
        accounts[0]    = securityAdmin;
        shouldGrant[0] = true;

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);

        assertNotEmptyProposal(address(timelock), 2);

        uint256[] memory proposalIds = new uint256[](1);
        proposalIds[0]               = 2;

        vm.expectRevert("GT:UP:NOT_UNSCHEDULABLE");
        vm.prank(canceller);
        timelock.unscheduleProposals(proposalIds);
    }

    function test_unscheduleProposals_success() public {
        assertEq(timelock.latestProposalId(), 1);

        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(collateralAsset);

        bytes4 functionToCall1 = globals.setPendingGovernor.selector;
        bytes4 functionToCall2 = collateralAsset.mint.selector;

        data[0] = abi.encodeWithSelector(functionToCall1, securityAdmin);
        data[1] = abi.encodeWithSelector(functionToCall2, securityAdmin, 100e18);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        assertNotEmptyProposal(address(timelock), 2);
        assertNotEmptyProposal(address(timelock), 3);

        assertEq(timelock.latestProposalId(), 3);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = 3;
        proposalIds[1] = 2;

        vm.prank(canceller);
        timelock.unscheduleProposals(proposalIds);

        assertEmptyProposal(address(timelock), 3);
        assertEmptyProposal(address(timelock), 2);

        assertEq(timelock.latestProposalId(), 3);
    }

}
