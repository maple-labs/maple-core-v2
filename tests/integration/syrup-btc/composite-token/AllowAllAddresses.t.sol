// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract CompositeTokenAllowAllAddressesTests is SyrupBitcoinTestBase {

    function test_allowAllAddresses_revert_notGovernor() external {
        vm.expectRevert("CT:NOT_GOVERNOR");
        compositeAsset.allowAllAddresses(true);
    }

    function test_allowAllAddresses_success_governor() external {
        address receiver = makeAddr("receiver");
        uint256 amount   = 100e8;

        assertEq(compositeAsset.allAllowed(),               false);
        assertEq(compositeAsset.allowedAddresses(receiver), false);

        vm.prank(assetControllerProxy);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.mint(receiver, amount);

        vm.prank(governor);
        compositeAsset.allowAllAddresses(true);

        assertEq(compositeAsset.allAllowed(),               true);
        assertEq(compositeAsset.allowedAddresses(receiver), false);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(receiver, amount);

        assertEq(compositeAsset.balanceOf(receiver), amount);

        vm.prank(governor);
        compositeAsset.allowAllAddresses(false);

        assertEq(compositeAsset.allAllowed(),               false);
        assertEq(compositeAsset.allowedAddresses(receiver), false);

        vm.prank(assetControllerProxy);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.mint(receiver, amount);
    }

}
