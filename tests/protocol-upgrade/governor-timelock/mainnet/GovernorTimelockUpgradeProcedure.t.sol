// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, IMG as IMapleGlobals } from "../../../../contracts/interfaces/Interfaces.sol";

import { GovernorTimelockUpgradeTestsBase } from "./GovernorTimelockUpgradeTestsBase.t.sol";

contract GovernorTimelockUpgradeProcedureTests is GovernorTimelockUpgradeTestsBase {

    bool isUnschedulable;

    bytes32 proposalHash;

    uint256 delayedUntil;
    uint256 scheduledAt;
    uint256 start;
    uint256 validUntil;

    function testFork_governorTimelock_fullUpgradeProcedure() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23428891);

        backupRoleAdmin = makeAddr("backupRoleAdmin");
        backupExecutor  = makeAddr("backupExecutor");

        start = block.timestamp;

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy Timelock & Assert Constructor Setup                                                                         ***/
        /**********************************************************************************************************************************/

        // Deploy GovernorTimelock
        proposer  = daoMultisig;
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = daoMultisig;
        timelock  = deployFromFile("Contracts@25", "Timelock", abi.encode(daoMultisig, proposer, executor, canceller, roleAdmin));

        // Assert Roles
        assertEq(IGovernorTimelock(timelock).hasRole(proposer,         IGovernorTimelock(timelock).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelock).hasRole(operationalAdmin, IGovernorTimelock(timelock).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelock).hasRole(securityAdmin,    IGovernorTimelock(timelock).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelock).hasRole(daoMultisig,      IGovernorTimelock(timelock).ROLE_ADMIN()),     true);

        // Assert token withdrawer role
        assertEq(IGovernorTimelock(timelock).tokenWithdrawer(), daoMultisig);

        // Assert Default Timelock
        assertEq(IGovernorTimelock(timelock).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelock).MIN_EXECUTION_WINDOW(), 1 days);

        // Assert Default Timelock Parameters Set
        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelock).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelock).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelock).MIN_EXECUTION_WINDOW());

        /**********************************************************************************************************************************/
        /*** Step 2: Schedule New configuration of roles and timelock                                                                   ***/
        /**********************************************************************************************************************************/

        // Setup backups for role admin and executor roles
        bytes32[] memory roles            = new bytes32[](2);
        address[] memory accounts         = new address[](2);
        bool[]    memory shouldGrantArray = new bool[](2);

        roles[0]            = IGovernorTimelock(timelock).ROLE_ADMIN();
        accounts[0]         = backupRoleAdmin;
        shouldGrantArray[0] = true;

        roles[1]            = IGovernorTimelock(timelock).EXECUTOR_ROLE();
        accounts[1]         = backupExecutor;
        shouldGrantArray[1] = true;

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).proposeRoleUpdates(roles, accounts, shouldGrantArray);

        uint256 proposalId = IGovernorTimelock(timelock).latestProposalId();

        (
            proposalHash,
            isUnschedulable ,
            scheduledAt ,
            delayedUntil,
            validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId - 1);

        // Assert Role Updates Proposed
        assertEq(proposalId - 1,  1);
        assertEq(delayedUntil,    block.timestamp + 1 days);
        assertEq(isUnschedulable, false);
        assertEq(scheduledAt,     block.timestamp);
        assertEq(validUntil,      block.timestamp + 1 days + 1 days);

        (
            proposalHash,
            isUnschedulable ,
            scheduledAt ,
            delayedUntil,
            validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        // Assert Role Updates Proposed
        assertEq(proposalId,      2);
        assertEq(delayedUntil,    block.timestamp + 1 days);
        assertEq(isUnschedulable, false);
        assertEq(scheduledAt,     block.timestamp);
        assertEq(validUntil,      block.timestamp + 1 days + 1 days);

        // Schedule changing of timelock params
        address[] memory targets = new address[](1);
        bytes[] memory data      = new bytes[](1);

        targets[0] = timelock;
        data[0]    = abi.encodeWithSelector(
            IGovernorTimelock(timelock).setDefaultTimelockParameters.selector,
            3 days,
            2 days
        );

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).scheduleProposals(targets, data);

        proposalId = IGovernorTimelock(timelock).latestProposalId();

        (
            proposalHash,
            isUnschedulable ,
            scheduledAt ,
            delayedUntil,
            validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        // Assert Timelock Params Change Proposed
        assertEq(proposalId,      3);
        assertEq(delayedUntil,    block.timestamp + 1 days);
        assertEq(isUnschedulable, true);
        assertEq(scheduledAt,     block.timestamp);
        assertEq(validUntil,      block.timestamp + 1 days + 1 days);

        /**********************************************************************************************************************************/
        /*** Step 3: Execute Role and Timelock Param proposals                                                                         ***/
        /**********************************************************************************************************************************/

        uint256[] memory proposalIdsToExecute = new uint256[](3);
        address[] memory targetsToExecute     = new address[](3);
        bytes[] memory dataToExecute          = new bytes[](3);

        proposalIdsToExecute[0] = 1;
        proposalIdsToExecute[1] = 2;
        proposalIdsToExecute[2] = 3;

        targetsToExecute[0] = timelock;
        targetsToExecute[1] = timelock;
        targetsToExecute[2] = timelock;

        dataToExecute[0] = abi.encodeWithSelector(
            IGovernorTimelock(timelock).updateRole.selector,
            IGovernorTimelock(timelock).ROLE_ADMIN(),
            backupRoleAdmin,
            true
        );

        dataToExecute[1] = abi.encodeWithSelector(
            IGovernorTimelock(timelock).updateRole.selector,
            IGovernorTimelock(timelock).EXECUTOR_ROLE(),
            backupExecutor,
            true
        );

        dataToExecute[2] = abi.encodeWithSelector(
            IGovernorTimelock(timelock).setDefaultTimelockParameters.selector,
            3 days,
            2 days
        );

        vm.warp(start + 1 days + 1 seconds);
        vm.prank(operationalAdmin);
        IGovernorTimelock(timelock).executeProposals(proposalIdsToExecute, targetsToExecute, dataToExecute);

        // Assert Role Updates Executed
        assertEq(IGovernorTimelock(timelock).hasRole(backupRoleAdmin, IGovernorTimelock(timelock).ROLE_ADMIN()),    true);
        assertEq(IGovernorTimelock(timelock).hasRole(backupExecutor,  IGovernorTimelock(timelock).EXECUTOR_ROLE()), true);

        // Assert Timelock Params Changed
        ( defaultDelay, defaultExecutionWindow ) = IGovernorTimelock(timelock).defaultTimelockParameters();
        assertEq(defaultDelay,           3 days);
        assertEq(defaultExecutionWindow, 2 days);

        /**********************************************************************************************************************************/
        /*** Step 4: Transfer Governorship                                                                                              ***/
        /**********************************************************************************************************************************/

        // Imitate natural passage of time
        vm.warp(start + 2 days);

        // Set pending governor on globals
        vm.startPrank(daoMultisig);
        IMapleGlobals(globals).setPendingGovernor(timelock);
        vm.stopPrank();

        // Assert Pending Governor Set on Globals
        assertEq(IMapleGlobals(globals).pendingGovernor(), timelock);

        // Schedule acceptance of governorship on Timelock
        targets[0] = globals;
        data[0]    = abi.encodeWithSelector(IMapleGlobals.acceptGovernor.selector);

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).scheduleProposals(targets, data);

        proposalId = IGovernorTimelock(timelock).latestProposalId();

        (
            proposalHash,
            isUnschedulable ,
            scheduledAt ,
            delayedUntil,
            validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        // Assert Accept Governorship Proposed
        assertEq(proposalId,      4);
        assertEq(delayedUntil,    block.timestamp + 3 days);
        assertEq(isUnschedulable, true);
        assertEq(scheduledAt,     block.timestamp);
        assertEq(validUntil,      block.timestamp + 3 days + 2 days);

        // Execute acceptance of governorship on Timelock
        proposalIdsToExecute = new uint256[](1);
        targetsToExecute     = new address[](1);
        dataToExecute        = new bytes[](1);

        proposalIdsToExecute[0] = proposalId;
        targetsToExecute[0]     = globals;
        dataToExecute[0]        = abi.encodeWithSelector(IMapleGlobals.acceptGovernor.selector);

        vm.warp(start + 6 days + 1 seconds);
        vm.prank(operationalAdmin);
        IGovernorTimelock(timelock).executeProposals(proposalIdsToExecute, targetsToExecute, dataToExecute);

        // Assert Governorship Transferred
        assertEq(IMapleGlobals(globals).pendingGovernor(), address(0));
        assertEq(IMapleGlobals(globals).governor(),        timelock);
    }

}
