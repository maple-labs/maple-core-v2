// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract ControllersTests is SyrupBitcoinTestBase {

    function test_controllers_revert_burn_invalidController() external {
        address[] memory addresses = new address[](1);
        bool[]    memory flags     = new bool[](1);

        addresses[0] = assetControllerProxy;
        flags[0]     = false;

        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, flags);

        assertEq(compositeAsset.controllers(assetControllerProxy), false);

        vm.prank(assetControllerProxy);
        vm.expectRevert("CT:NOT_CONTROLLER");
        compositeAsset.burn(assetControllerProxy, 1);
    }

    function test_onlyController_revert_mint_invalidController() external {
        address[] memory addresses = new address[](1);
        bool[]    memory flags     = new bool[](1);

        addresses[0] = assetControllerProxy;
        flags[0]     = false;

        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, flags);

        assertEq(compositeAsset.controllers(assetControllerProxy), false);

        vm.prank(assetControllerProxy);
        vm.expectRevert("CT:NOT_CONTROLLER");
        compositeAsset.mint(assetControllerProxy, 1);
    }

    function test_controllers_success() external {
        assertEq(compositeAsset.controllers(assetControllerProxy),      true);
        assertEq(compositeAsset.controllers(makeAddr("randomAddress")), false);
    }

    function test_controllers_success_update() external {
        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        address[] memory addresses = new address[](1);
        bool[]    memory flags     = new bool[](1);

        addresses[0] = assetControllerProxy;
        flags[0]     = false;

        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, flags);

        assertEq(compositeAsset.controllers(assetControllerProxy), false);

        flags[0] = true;

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, flags);

        assertEq(compositeAsset.controllers(assetControllerProxy), true);
    }

    function test_onlyController_success_burn() external {
        uint256 amount = 1e8;

        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(assetControllerProxy, amount);

        assertEq(compositeAsset.balanceOf(assetControllerProxy), amount);

        vm.prank(assetControllerProxy);
        compositeAsset.burn(assetControllerProxy, amount / 2);

        assertEq(compositeAsset.balanceOf(assetControllerProxy), amount - (amount / 2));
    }

    function test_controllers_success_mint() external {
        uint256 amount = 1e8;

        uint256 balanceBefore = compositeAsset.balanceOf(assetControllerProxy);

        assertEq(compositeAsset.controllers(assetControllerProxy), true);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(assetControllerProxy, amount);

        assertEq(compositeAsset.balanceOf(assetControllerProxy), balanceBefore + amount);
    }

}
