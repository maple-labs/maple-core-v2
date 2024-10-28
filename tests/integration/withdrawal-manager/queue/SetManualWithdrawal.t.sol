// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../../TestBaseWithAssertions.sol";

contract SetManualWithdrawalTests is TestBaseWithAssertions {

    address lp;
    address wm;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        lp = makeAddr("lp");
        wm = address(queueWM);

        deposit(lp, 1_000e6);
    }

    function test_setManualWithdrawal_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("WM:PAUSED");
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_failIfNotProtocolAdmin() external {
        vm.expectRevert("WM:NOT_PD_OR_GOV_OR_OA");
        queueWM.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_failIfLpAlreadyInQueue() external {
        requestRedeem(lp, 1_000e6);

        vm.expectRevert("WM:SMW:IN_QUEUE");
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_success() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));
    }

    function test_setManualWithdrawal_successAsGovernor() external {
        vm.prank(governor);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));
    }

    function test_setManualWithdrawal_successAsOperationalAdmin() external {
        vm.prank(operationalAdmin);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));
    }

    function test_setManualWithdrawal_unsetSuccess() external {
        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, true);

        assertTrue(queueWM.isManualWithdrawal(lp));

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp, false);

        assertFalse(queueWM.isManualWithdrawal(lp));
    }

}
