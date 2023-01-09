// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBaseWithAssertions } from "../utilities/TestBaseWithAssertions.sol";

contract TransferPoolOwnershipTests is TestBaseWithAssertions {

    address internal newPoolDelegate = address(new Address());

    function test_setPendingPoolDelegate_notPD() external {
        vm.expectRevert("PM:SPA:NOT_PD");
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_acceptPendingPoolDelegate_notPendingPoolDelegate() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.expectRevert("PM:APPD:NOT_PENDING_PD");
        poolManager.acceptPendingPoolDelegate();

        vm.prank(newPoolDelegate);
        poolManager.acceptPendingPoolDelegate();

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
        vm.expectRevert("MG:TOPM:NOT_AUTHORIZED");
        globals.transferOwnedPoolManager(poolDelegate, newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPendingPoolDelegate();

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
        vm.expectRevert("MG:TOPM:NOT_POOL_DELEGATE");
        poolManager.acceptPendingPoolDelegate();

        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(newPoolDelegate);
        poolManager.acceptPendingPoolDelegate();

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
        poolManager.acceptPendingPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);

        vm.prank(newPoolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        vm.expectRevert("MG:TOPM:ALREADY_OWNS");
        poolManager.acceptPendingPoolDelegate();
    }

    function test_setPendingPoolDelegate() external {
        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);
    }

    function test_acceptPendingPoolDelegate() external {
        vm.prank(governor);
        globals.setValidPoolDelegate(newPoolDelegate, true);

        vm.prank(poolDelegate);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPendingPoolDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        ( address poolManager_, bool isPoolDelegate_ ) = globals.poolDelegates(newPoolDelegate);

        assertEq(poolManager_, address(poolManager));

        assertTrue(isPoolDelegate_);
    }

}
