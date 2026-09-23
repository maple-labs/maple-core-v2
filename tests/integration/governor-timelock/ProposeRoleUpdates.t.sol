// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../modules/globals/contracts/interfaces/IGovernorTimelock.sol";

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract ProposeRoleUpdatesTests is GovernorTimelockTestBase {

    function test_proposeRoleUpdates_revert_notRoleAdmin() public {
        vm.expectRevert("GT:NOT_AUTHORIZED");
        timelock.proposeRoleUpdates(new bytes32[](0), new address[](0), new bool[](0));
    }

    function test_proposeRoleUpdates_revert_emptyArray() public {
        vm.expectRevert("GT:PRU:EMPTY_ARRAY");
        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(new bytes32[](0), new address[](0), new bool[](0));
    }

    function test_proposeRoleUpdates_revert_invalidAccountsLength() public {
        vm.expectRevert("GT:PRU:INVALID_ACCOUNTS_LENGTH");
        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(new bytes32[](1), new address[](2), new bool[](0));
    }

    function test_proposeRoleUpdates_revert_invalidShouldGrantLength() public {
        vm.expectRevert("GT:PRU:INVALID_SHOULD_GRANT_LENGTH");
        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(new bytes32[](1), new address[](1), new bool[](2));
    }

    function test_proposeRoleUpdates_success() public {
        assertEq(timelock.latestProposalId(), 1);

        bytes32[] memory roles       = new bytes32[](2);
        address[] memory accounts    = new address[](2);
        bool[] memory    shouldGrant = new bool[](2);

        roles[0] = timelock.PROPOSER_ROLE();
        roles[1] = timelock.EXECUTOR_ROLE();

        address newProposer = makeAddr("newProposer");
        accounts[0]         = newProposer;
        accounts[1]         = executor;

        shouldGrant[0] = true;
        shouldGrant[1] = false;

        assertEq(timelock.hasRole(newProposer, timelock.PROPOSER_ROLE()), false);
        assertEq(timelock.hasRole(executor, timelock.EXECUTOR_ROLE()),    true);

        assertEmptyProposal(address(timelock), 2);
        assertEmptyProposal(address(timelock), 3);

        (uint32 delay, uint32 executionWindow) = timelock.defaultTimelockParameters();

        bytes32 expectedProposalHash1 = keccak256(
            abi.encode(address(timelock), abi.encodeWithSelector(timelock.updateRole.selector, roles[0], accounts[0], shouldGrant[0]))
        );
        bytes32 expectedProposalHash2 = keccak256(
            abi.encode(address(timelock), abi.encodeWithSelector(timelock.updateRole.selector, roles[1], accounts[1], shouldGrant[1]))
        );

        uint32 currentTimestamp           = uint32(block.timestamp);
        uint32 expectedScheduledTimestamp = currentTimestamp;
        uint32 expectedDelayedUntil       = currentTimestamp + delay;
        uint32 expectedValidUntil         = currentTimestamp + delay + executionWindow;

        IGovernorTimelock.Proposal memory expectedProposal1 = IGovernorTimelock.Proposal({
            proposalHash:    expectedProposalHash1,
            isUnschedulable: false,
            scheduledAt:     expectedScheduledTimestamp,
            delayedUntil:    expectedDelayedUntil,
            validUntil:      expectedValidUntil
        });

        IGovernorTimelock.Proposal memory expectedProposal2 = IGovernorTimelock.Proposal({
            proposalHash:    expectedProposalHash2,
            isUnschedulable: false,
            scheduledAt:     expectedScheduledTimestamp,
            delayedUntil:    expectedDelayedUntil,
            validUntil:      expectedValidUntil
        });

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);

        assertProposal(address(timelock), 2, expectedProposal1);
        assertProposal(address(timelock), 3, expectedProposal2);

        assertEq(timelock.latestProposalId(), 3);
    }

}
