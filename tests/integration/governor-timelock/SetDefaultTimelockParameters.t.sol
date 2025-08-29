// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract SetDefaultTimelockParametersTests is GovernorTimelockTestBase {

    function test_setDefaultTimelockParameters_revert_notSelf() public {
        vm.expectRevert("GT:NOT_SELF");
        timelock.setDefaultTimelockParameters(1, 1);
    }

    function test_setDefaultTimelockParameters_revert_invalidDelay() public {
        uint32 minDelay           = timelock.MIN_DELAY();
        uint32 minExecutionWindow = timelock.MIN_EXECUTION_WINDOW();

        bytes4 functionToExecute = timelock.setDefaultTimelockParameters.selector;
        bytes memory parameters  = abi.encode(minDelay - 1, minExecutionWindow);

        ( uint256 proposalId, uint32 delayedUntil ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        vm.warp(delayedUntil);

        vm.expectRevert("GT:EP:FAILED");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);
    }

    function test_setDefaultTimelockParameters_revert_invalidExecutionWindow() public {
        uint32 minDelay           = timelock.MIN_DELAY();
        uint32 minExecutionWindow = timelock.MIN_EXECUTION_WINDOW();

        bytes4 functionToExecute = timelock.setDefaultTimelockParameters.selector;
        bytes memory parameters  = abi.encode(minDelay, minExecutionWindow - 1);

        ( uint256 proposalId, uint32 delayedUntil ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        vm.warp(delayedUntil);

        vm.expectRevert("GT:EP:FAILED");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);
    }

    function test_setDefaultTimelockParameters_success() public {
        ( uint32 currentDelay, uint32 currentExecutionWindow ) = timelock.defaultTimelockParameters();

        uint32 newDelay           = currentDelay + 1 days;
        uint32 newExecutionWindow = currentExecutionWindow + 1 days;

        bytes4 functionToExecute = timelock.setDefaultTimelockParameters.selector;
        bytes memory parameters  = abi.encode(newDelay, newExecutionWindow);

        _executeThroughTimelock(address(timelock), functionToExecute, parameters);

        ( currentDelay, currentExecutionWindow ) = timelock.defaultTimelockParameters();

        assertEq(currentDelay,           newDelay);
        assertEq(currentExecutionWindow, newExecutionWindow);

        ( uint256 proposalId, ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        (
            ,
            ,
            uint32 scheduledAt,
            uint32 delayedUntil,
            uint32 validUntil
        ) = timelock.proposals(proposalId);

        uint32 currentTimestamp = uint32(block.timestamp);
        assertEq(scheduledAt,  currentTimestamp);
        assertEq(delayedUntil, currentTimestamp + newDelay);
        assertEq(validUntil,   currentTimestamp + newDelay + newExecutionWindow);
    }

}
