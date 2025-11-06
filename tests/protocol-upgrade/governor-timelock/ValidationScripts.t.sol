// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Test } from "../../../contracts/Runner.sol";

import {
    IGlobals,
    IGovernorTimelock
} from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract TimelockValidationScriptBase is UpgradeAddressRegistry, Test {

    bytes32 cancellerRole = keccak256("CANCELLER_ROLE");
    bytes32 executorRole  = keccak256("EXECUTOR_ROLE");
    bytes32 proposerRole  = keccak256("PROPOSER_ROLE");
    bytes32 roleAdminRole = keccak256("ROLE_ADMIN");

    IGovernorTimelock tl = IGovernorTimelock(timelock);

    function _proposalHash(address target, bytes memory calldata_) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, calldata_));
    }
}

contract ValidateTimelockDeployment is TimelockValidationScriptBase {

    function run() external {
        assertEq(tl.CANCELLER_ROLE(), cancellerRole, "Invalid canceller role!");
        assertEq(tl.EXECUTOR_ROLE(),  executorRole,  "Invalid executor role!");
        assertEq(tl.PROPOSER_ROLE(),  proposerRole,  "Invalid proposer role!");
        assertEq(tl.ROLE_ADMIN(),     roleAdminRole, "Invalid role admin role!");

        assertEq(tl.MIN_DELAY(),            1 days, "Invalid minimum delay!");
        assertEq(tl.MIN_EXECUTION_WINDOW(), 1 days, "Invalid minimum window!");

        assertEq(tl.pendingTokenWithdrawer(), address(0), "Pending token withdrawer is not the zero address!");
        assertEq(tl.tokenWithdrawer(),        governor,   "Governor is not the token withdrawer!");

        assertEq(tl.latestProposalId(), 0);

        ( uint256 delay, uint256 window ) = tl.defaultTimelockParameters();

        assertEq(delay,  1 days);
        assertEq(window, 1 days);

        assertEq(tl.hasRole(proposer,  proposerRole),  true, "Governor is not a proposer!");
        assertEq(tl.hasRole(executor,  executorRole),  true, "Operational admin is not an executor!");
        assertEq(tl.hasRole(canceller, cancellerRole), true, "Security admin is not a canceller!");
        assertEq(tl.hasRole(proposer,  roleAdminRole), true, "Governor is not a role admin!");

        assertEq(tl.hasRole(backupExecutor,  executorRole),  false, "Backup executor is already set!");
        assertEq(tl.hasRole(backupRoleAdmin, roleAdminRole), false, "Backup role admin is already set!");
    }

}

contract ValidateConfigurationScheduling is TimelockValidationScriptBase {

    bytes32 proposalHash_1 = _proposalHash(
        timelock,
        abi.encodeWithSignature("updateRole(bytes32,address,bool)", roleAdminRole, backupRoleAdmin, true)
    );

    bytes32 proposalHash_2 = _proposalHash(
        timelock,
        abi.encodeWithSignature("updateRole(bytes32,address,bool)", executorRole, backupExecutor, true)
    );

    bytes32 proposalHash_3 = _proposalHash(
        timelock,
        abi.encodeWithSignature("setDefaultTimelockParameters(uint32,uint32)", 3 days, 2 days)
    );

    // TODO: Replace with the timestamp of the proposal transaction.
    uint32 proposalTimestamp = uint32(0);

    function run() external {
        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = tl.proposals(1);

        assertEq(proposalHash,    proposalHash_1,             "Invalid proposal hash! (id: 1)");
        assertEq(isUnschedulable, false,                      "Proposal is unschedulable! (id: 1)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 1)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 1)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 1)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(2);

        assertEq(proposalHash,    proposalHash_2,             "Invalid proposal hash! (id: 2)");
        assertEq(isUnschedulable, false,                      "Proposal is unschedulable! (id: 2)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 2)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 2)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 2)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(3);

        assertEq(proposalHash,    proposalHash_3,             "Invalid proposal hash! (id: 3)");
        assertEq(isUnschedulable, true,                       "Proposal is unschedulable! (id: 3)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 3)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 3)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 3)");

        assertEq(tl.latestProposalId(), 3, "Invalid latest proposal id!");
    }

}

contract ValidateConfigurationExecution is TimelockValidationScriptBase {

    function run() external {
        assertEq(tl.hasRole(backupExecutor,  executorRole),  true, "Backup executor is not configured!");
        assertEq(tl.hasRole(backupRoleAdmin, roleAdminRole), true, "Backup role admin is not configured!");

        ( uint256 delay, uint256 window ) = tl.defaultTimelockParameters();

        assertEq(delay,  3 days);
        assertEq(window, 2 days);
    }

}

contract ValidateGovernorTransferScheduling is TimelockValidationScriptBase {

    bytes32 proposalHash_4 = _proposalHash(globals, abi.encodeWithSignature("acceptGovernor()"));

    // TODO: Replace with the timestamp of the proposal transaction.
    uint32 proposalTimestamp = uint32(0);

    function run() external {
        assertEq(IGlobals(globals).governor(),        address(governor), "Invalid governor!");
        assertEq(IGlobals(globals).pendingGovernor(), address(tl),       "Invalid pending governor!");

        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = tl.proposals(4);

        assertEq(proposalHash,    proposalHash_4,             "Invalid proposal hash! (id: 4)");
        assertEq(isUnschedulable, true,                       "Proposal is unschedulable! (id: 4)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 4)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 4)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 4)");

        assertEq(tl.latestProposalId(), 4, "Invalid latest proposal id!");
    }

}

contract ValidateGovernorTransferExecution is TimelockValidationScriptBase {

    function run() external {
        assertEq(IGlobals(globals).governor(),        address(tl), "Invalid governor!");
        assertEq(IGlobals(globals).pendingGovernor(), address(0),  "Invalid pending governor!");
    }

}
