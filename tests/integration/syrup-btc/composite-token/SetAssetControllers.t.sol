// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract CompositeTokenSetAssetControllersTests is SyrupBitcoinTestBase {

    address[] controllers;
    bool[]    flags;

    function setUp() public override {
        super.setUp();

        controllers.push(makeAddr("newController1"));
        controllers.push(makeAddr("newController2"));

        flags.push(true);
        flags.push(true);

        vm.startPrank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", controllers[0], true);
        globals.setValidInstanceOf("ASSET_CONTROLLER", controllers[1], true);
        vm.stopPrank();
    }

    function test_setAssetControllers_revert_notProtocolAdmins() external {
        vm.expectRevert("CT:NOT_GOVERNOR");
        compositeAsset.setAssetControllers(new address[](0), new bool[](0));
    }

    function test_setAssetControllers_revert_noAddresses() external {
        vm.prank(governor);
        vm.expectRevert("CT:SAC:NO_ADDRESSES");
        compositeAsset.setAssetControllers(new address[](0), new bool[](0));
    }

    function test_setAssetControllers_revert_lengthMismatch() external {
        vm.prank(governor);
        vm.expectRevert("CT:SAC:LENGTH_MISMATCH");
        compositeAsset.setAssetControllers(new address[](1), new bool[](2));
    }

    function test_setAssetController_revert_invalidController() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", controllers[0], false);

        vm.expectRevert("CT:SAC:INVALID_CONTROLLER");
        compositeAsset.setAssetControllers(controllers, flags);
        vm.stopPrank();
    }

    function test_setAssetControllers_success_governor() external {
        assertEq(compositeAsset.controllers(controllers[0]), false);
        assertEq(compositeAsset.controllers(controllers[1]), false);

        vm.prank(governor);
        compositeAsset.setAssetControllers(controllers, flags);

        assertEq(compositeAsset.controllers(controllers[0]), true);
        assertEq(compositeAsset.controllers(controllers[1]), true);

        flags[0] = false;
        flags[1] = false;

        vm.prank(governor);
        compositeAsset.setAssetControllers(controllers, flags);

        assertEq(compositeAsset.controllers(controllers[0]), false);
        assertEq(compositeAsset.controllers(controllers[1]), false);
    }

}
