// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory } from "../../../contracts/interfaces/Interfaces.sol";

import { MockMapleWithdrawalManager } from "../../mocks/Mocks.sol";

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract GovernorTimelockScenariosTests is GovernorTimelockTestBase {

    function test_withdrawERC20Token_revert_afterChangingTokenWithdrawer() public {
        uint256 balanceBefore    = 100e18;
        uint256 amountToWithdraw = 40e18;
        collateralAsset.mint(address(timelock), balanceBefore);

        address newTokenWithdrawer = makeAddr("newTokenWithdrawer");

        vm.startPrank(governor);
        timelock.setPendingTokenWithdrawer(newTokenWithdrawer);
        timelock.withdrawERC20Token(address(collateralAsset), amountToWithdraw);
        vm.stopPrank();

        assertEq(collateralAsset.balanceOf(governor),          amountToWithdraw);
        assertEq(collateralAsset.balanceOf(address(timelock)), balanceBefore - amountToWithdraw);

        vm.prank(newTokenWithdrawer);
        vm.expectRevert("GT:WET:NOT_AUTHORIZED");
        timelock.withdrawERC20Token(address(collateralAsset), amountToWithdraw);

        vm.prank(newTokenWithdrawer);
        timelock.acceptTokenWithdrawer();

        vm.prank(governor);
        vm.expectRevert("GT:WET:NOT_AUTHORIZED");
        timelock.withdrawERC20Token(address(collateralAsset), amountToWithdraw);

        vm.prank(newTokenWithdrawer);
        timelock.withdrawERC20Token(address(collateralAsset), amountToWithdraw);

        assertEq(collateralAsset.balanceOf(newTokenWithdrawer), amountToWithdraw);
        assertEq(collateralAsset.balanceOf(address(timelock)),  balanceBefore - 2 * amountToWithdraw);
    }

    function test_updateRoles_backupRoleAdmin_removesPrimaryRoleAdmin() public {
        address roleAdmin2 = makeAddr("roleAdmin2");

        _proposeRoleUpdate(timelock.ROLE_ADMIN(), roleAdmin2, true);
        _executeRoleUpdate(2, timelock.ROLE_ADMIN(), roleAdmin2, true);

        assertEq(timelock.hasRole(roleAdmin2, timelock.ROLE_ADMIN()), true);

        _proposeRoleUpdate(timelock.ROLE_ADMIN(), roleAdmin, false);
        _executeRoleUpdate(3, timelock.ROLE_ADMIN(), roleAdmin, false);

        assertEq(timelock.hasRole(roleAdmin,  timelock.ROLE_ADMIN()), false);
        assertEq(timelock.hasRole(roleAdmin2, timelock.ROLE_ADMIN()), true);
    }

    function test_unscheduleProposals_cancellerCanNotUnscheduleRoleUpdate() public {
        _proposeRoleUpdate(timelock.CANCELLER_ROLE(), canceller, false);

        uint256[] memory proposalsToCancel = new uint256[](1);
        proposalsToCancel[0]               = 2;

        vm.prank(canceller);
        vm.expectRevert("GT:UP:NOT_UNSCHEDULABLE");
        timelock.unscheduleProposals(proposalsToCancel);
    }

    function test_unscheduleProposals_cancellerUnschedulesMaliciousProposal() public {
        uint256 timelockBalance = 100e18;
        collateralAsset.mint(address(timelock), timelockBalance);

        bytes4 functionToExecute = collateralAsset.transfer.selector;
        bytes memory parameters  = abi.encode(makeAddr("malicious"), timelockBalance);

        ( uint256 proposalId, ) = _scheduleProposal(address(timelock), functionToExecute, parameters);

        uint256[] memory proposalsToCancel = new uint256[](1);
        proposalsToCancel[0]               = proposalId;

        vm.prank(canceller);
        timelock.unscheduleProposals(proposalsToCancel);

        assertEmptyProposal(address(timelock), proposalId);

        vm.expectRevert("GT:EP:NOT_EXECUTABLE");
        _executeProposal(proposalId, address(timelock), functionToExecute, parameters);
    }

    function test_upgradeWithdrawalManager() public {
        address newPoolManager = makeAddr("newPoolManager");

        assertNotEq(cyclicalWM.poolManager(), newPoolManager);
        assertEq(cyclicalWM.poolManager(), address(poolManager));

        address newImplementation = address(new MockMapleWithdrawalManager(newPoolManager));
        uint256 version           = 200;

        bytes4 functionToExecute1 = IMapleProxyFactory.registerImplementation.selector;
        bytes4 functionToExecute2 = IMapleProxyFactory.enableUpgradePath.selector;

        bytes memory parameters1 = abi.encode(version, newImplementation, address(0));
        bytes memory parameters2 = abi.encode(1, version, address(0));

        _scheduleProposal(address(cyclicalWMFactory), functionToExecute1, parameters1);
        _scheduleProposal(address(cyclicalWMFactory), functionToExecute2, parameters2);

        uint32 scheduledAt = uint32(block.timestamp);
        ( uint32 delay, )  = timelock.defaultTimelockParameters();

        vm.warp(scheduledAt + delay);
        _executeProposal(2, address(cyclicalWMFactory), functionToExecute1, parameters1);
        _executeProposal(3, address(cyclicalWMFactory), functionToExecute2, parameters2);

        vm.prank(securityAdmin);
        cyclicalWM.upgrade(version, "");

        assertEq(cyclicalWM.poolManager(), newPoolManager);
    }

}
