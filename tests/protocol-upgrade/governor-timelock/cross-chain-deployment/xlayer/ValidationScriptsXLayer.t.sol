// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Test } from "../../../../../contracts/Runner.sol";

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract TimelockValidationScriptXLayer is UpgradeAddressRegistry, Test {

    bytes32 cancellerRole = keccak256("CANCELLER_ROLE");
    bytes32 executorRole  = keccak256("EXECUTOR_ROLE");
    bytes32 proposerRole  = keccak256("PROPOSER_ROLE");
    bytes32 roleAdminRole = keccak256("ROLE_ADMIN");

    IGovernorTimelock tl = IGovernorTimelock(timelockXLayer);

    function _proposalHash(address target, bytes memory calldata_) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, calldata_));
    }

}

contract ValidateTimelockDeploymentXLayer is TimelockValidationScriptXLayer {

    function run() external view {
        assertEq(tl.CANCELLER_ROLE(), cancellerRole, "Invalid canceller role!");
        assertEq(tl.EXECUTOR_ROLE(),  executorRole,  "Invalid executor role!");
        assertEq(tl.PROPOSER_ROLE(),  proposerRole,  "Invalid proposer role!");
        assertEq(tl.ROLE_ADMIN(),     roleAdminRole, "Invalid role admin role!");

        assertEq(tl.MIN_DELAY(),            1 days, "Invalid minimum delay!");
        assertEq(tl.MIN_EXECUTION_WINDOW(), 1 days, "Invalid minimum window!");

        assertEq(tl.pendingTokenWithdrawer(), address(0),            "Pending token withdrawer is not the zero address!");
        assertEq(tl.tokenWithdrawer(),        tokenWithdrawerXLayer, "Governor is not the token withdrawer!");

        assertEq(tl.latestProposalId(), 0);

        (uint256 delay, uint256 window) = tl.defaultTimelockParameters();

        assertEq(delay,  1 days, "Invalid minimum delay!");
        assertEq(window, 1 days, "Invalid minimum window!");

        assertEq(tl.hasRole(proposerXLayer, proposerRole),   true, "Governor is not a proposer!");
        assertEq(tl.hasRole(executorXLayer, executorRole),   true, "Operational admin is not an executor!");
        assertEq(tl.hasRole(cancellerXLayer, cancellerRole), true, "Security admin is not a canceller!");
        assertEq(tl.hasRole(roleAdminXLayer, roleAdminRole), true, "Governor is not a role admin!");

        assertEq(tl.hasRole(backupExecutorXLayer, executorRole),   false, "Backup executor is already set!");
        assertEq(tl.hasRole(backupRoleAdminXLayer, roleAdminRole), false, "Backup role admin is already set!");
    }

}

contract ValidateConfigurationSchedulingXLayer is TimelockValidationScriptXLayer {

    bytes32 proposalHash_1 = _proposalHash(
        timelockXLayer, abi.encodeWithSignature("updateRole(bytes32,address,bool)", roleAdminRole, backupRoleAdminXLayer, true)
    );

    bytes32 proposalHash_2 = _proposalHash(
        timelockXLayer, abi.encodeWithSignature("updateRole(bytes32,address,bool)", executorRole, backupExecutorXLayer, true)
    );

    bytes32 proposalHash_3 =
        _proposalHash(timelockXLayer, abi.encodeWithSignature("setDefaultTimelockParameters(uint32,uint32)", 3 days, 2 days));

    // TODO: Replace with the timestamp of the proposal transaction.
    uint32 proposalTimestamp = uint32(0);

    function run() external view {
        (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) = tl.proposals(1);

        assertEq(proposalHash,    proposalHash_1,             "Invalid proposal hash! (id: 1)");
        assertEq(isUnschedulable, false,                      "Proposal is unschedulable! (id: 1)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 1)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 1)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 1)");

        (proposalHash, isUnschedulable, scheduledAt, delayedUntil, validUntil) = tl.proposals(2);

        assertEq(proposalHash,    proposalHash_2,             "Invalid proposal hash! (id: 2)");
        assertEq(isUnschedulable, false,                      "Proposal is unschedulable! (id: 2)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 2)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 2)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 2)");

        (proposalHash, isUnschedulable, scheduledAt, delayedUntil, validUntil) = tl.proposals(3);

        assertEq(proposalHash,    proposalHash_3,             "Invalid proposal hash! (id: 3)");
        assertEq(isUnschedulable, true,                       "Proposal is unschedulable! (id: 3)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 3)");
        assertEq(delayedUntil,    proposalTimestamp + 1 days, "Execution window starting date is invalid! (id: 3)");
        assertEq(validUntil,      proposalTimestamp + 2 days, "Execution window ending date is invalid! (id: 3)");

        assertEq(tl.latestProposalId(), 3, "Invalid latest proposal id!");
    }

}

contract ValidateConfigurationExecutionXLayer is TimelockValidationScriptXLayer {

    function run() external view {
        assertEq(tl.hasRole(backupExecutorXLayer, executorRole),   true, "Backup executor is not configured!");
        assertEq(tl.hasRole(backupRoleAdminXLayer, roleAdminRole), true, "Backup role admin is not configured!");

        (uint256 delay, uint256 window) = tl.defaultTimelockParameters();

        assertEq(delay,  3 days, "Invalid minimum delay!");
        assertEq(window, 2 days, "Invalid minimum window!");
    }

}
