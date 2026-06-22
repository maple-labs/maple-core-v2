// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, IMG as IMapleGlobals, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract GovernorTimelockTestBase is TestBaseWithAssertions {

    address public proposer  = makeAddr("proposer");
    address public executor;
    address public canceller;
    address public roleAdmin;

    uint256 public startTimestamp;

    IGovernorTimelock public timelock;

    function setUp() public virtual override {
        super.setUp();

        _initTimelock();
    }

    function _initTimelock() internal {
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = governor;

        timelock = IGovernorTimelock(
            deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin))
        );

        vm.prank(governor);
        globals.setPendingGovernor(address(timelock));

        _executeThroughTimelock(address(globals), IMapleGlobals.acceptGovernor.selector, "");

        startTimestamp = block.timestamp;

        queueWM = IWithdrawalManagerQueue(poolManager.withdrawalManager());
    }

    function test_setUp() public view {
        assertEq(timelock.hasRole(proposer,  timelock.PROPOSER_ROLE()),  true);
        assertEq(timelock.hasRole(executor,  timelock.EXECUTOR_ROLE()),  true);
        assertEq(timelock.hasRole(canceller, timelock.CANCELLER_ROLE()), true);
        assertEq(timelock.hasRole(roleAdmin, timelock.ROLE_ADMIN()),     true);

        assertEq(timelock.tokenWithdrawer(), governor);

        assertEq(timelock.MIN_DELAY(),            1 days);
        assertEq(timelock.MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = timelock.defaultTimelockParameters();

        assertEq(defaultDelay,           timelock.MIN_DELAY());
        assertEq(defaultExecutionWindow, timelock.MIN_EXECUTION_WINDOW());

        assertEq(IMapleGlobals(globals).governor(), address(timelock));
    }

    function _scheduleProposal(
        address      target,
        bytes4       functionSelector,
        bytes memory parameters
    )
        internal returns (uint256 proposalId, uint32 delayedUntil)
    {
        address[] memory targets = new address[](1);
        bytes[] memory data      = new bytes[](1);

        targets[0] = target;
        data[0]    = bytes.concat(functionSelector, parameters);

        vm.prank(proposer);
        timelock.scheduleProposals(targets, data);

        proposalId              = timelock.latestProposalId();
        ( , , , delayedUntil, ) = timelock.proposals(proposalId);
    }

    function _executeProposal(
        uint256      proposalId,
        address      target,
        bytes4       functionSelector,
        bytes memory parameters
    )
        internal
    {
        uint256[] memory proposalsToExecute = new uint256[](1);
        address[] memory targets            = new address[](1);
        bytes[] memory data                 = new bytes[](1);

        proposalsToExecute[0] = proposalId;
        targets[0]            = target;
        data[0]               = bytes.concat(functionSelector, parameters);

        vm.prank(executor);
        timelock.executeProposals(proposalsToExecute, targets, data);
    }

    function _executeThroughTimelock(
        address target,
        bytes4 functionSelector,
        bytes memory parameters
    )
        internal
    {
        ( uint256 proposalId, uint32 delayedUntil ) = _scheduleProposal(target, functionSelector, parameters);

        vm.warp(delayedUntil);
        _executeProposal(proposalId, target, functionSelector, parameters);
    }

    function _proposeRoleUpdate(bytes32 role_, address account_, bool shouldGrant_) internal {
        bytes32[] memory roles       = new bytes32[](1);
        address[] memory accounts    = new address[](1);
        bool[]    memory shouldGrant = new bool[](1);

        roles[0]       = role_;
        accounts[0]    = account_;
        shouldGrant[0] = shouldGrant_;

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);
    }

    function _executeRoleUpdate(uint256 proposalId_, bytes32 role_, address account_, bool shouldGrant_) internal {
        ( , , , uint32 delayedUntil_, ) = timelock.proposals(proposalId_);

        vm.warp(delayedUntil_);
        _executeProposal(
            proposalId_, address(timelock), timelock.updateRole.selector, abi.encode(role_, account_, shouldGrant_)
        );
    }

}
