// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, IMG as IMapleGlobals } from "../../../../contracts/interfaces/Interfaces.sol";
import { Runner }                                  from "../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBase is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23428891);

        deployGovernorTimelock();

        vm.startPrank(governor);
        IMapleGlobals(globals).setPendingGovernor(timelock);
        vm.stopPrank();

        _executeThroughTimelock(globals, IMapleGlobals.acceptGovernor.selector, "");
    }

    function deployGovernorTimelock() internal {
        proposer  = makeAddr("proposer");
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = governor;
        timelock  = deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin));
    }


    function testFork_setUp_governorTimelockUpgradeTests() public {
        assertEq(IGovernorTimelock(timelock).hasRole(proposer,         IGovernorTimelock(timelock).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelock).hasRole(operationalAdmin, IGovernorTimelock(timelock).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelock).hasRole(securityAdmin,    IGovernorTimelock(timelock).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelock).hasRole(governor,         IGovernorTimelock(timelock).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelock).tokenWithdrawer(), governor);

        assertEq(IGovernorTimelock(timelock).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelock).MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelock).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelock).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelock).MIN_EXECUTION_WINDOW());

        assertEq(IMapleGlobals(globals).pendingGovernor(), address(0));
        assertEq(IMapleGlobals(globals).governor(),        timelock);
    }

    function _setGovernorOnOldGlobals() internal {
        vm.startPrank(governor);
        IMapleGlobals(oldGlobalsOnTreasury).setPendingGovernor(timelock);
        vm.stopPrank();

        _executeThroughTimelock(oldGlobalsOnTreasury, IMapleGlobals.acceptGovernor.selector, "");

        assertEq(IMapleGlobals(oldGlobalsOnTreasury).pendingGovernor(), address(0));
        assertEq(IMapleGlobals(oldGlobalsOnTreasury).governor(),        timelock);
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
        IGovernorTimelock(timelock).scheduleProposals(targets, data);

        proposalId              = IGovernorTimelock(timelock).latestProposalId();
        ( , , , delayedUntil, ) = IGovernorTimelock(timelock).proposals(proposalId);
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
        IGovernorTimelock(timelock).executeProposals(proposalsToExecute, targets, data);
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

    function _proposeRoleUpdate(address caller, bytes32 role, address account, bool shouldGrant) internal {
        bytes32[] memory roles            = new bytes32[](1);
        address[] memory accounts         = new address[](1);
        bool[]    memory shouldGrantArray = new bool[](1);

        roles[0]            = role;
        accounts[0]         = account;
        shouldGrantArray[0] = shouldGrant;

        vm.prank(caller);
        IGovernorTimelock(timelock).proposeRoleUpdates(roles, accounts, shouldGrantArray);
    }

    function _executeRoleUpdate(uint256 proposalId, bytes32 role, address account, bool shouldGrant) internal {
        ( , , , uint32 delayedUntil, ) = IGovernorTimelock(timelock).proposals(proposalId);

        vm.warp(delayedUntil);
        _executeProposal(
            proposalId,
            timelock,
            IGovernorTimelock(timelock).updateRole.selector,
            abi.encode(role, account, shouldGrant)
        );
    }

    function _assertEmptyProposal(uint256 proposalId) internal {
        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        assertEq(proposalHash,    bytes32(0));
        assertEq(isUnschedulable, false);
        assertEq(scheduledAt,     0);
        assertEq(delayedUntil,    0);
        assertEq(validUntil,      0);
    }

}
