// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract SetPoolPermissionLevelTests is TestBase {

    uint256 constant PRIVATE = 0;
    uint256 constant PUBLIC  = 3;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);
    }

    function test_setPoolPermissionLevel_notAuthorized() external {
        vm.expectRevert("PPM:NOT_PD_GOV_OR_OA");
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), PUBLIC);
    }

    function test_setPoolPermissionLevel_anotherPoolDelegate() external {
        address anotherPoolDelegate = makeAddr("anotherPoolDelegate");

        vm.prank(governor);
        globals.setValidPoolDelegate(anotherPoolDelegate, true);

        vm.prank(anotherPoolDelegate);
        vm.expectRevert("PPM:NOT_PD_GOV_OR_OA");
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), PUBLIC);
    }

    function test_setPoolPermissionLevel_poolDelegate() external {
        vm.prank(poolDelegate);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), PUBLIC);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), PUBLIC);
    }

    function test_setPoolPermissionLevel_governor() external {
        vm.prank(governor);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), PUBLIC);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), PUBLIC);
    }

    function test_setPoolPermissionLevel_operationalAdmin() external {
        vm.prank(operationalAdmin);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), PUBLIC);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), PUBLIC);
    }

    function testFuzz_setPoolPermissionLevel_publicPool(uint256 permissionLevel) external {
        permissionLevel = bound(permissionLevel, 0, 3);

        openPool(address(poolManager));

        vm.prank(poolDelegate);
        vm.expectRevert("PPM:SPPL:PUBLIC_POOL");
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), permissionLevel);
    }

    function testFuzz_setPoolPermissionLevel_invalidLevel(uint256 permissionLevel) external {
        permissionLevel = bound(permissionLevel, 4, type(uint256).max);

        vm.prank(poolDelegate);
        vm.expectRevert("PPM:SPPL:INVALID_LEVEL");
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), permissionLevel);
    }

    function testFuzz_setPoolPermissionLevel(uint256 oldPermissionLevel, uint256 newPermissionLevel) external {
        oldPermissionLevel = bound(oldPermissionLevel, 0, PUBLIC);
        newPermissionLevel = bound(newPermissionLevel, 0, PUBLIC + 1);

        setPoolPermissionLevel(address(poolManager), oldPermissionLevel);

        if (oldPermissionLevel == PUBLIC) vm.expectRevert("PPM:SPPL:PUBLIC_POOL");
        else if (newPermissionLevel > PUBLIC) vm.expectRevert("PPM:SPPL:INVALID_LEVEL");

        vm.prank(poolDelegate);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), newPermissionLevel);

        if (oldPermissionLevel != PUBLIC && newPermissionLevel <= PUBLIC) {
            assertEq(poolPermissionManager.permissionLevels(address(poolManager)), newPermissionLevel);
        }
    }

}
