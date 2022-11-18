// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

contract ActivatePoolManagerTests is TestBaseWithAssertions {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool(1 weeks, 2 days);
    }

    function test_activatePoolManager() external {
        assertTrue(!poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(0));

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        assertTrue(poolManager.active());
        assertEq(globals.ownedPoolManager(address(poolDelegate)), address(poolManager));
    }

}

contract ActivatePoolManagerFailureTests is TestBaseWithAssertions {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool(1 weeks, 2 days);
    }

    function test_activatePoolManager_failIfNotGovernor() public {
        vm.expectRevert("MG:NOT_GOVERNOR");
        globals.activatePoolManager(address(poolManager));
    }

    function test_activatePoolManager_failIfProtocolIsPaused() public {
        vm.startPrank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        globals.activatePoolManager(address(poolManager));
    }

    function test_activatePoolManager_failIfNotGlobals() public {
        vm.expectRevert("PM:SA:NOT_GLOBALS");
        poolManager.setActive(true);
    }

}
