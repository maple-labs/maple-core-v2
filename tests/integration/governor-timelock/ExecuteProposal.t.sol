// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MockContractWithFallback } from "../../mocks/Mocks.sol";

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract ExecuteProposalsTests is GovernorTimelockTestBase {

    function test_executeProposals_revert_notExecutor() public {
        vm.expectRevert("GT:NOT_AUTHORIZED");
        timelock.executeProposals(new uint256[](0), new address[](0), new bytes[](0));
    }

    function test_executeProposals_revert_emptyArray() public {
        vm.expectRevert("GT:EP:EMPTY_ARRAY");
        vm.prank(executor);
        timelock.executeProposals(new uint256[](0), new address[](0), new bytes[](0));
    }

    function test_executeProposals_revert_invalidTargetsLength() public {
        vm.expectRevert("GT:EP:INVALID_TARGETS_LENGTH");
        vm.prank(executor);
        timelock.executeProposals(new uint256[](1), new address[](2), new bytes[](0));
    }

    function test_executeProposals_revert_invalidDataLength() public {
        vm.expectRevert("GT:EP:INVALID_DATA_LENGTH");
        vm.prank(executor);
        timelock.executeProposals(new uint256[](1), new address[](1), new bytes[](2));
    }

    function test_executeProposals_revert_notExecutable() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(queueWM);

        bytes4 functionToCall1 = globals.setPendingGovernor.selector;
        bytes4 functionToCall2 = queueWM.setManualWithdrawal.selector;

        data[0] = abi.encodeWithSelector(functionToCall1, securityAdmin);
        data[1] = abi.encodeWithSelector(functionToCall2, securityAdmin, true);

        ( uint32 delay, uint32 executionWindow ) = timelock.defaultTimelockParameters();

        uint32 functionSpecificDelay           = 2 * delay;
        uint32 functionSpecificExecutionWindow = 2 * executionWindow;

        _executeThroughTimelock(
            address(timelock),
            timelock.setFunctionTimelockParameters.selector,
            abi.encode(targets[1], functionToCall2, functionSpecificDelay, functionSpecificExecutionWindow)
        );

        assertEq(timelock.latestProposalId(), 2);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        uint256 startingTimestamp = block.timestamp;
        vm.warp(startingTimestamp + delay);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0]               = 3;
        proposalIds[1]               = 4;

        assertEq(timelock.isExecutable(3), true);
        assertEq(timelock.isExecutable(4), false);

        vm.expectRevert("GT:EP:NOT_EXECUTABLE");
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        vm.warp(startingTimestamp + functionSpecificDelay + functionSpecificExecutionWindow + 1);

        vm.expectRevert("GT:EP:NOT_EXECUTABLE");
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(timelock.isExecutable(3), false);
        assertEq(timelock.isExecutable(4), false);
    }

    function test_executeProposals_revert_notExecutable_failedToExecuteTheSameProposalTwice() public {
        assertEq(timelock.latestProposalId(), 1);

        address[] memory targets = new address[](1);
        bytes[] memory data      = new bytes[](1);

        targets[0] = address(collateralAsset);
        data[0]    = abi.encodeWithSelector(collateralAsset.mint.selector, address(timelock), 100e18);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        assertNotEmptyProposal(address(timelock), 2);

        ( uint32 delay, ) = timelock.defaultTimelockParameters();

        vm.warp(startTimestamp + delay);

        uint256[] memory proposalIds = new uint256[](1);
        proposalIds[0]               = 2;

        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(collateralAsset.balanceOf(address(timelock)), 100e18);

        vm.expectRevert("GT:EP:NOT_EXECUTABLE");
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(collateralAsset.balanceOf(address(timelock)), 100e18);
    }

    function test_executeProposals_revert_invalidData() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(collateralAsset);

        bytes4 functionToCall1 = globals.setPendingGovernor.selector;
        bytes4 functionToCall2 = collateralAsset.transfer.selector;

        data[0] = abi.encodeWithSelector(functionToCall1, securityAdmin);
        data[1] = abi.encodeWithSelector(functionToCall2, governor, 100e18);

        ( uint32 delay, ) = timelock.defaultTimelockParameters();

        assertEq(timelock.latestProposalId(), 1);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        vm.warp(block.timestamp + delay);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0]               = 2;
        proposalIds[1]               = 3;

        data[1] = abi.encodeWithSelector(functionToCall2, executor, 100e18);

        vm.expectRevert("GT:EP:INVALID_DATA");
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(timelock.isExecutable(2), true);
        assertEq(timelock.isExecutable(3), true);
    }

    function test_executeProposals_executionFailed() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(queueWM);

        bytes4 functionToCall1 = globals.acceptGovernor.selector;
        bytes4 functionToCall2 = queueWM.setManualWithdrawal.selector;

        data[0] = abi.encodeWithSelector(functionToCall1);
        data[1] = abi.encodeWithSelector(functionToCall2, securityAdmin, true);

        assertEq(timelock.latestProposalId(), 1);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        ( uint32 delay, ) = timelock.defaultTimelockParameters();

        vm.warp(block.timestamp + delay);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0]               = 2;
        proposalIds[1]               = 3;

        vm.expectRevert("GT:EP:FAILED");
        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEq(timelock.isExecutable(2), true);
        assertEq(timelock.isExecutable(3), true);
    }

    function test_executeProposals_success_emptyData() public {
        assertEq(timelock.latestProposalId(), 1);

        uint256 nextProposalId = timelock.latestProposalId() + 1;

        MockContractWithFallback contractWithFallback = new MockContractWithFallback();

        _scheduleProposal(address(contractWithFallback), "", "");

        assertNotEmptyProposal(address(timelock), nextProposalId);

        uint256[] memory proposalIds = new uint256[](1);
        proposalIds[0]               = nextProposalId;

        ( uint32 delay, ) = timelock.defaultTimelockParameters();

        assertEq(contractWithFallback.counter(), 0);

        vm.warp(startTimestamp + delay);
        _executeProposal(nextProposalId, address(contractWithFallback), "", "");

        assertEq(contractWithFallback.counter(), 1);
    }

    function test_executeProposals_success() public {
        address[] memory targets = new address[](2);
        bytes[]   memory data    = new bytes[](2);

        targets[0] = address(globals);
        targets[1] = address(collateralAsset);

        bytes4 functionToCall1 = globals.setPendingGovernor.selector;
        bytes4 functionToCall2 = collateralAsset.mint.selector;

        data[0] = abi.encodeWithSelector(functionToCall1, securityAdmin);
        data[1] = abi.encodeWithSelector(functionToCall2, securityAdmin, 100e18);

        assertEq(timelock.latestProposalId(), 1);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        assertNotEmptyProposal(address(timelock), 2);
        assertNotEmptyProposal(address(timelock), 3);

        assertEq(timelock.latestProposalId(), 3);

        ( uint32 delay, ) = timelock.defaultTimelockParameters();

        vm.warp(block.timestamp + delay);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0]               = 2;
        proposalIds[1]               = 3;

        assertEq(timelock.isExecutable(2), true);
        assertEq(timelock.isExecutable(3), true);

        assertEq(globals.pendingGovernor(),                address(0));
        assertEq(collateralAsset.balanceOf(securityAdmin), 0);

        vm.prank(executor);
        timelock.executeProposals(proposalIds, targets, data);

        assertEmptyProposal(address(timelock), 2);
        assertEmptyProposal(address(timelock), 3);

        assertEq(timelock.latestProposalId(), 3);

        assertEq(timelock.isExecutable(2), false);
        assertEq(timelock.isExecutable(3), false);

        assertEq(globals.pendingGovernor(),                securityAdmin);
        assertEq(collateralAsset.balanceOf(securityAdmin), 100e18);
    }

}
