// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract SetFunctionTimelockParametersTests is GovernorTimelockTestBase {

    function test_setFunctionTimelockParameters_revert_notSelf() public {
        address target          = address(globals);
        bytes4 functionSelector = globals.setMinCoverAmount.selector;

        vm.expectRevert("GT:NOT_SELF");
        timelock.setFunctionTimelockParameters(target, functionSelector, 1, 1);
    }

    function test_setFunctionTimelockParameters_revert_invalidDelay() public {
        uint32 minDelay           = timelock.MIN_DELAY();
        uint32 minExecutionWindow = timelock.MIN_EXECUTION_WINDOW();

        address target          = address(globals);
        bytes4 functionSelector = globals.setMinCoverAmount.selector;

        bytes4 functionToExecute = timelock.setFunctionTimelockParameters.selector;
        bytes memory parameters  = abi.encode(target, functionSelector, minDelay - 1, minExecutionWindow);

        ( uint256 proposalId, uint32 delayedUntil ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        vm.warp(delayedUntil);
        vm.expectRevert("GT:EP:FAILED");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);
    }

    function test_setFunctionTimelockParameters_revert_invalidExecutionWindow() public {
        uint32 minDelay           = timelock.MIN_DELAY();
        uint32 minExecutionWindow = timelock.MIN_EXECUTION_WINDOW();

        address target          = address(globals);
        bytes4 functionSelector = globals.setMinCoverAmount.selector;

        bytes4 functionToExecute = timelock.setFunctionTimelockParameters.selector;
        bytes memory parameters  = abi.encode(target, functionSelector, minDelay, minExecutionWindow - 1);

        ( uint256 proposalId, uint32 delayedUntil ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        vm.warp(delayedUntil);
        vm.expectRevert("GT:EP:FAILED");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);
    }

    function test_setFunctionTimelockParameters_success_timelockOfUnderlyingFunctionIsRespected() public {
        assertEq(timelock.latestProposalId(), 1);

        address targetToSetTimelockFor  = address(globals);
        bytes4 functionToSetTimelockFor = globals.setMinCoverAmount.selector;

        ( uint32 currentFunctionDelay, uint32 currentFunctionExecutionWindow ) =
            timelock.functionTimelockParameters(targetToSetTimelockFor, functionToSetTimelockFor);

        assertEq(currentFunctionDelay,           0);
        assertEq(currentFunctionExecutionWindow, 0);

        uint32 newFunctionDelay           = 3 days;
        uint32 newFunctionExecutionWindow = 4 days;

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = timelock.defaultTimelockParameters();

        assertNotEq(defaultDelay,           newFunctionDelay);
        assertNotEq(defaultExecutionWindow, newFunctionExecutionWindow);

        assertEq(defaultDelay,           timelock.MIN_DELAY());
        assertEq(defaultExecutionWindow, timelock.MIN_EXECUTION_WINDOW());

        bytes4 functionToExecute = timelock.setFunctionTimelockParameters.selector;
        bytes memory parameters  =
            abi.encode(targetToSetTimelockFor, functionToSetTimelockFor, newFunctionDelay, newFunctionExecutionWindow);

        _scheduleProposal(address(timelock), functionToExecute, parameters);

        (
            ,
            ,
            uint32 scheduledAt,
            uint32 delayedUntil,
            uint32 validUntil
        ) = timelock.proposals(2);

        uint32 currentTimestamp = uint32(block.timestamp);

        assertEq(scheduledAt,  currentTimestamp);
        assertEq(delayedUntil, currentTimestamp + defaultDelay);
        assertEq(validUntil,   currentTimestamp + defaultDelay + defaultExecutionWindow);

        vm.warp(delayedUntil);
        _executeProposal(2, address(timelock), functionToExecute, parameters);

        ( currentFunctionDelay, currentFunctionExecutionWindow ) =
            timelock.functionTimelockParameters(targetToSetTimelockFor, functionToSetTimelockFor);

        assertEq(currentFunctionDelay,           newFunctionDelay);
        assertEq(currentFunctionExecutionWindow, newFunctionExecutionWindow);

        _scheduleProposal(address(timelock), functionToExecute, parameters);

        ( , , scheduledAt, delayedUntil, validUntil ) = timelock.proposals(3);

        currentTimestamp = uint32(block.timestamp);
        assertEq(scheduledAt,  currentTimestamp);
        assertEq(delayedUntil, currentTimestamp + newFunctionDelay);
        assertEq(validUntil,   currentTimestamp + newFunctionDelay + newFunctionExecutionWindow);
    }

}
