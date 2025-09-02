// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../modules/globals/contracts/interfaces/IGovernorTimelock.sol";

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract ScheduleProposalsTests is GovernorTimelockTestBase {

    function test_scheduleProposals_revert_notProposer() public {
        vm.expectRevert("GT:NOT_AUTHORIZED");
        timelock.scheduleProposals(new address[](0), new bytes[](0));
    }

    function test_scheduleProposals_revert_emptyArray() public {
        vm.expectRevert("GT:SP:EMPTY_ARRAY");
        vm.prank(proposer);
        timelock.scheduleProposals(new address[](0), new bytes[](0));
    }

    function test_scheduleProposals_revert_arrayLengthMismatch() public {
        vm.expectRevert("GT:SP:ARRAY_LENGTH_MISMATCH");
        vm.prank(proposer);
        timelock.scheduleProposals(new address[](1), new bytes[](2));
    }

    function test_scheduleProposals_revert_updateRoleNotAllowed() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(timelock);

        data[0] = abi.encodeWithSelector(globals.setPendingGovernor.selector, securityAdmin);
        data[1] = abi.encodeWithSelector(timelock.updateRole.selector, timelock.PROPOSER_ROLE(), proposer, false);

        vm.expectRevert("GT:SP:UPDATE_ROLE_NOT_ALLOWED");
        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);
    }

    function test_scheduleProposals_revert_emptyTarget() public {
        address[] memory targets = new address[](1);
        bytes[]   memory data    = new bytes[](1);

        targets[0] = address(1337);
        data[0]    = abi.encodeWithSignature("randomFunction(bytes)", "randomParameters");

        vm.expectRevert("GT:SP:EMPTY_ADDRESS");
        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);
    }

    function test_scheduleProposals_success_respectsDefaultTimelockAndFunctionSpecific() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(queueWM);

        bytes4 functionToCall1 = globals.setPendingGovernor.selector;
        bytes4 functionToCall2 = queueWM.setManualWithdrawal.selector;

        data[0] = abi.encodeWithSelector(functionToCall1, securityAdmin);
        data[1] = abi.encodeWithSelector(functionToCall2, securityAdmin, true);

        uint32 secondFunctionDelay           = 2 days;
        uint32 secondFunctionExecutionWindow = 2 days;

        ( uint32 delay, uint32 executionWindow ) = timelock.defaultTimelockParameters();

        assertEq(delay,           1 days);
        assertEq(executionWindow, 1 days);

        _executeThroughTimelock(
            address(timelock),
            timelock.setFunctionTimelockParameters.selector,
            abi.encode(address(queueWM), functionToCall2, secondFunctionDelay, secondFunctionExecutionWindow)
        );

        ( uint32 currentSecondFunctionDelay, uint32 currentSecondFunctionExecutionWindow ) =
            timelock.functionTimelockParameters(address(queueWM), functionToCall2);

        assertEq(currentSecondFunctionDelay,           secondFunctionDelay);
        assertEq(currentSecondFunctionExecutionWindow, secondFunctionExecutionWindow);

        uint32 currentTimestamp = uint32(block.timestamp);

        IGovernorTimelock.Proposal memory expectedProposal1 = IGovernorTimelock.Proposal({
            proposalHash:    keccak256(abi.encode(targets[0], data[0])),
            isUnschedulable: true,
            scheduledAt:     currentTimestamp,
            delayedUntil:    currentTimestamp + delay,
            validUntil:      currentTimestamp + delay + executionWindow
        });

        IGovernorTimelock.Proposal memory expectedProposal2 = IGovernorTimelock.Proposal({
            proposalHash:    keccak256(abi.encode(targets[1], data[1])),
            isUnschedulable: true,
            scheduledAt:     currentTimestamp,
            delayedUntil:    currentTimestamp + secondFunctionDelay,
            validUntil:      currentTimestamp + secondFunctionDelay + secondFunctionExecutionWindow
        });

        assertEq(timelock.latestProposalId(),  2);
        assertEmptyProposal(address(timelock), 3);
        assertEmptyProposal(address(timelock), 4);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        assertProposal(address(timelock), 3, expectedProposal1);
        assertProposal(address(timelock), 4, expectedProposal2);

        assertEq(timelock.latestProposalId(), 4);
    }

}
