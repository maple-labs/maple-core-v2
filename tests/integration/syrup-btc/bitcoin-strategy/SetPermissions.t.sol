// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SetPermissionsTests is SyrupBitcoinTestBase {

    address[] addressesToSet;

    bool[] allowDeploy    = [true, true];
    bool[] allowReconcile = [true, true];
    bool[] allowSchedule  = [true, true];

    function setUp() public virtual override {
        super.setUp();

        addressesToSet.push(makeAddr("addressToSetA"));
        addressesToSet.push(makeAddr("addressToSetB"));
    }

    function test_setPermissions_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_revert_notAdmin() external {
        vm.expectRevert("MBS:NOT_GOV_OR_OPS_ADMIN");
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_revert_noAddresses() external {
        address[] memory emptyAddresses = new address[](0);

        vm.prank(governor);
        vm.expectRevert("MBS:SP:NO_ADDRESSES");
        bitcoinStrategy.setPermissions(emptyAddresses, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_revert_deployMismatch() external {
        allowDeploy.pop();

        vm.prank(governor);
        vm.expectRevert("MBS:SP:DEPLOY_MISMATCH");
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_revert_reconcileMismatch() external {
        allowReconcile.pop();

        vm.prank(governor);
        vm.expectRevert("MBS:SP:RECONCILE_MISMATCH");
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_revert_scheduleMismatch() external {
        allowSchedule.pop();

        vm.prank(governor);
        vm.expectRevert("MBS:SP:SCHEDULE_MISMATCH");
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);
    }

    function test_setPermissions_success_singleAddress() external {
        address[] memory singleAddress = new address[](1);
        singleAddress[0]               = makeAddr("singleAddress");

        assertPermissions({
            account:      singleAddress[0],
            canDeploy:    false,
            canReconcile: false,
            canSchedule:  false
        });

        allowDeploy    = [true];
        allowReconcile = [false];
        allowSchedule  = [true];

        vm.prank(governor);
        bitcoinStrategy.setPermissions(singleAddress, allowDeploy, allowReconcile, allowSchedule);

        assertPermissions({
            account:      singleAddress[0],
            canDeploy:    true,
            canReconcile: false,
            canSchedule:  true
        });
    }

    function test_setPermissions_success_multipleAddresses() external {
        assertPermissions({
            account:      addressesToSet[0],
            canDeploy:    false,
            canReconcile: false,
            canSchedule:  false
        });
        assertPermissions({
            account:      addressesToSet[1],
            canDeploy:    false,
            canReconcile: false,
            canSchedule:  false
        });

        allowDeploy    = [true, false];
        allowReconcile = [false, true];
        allowSchedule  = [true, true];

        vm.prank(governor);
        bitcoinStrategy.setPermissions(addressesToSet, allowDeploy, allowReconcile, allowSchedule);

        assertPermissions({
            account:      addressesToSet[0],
            canDeploy:    true,
            canReconcile: false,
            canSchedule:  true
        });
        assertPermissions({
            account:      addressesToSet[1],
            canDeploy:    false,
            canReconcile: true,
            canSchedule:  true
        });
    }

}
