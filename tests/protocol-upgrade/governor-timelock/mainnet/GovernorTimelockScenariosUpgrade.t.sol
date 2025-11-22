// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IGovernorTimelock,
    IGlobals,
    IMapleProxyFactory,
    IMapleTreasuryLike,
    IMWMQ as IMapleWithdrawalManager
} from "../../../../contracts/interfaces/Interfaces.sol";

import { MockMapleWithdrawalManager } from "../../../mocks/Mocks.sol";

import { GovernorTimelockUpgradeTestsBase } from "./GovernorTimelockUpgradeTestsBase.t.sol";

contract GovernorTimelockScenariosUpgradeTests is GovernorTimelockUpgradeTestsBase {

    function testFork_reclaimERC20_withoutChangingGovernorOnOldGlobals() public {
        uint256 amountToReclaim = 100e6;

        uint256 treasuryBalanceBefore = IERC20(usdc).balanceOf(address(treasury));
        uint256 governorBalanceBefore = IERC20(usdc).balanceOf(governor);

        vm.prank(governor);
        IMapleTreasuryLike(treasury).reclaimERC20(usdc, amountToReclaim);

        assertEq(IERC20(usdc).balanceOf(address(treasury)), treasuryBalanceBefore - amountToReclaim);
        assertEq(IERC20(usdc).balanceOf(address(governor)), governorBalanceBefore + amountToReclaim);
    }

    function testFork_withdrawERC20Token_afterChangingTokenWithdrawer_withNewGovernorOnOldGlobals() public {
        _setGovernorOnOldGlobals();

        address newTokenWithdrawer = makeAddr("newTokenWithdrawer");
        uint256 amountToWithdraw   = 100e6;
        uint256 amountToPull       = 200e6;

        uint256 treasuryBalanceBefore = IERC20(usdc).balanceOf(address(treasury));

        _executeThroughTimelock(treasury, IMapleTreasuryLike.reclaimERC20.selector, abi.encode(usdc, amountToPull));

        uint256 timelockBalanceBefore = IERC20(usdc).balanceOf(address(timelock));
        uint256 governorBalanceBefore = IERC20(usdc).balanceOf(governor);

        vm.startPrank(governor);
        IGovernorTimelock(timelock).setPendingTokenWithdrawer(newTokenWithdrawer);
        IGovernorTimelock(timelock).withdrawERC20Token(usdc, amountToWithdraw);
        vm.stopPrank();

        assertEq(IERC20(usdc).balanceOf(governor),          governorBalanceBefore + amountToWithdraw);
        assertEq(IERC20(usdc).balanceOf(address(timelock)), timelockBalanceBefore - amountToWithdraw);
        assertEq(IERC20(usdc).balanceOf(address(treasury)), treasuryBalanceBefore - amountToPull);

        vm.prank(newTokenWithdrawer);
        vm.expectRevert("GT:WET:NOT_AUTHORIZED");
        IGovernorTimelock(timelock).withdrawERC20Token(usdc, amountToWithdraw);

        vm.prank(newTokenWithdrawer);
        IGovernorTimelock(timelock).acceptTokenWithdrawer();

        vm.prank(governor);
        vm.expectRevert("GT:WET:NOT_AUTHORIZED");
        IGovernorTimelock(timelock).withdrawERC20Token(usdc, amountToWithdraw);

        vm.prank(newTokenWithdrawer);
        IGovernorTimelock(timelock).withdrawERC20Token(usdc, amountToWithdraw);

        assertEq(IERC20(usdc).balanceOf(newTokenWithdrawer), amountToWithdraw);
        assertEq(IERC20(usdc).balanceOf(address(timelock)),  0);
    }

    function testFork_updateRoles_backupRoleAdmin_removesPrimaryRoleAdmin() public {
        uint256 latestProposalId    = IGovernorTimelock(timelock).latestProposalId();
        uint256 expectedProposalId1 = latestProposalId + 1;
        uint256 expectedProposalId2 = latestProposalId + 2;

        address roleAdmin2 = makeAddr("roleAdmin2");

        _proposeRoleUpdate(roleAdmin, IGovernorTimelock(timelock).ROLE_ADMIN(), roleAdmin2, true);
        _executeRoleUpdate(expectedProposalId1, IGovernorTimelock(timelock).ROLE_ADMIN(), roleAdmin2, true);

        assertEq(IGovernorTimelock(timelock).hasRole(roleAdmin2, IGovernorTimelock(timelock).ROLE_ADMIN()), true);

        _proposeRoleUpdate(roleAdmin2, IGovernorTimelock(timelock).ROLE_ADMIN(), roleAdmin, false);
        _executeRoleUpdate(expectedProposalId2, IGovernorTimelock(timelock).ROLE_ADMIN(), roleAdmin, false);

        assertEq(IGovernorTimelock(timelock).hasRole(roleAdmin,  IGovernorTimelock(timelock).ROLE_ADMIN()), false);
        assertEq(IGovernorTimelock(timelock).hasRole(roleAdmin2, IGovernorTimelock(timelock).ROLE_ADMIN()), true);
    }

    function testFork_unscheduleProposals_cancellerCanNotUnscheduleRoleUpdate() public {
        uint256 latestProposalId   = IGovernorTimelock(timelock).latestProposalId();
        uint256 expectedProposalId = latestProposalId + 1;

        _proposeRoleUpdate(roleAdmin, IGovernorTimelock(timelock).CANCELLER_ROLE(), canceller, false);

        uint256[] memory proposalsToCancel = new uint256[](1);
        proposalsToCancel[0]               = expectedProposalId;

        vm.prank(canceller);
        vm.expectRevert("GT:UP:NOT_UNSCHEDULABLE");
        IGovernorTimelock(timelock).unscheduleProposals(proposalsToCancel);
    }

    function testFork_unscheduleProposals_cancellerUnschedulesMaliciousProposal() public {
        uint256 timelockBalance = IERC20(usdc).balanceOf(address(timelock));

        bytes4 functionToExecute = IERC20.transfer.selector;
        bytes memory parameters  = abi.encode(makeAddr("malicious"), timelockBalance);

        ( uint256 proposalId, ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        uint256[] memory proposalsToCancel = new uint256[](1);
        proposalsToCancel[0]               = proposalId;

        vm.prank(canceller);
        IGovernorTimelock(timelock).unscheduleProposals(proposalsToCancel);

        _assertEmptyProposal(proposalId);

        vm.expectRevert("GT:EP:PROPOSAL_NOT_FOUND");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);

        assertEq(IERC20(usdc).balanceOf(address(timelock)), timelockBalance);
    }

    function testFork_upgradeWithdrawalManager() public {
        uint256 latestProposalId    = IGovernorTimelock(timelock).latestProposalId();
        uint256 expectedProposalId1 = latestProposalId + 1;
        uint256 expectedProposalId2 = latestProposalId + 2;

        address newPoolManager     = makeAddr("newPoolManager");
        address currentPoolManager = IMapleWithdrawalManager(syrupUSDCWithdrawalManagerQueue).poolManager();

        assertEq(currentPoolManager, syrupUSDCPoolManager);
        assertNotEq(currentPoolManager, newPoolManager);

        address newImplementation = address(new MockMapleWithdrawalManager(newPoolManager));
        uint256 version           = 200;
        uint256 currentVersion    = 100;

        bytes4 functionToExecute1 = IMapleProxyFactory.registerImplementation.selector;
        bytes4 functionToExecute2 = IMapleProxyFactory.enableUpgradePath.selector;

        bytes memory parameters1 = abi.encode(version,        newImplementation, address(0));
        bytes memory parameters2 = abi.encode(currentVersion, version,           address(0));

        _scheduleProposal(address(withdrawalManagerQueueFactory), functionToExecute1, parameters1);
        _scheduleProposal(address(withdrawalManagerQueueFactory), functionToExecute2, parameters2);

        uint32 scheduledAt = uint32(block.timestamp);
        ( uint32 delay, )  = IGovernorTimelock(timelock).defaultTimelockParameters();

        vm.warp(scheduledAt + delay);
        _executeProposal(expectedProposalId1, address(withdrawalManagerQueueFactory), functionToExecute1, parameters1);
        _executeProposal(expectedProposalId2, address(withdrawalManagerQueueFactory), functionToExecute2, parameters2);

        vm.prank(securityAdmin);
        IMapleWithdrawalManager(syrupUSDCWithdrawalManagerQueue).upgrade(version, "");

        assertEq(IMapleWithdrawalManager(syrupUSDCWithdrawalManagerQueue).poolManager(), newPoolManager);
    }

}
