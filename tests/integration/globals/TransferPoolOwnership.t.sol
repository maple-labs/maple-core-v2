// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract TransferPoolOwnershipTests is TestBaseWithAssertions {

    address newPoolDelegate = makeAddr("newPoolDelegate");

    function test_setPendingPoolDelegate_notPD() external {
        vm.expectRevert("PM:NOT_PD_OR_GOV_OR_OA");
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_acceptPoolDelegate_notPendingPoolDelegate() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.expectRevert("PM:APD:NOT_PENDING_PD");
        poolManager.acceptPoolDelegate();

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);
    }

    function test_transferOwnedPoolManager_notPoolManager() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        vm.expectRevert("MG:TOPM:NO_AUTH");
        globals.transferOwnedPoolManager(poolDelegate, newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);
    }

    function test_transferOwnedPoolManager_notValidPoolDelegate() external {
        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        vm.expectRevert("MG:TOPM:NOT_PD");
        poolManager.acceptPoolDelegate();

        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);
    }

    function test_transferOwnedPoolManager_alreadyPoolDelegate() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);

        vm.prank(newPoolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        vm.expectRevert("MG:TOPM:ALREADY_OWNS");
        poolManager.acceptPoolDelegate();
    }

    function test_setPendingPoolDelegate_asPoolDelegate() external {
        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_setPendingPoolDelegate_asGovernor() external {
        vm.prank(governor);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_setPendingPoolDelegate_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_acceptPoolDelegate() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);
    }

}
