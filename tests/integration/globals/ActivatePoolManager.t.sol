// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract ActivatePoolManagerTests is TestBaseWithAssertions {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPool(start, 1 weeks, 2 days);
    }

    function test_activatePoolManager() external {
        assertTrue(!poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(0));

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        assertTrue(poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(poolManager));
    }

    function test_activatePoolManager_asOperationalAdmin() public {
        vm.expectRevert("MG:NOT_GOV_OR_OA");
        globals.activatePoolManager(address(poolManager));

        assertTrue(!poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(0));

        vm.prank(operationalAdmin);
        globals.activatePoolManager(address(poolManager));

        assertTrue(poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(poolManager));
    }

}

contract ActivatePoolManagerFailureTests is TestBaseWithAssertions {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPool(start, 1 weeks, 2 days);
    }

    function test_activatePoolManager_failIfNotGovernor() public {
        vm.expectRevert("MG:NOT_GOV_OR_OA");
        globals.activatePoolManager(address(poolManager));
    }

    function test_activatePoolManager_failIfProtocolIsPaused() public {
        vm.startPrank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PAUSED");
        globals.activatePoolManager(address(poolManager));
    }

    function test_activatePoolManager_failIfNotGlobals() public {
        vm.expectRevert("PM:SA:NOT_GLOBALS");
        poolManager.setActive(true);
    }

}
