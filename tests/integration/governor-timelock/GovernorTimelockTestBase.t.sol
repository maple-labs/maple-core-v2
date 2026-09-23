// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, IMG as IMapleGlobals, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

// TODO: Consider removing timelock wrappers and add/use timelock wrappers in ProtocolActions
contract GovernorTimelockTestBase is TestBaseWithAssertions {

    address public proposer = makeAddr("proposer");
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

        timelock =
            IGovernorTimelock(deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin)));

        vm.prank(governor);
        globals.setPendingGovernor(address(timelock));

        _executeThroughTimelock(address(globals), IMapleGlobals.acceptGovernor.selector, "");

        startTimestamp = block.timestamp;

        queueWM = IWithdrawalManagerQueue(poolManager.withdrawalManager());
    }

    function test_setUp() public view {
        assertEq(timelock.hasRole(proposer, timelock.PROPOSER_ROLE()),   true);
        assertEq(timelock.hasRole(executor, timelock.EXECUTOR_ROLE()),   true);
        assertEq(timelock.hasRole(canceller, timelock.CANCELLER_ROLE()), true);
        assertEq(timelock.hasRole(roleAdmin, timelock.ROLE_ADMIN()),     true);

        assertEq(timelock.tokenWithdrawer(), governor);

        assertEq(timelock.MIN_DELAY(),            1 days);
        assertEq(timelock.MIN_EXECUTION_WINDOW(), 1 days);

        (uint32 defaultDelay, uint32 defaultExecutionWindow) = timelock.defaultTimelockParameters();

        assertEq(defaultDelay,           timelock.MIN_DELAY());
        assertEq(defaultExecutionWindow, timelock.MIN_EXECUTION_WINDOW());

        assertEq(IMapleGlobals(globals).governor(), address(timelock));
    }

    function _scheduleProposal(
        address target,
        bytes4 functionSelector,
        bytes memory parameters
    )
        internal
        returns (uint256 proposalId, uint32 delayedUntil)
    {
        proposalId = scheduleProposal({
            timelock_: address(timelock),
            caller_:   proposer,
            target_:   target,
            callData_: bytes.concat(functionSelector, parameters)
        });

        (,,, delayedUntil,) = timelock.proposals(proposalId);
    }

    function _executeProposal(uint256 proposalId, address target, bytes4 functionSelector, bytes memory parameters) internal {
        executeProposal({
            timelock_:   address(timelock),
            caller_:     executor,
            proposalId_: proposalId,
            target_:     target,
            callData_:   bytes.concat(functionSelector, parameters)
        });
    }

    function _executeThroughTimelock(address target, bytes4 functionSelector, bytes memory parameters) internal {
        executeThroughTimelock({
            timelock_: address(timelock),
            proposer_: proposer,
            executor_: executor,
            target_:   target,
            callData_: bytes.concat(functionSelector, parameters)
        });
    }

    function _proposeRoleUpdate(bytes32 role_, address account_, bool shouldGrant_) internal {
        bytes32[] memory roles       = new bytes32[](1);
        address[] memory accounts    = new address[](1);
        bool[] memory    shouldGrant = new bool[](1);

        roles[0]       = role_;
        accounts[0]    = account_;
        shouldGrant[0] = shouldGrant_;

        vm.prank(roleAdmin);
        timelock.proposeRoleUpdates(roles, accounts, shouldGrant);
    }

    function _executeRoleUpdate(uint256 proposalId_, bytes32 role_, address account_, bool shouldGrant_) internal {
        (,,, uint32 delayedUntil_,) = timelock.proposals(proposalId_);

        vm.warp(delayedUntil_);
        _executeProposal({
            proposalId:       proposalId_,
            target:           address(timelock),
            functionSelector: timelock.updateRole.selector,
            parameters:       abi.encode(role_, account_, shouldGrant_)
        });
    }

}
