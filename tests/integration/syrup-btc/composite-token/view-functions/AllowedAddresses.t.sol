// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract AllowedAddressesTests is SyrupBitcoinTestBase {

    function test_allowedAddresses_revert_permissionRevoked() external {
        address sender    = makeAddr("sender");
        address recipient = makeAddr("recipient");

        uint256 amount = 1e8;

        assertEq(compositeAsset.allAllowed(),                false);
        assertEq(compositeAsset.allowedAddresses(sender),    false);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        address[] memory addresses = new address[](3);
        bool[]    memory flags     = new bool[](3);

        addresses[0] = sender;
        addresses[1] = recipient;

        flags[0] = true;
        flags[1] = true;

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, flags);

        assertEq(compositeAsset.allowedAddresses(sender),    true);
        assertEq(compositeAsset.allowedAddresses(recipient), true);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(sender, amount);

        assertEq(compositeAsset.balanceOf(sender), amount);

        uint256 senderBalBefore    = compositeAsset.balanceOf(sender);
        uint256 recipientBalBefore = compositeAsset.balanceOf(recipient);

        vm.prank(sender);
        compositeAsset.transfer(recipient, amount / 3);

        assertEq(compositeAsset.balanceOf(sender),    senderBalBefore - (amount / 3));
        assertEq(compositeAsset.balanceOf(recipient), recipientBalBefore + (amount / 3));

        flags[0] = true;
        flags[1] = false;

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, flags);

        assertEq(compositeAsset.allowedAddresses(recipient), false);

        vm.prank(sender);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.transfer(recipient, amount / 3);
    }

    function test_allowedAddresses_success() external {
        address sender    = makeAddr("sender");
        address recipient = makeAddr("recipient");

        uint256 amount = 1e8;

        assertEq(compositeAsset.allAllowed(),                false);
        assertEq(compositeAsset.allowedAddresses(sender),    false);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        address[] memory addresses = new address[](3);
        bool[]    memory flags    = new bool[](3);

        addresses[0] = sender;
        addresses[1] = recipient;

        flags[0] = true;
        flags[1] = true;

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, flags);

        assertEq(compositeAsset.allowedAddresses(sender),    true);
        assertEq(compositeAsset.allowedAddresses(recipient), true);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(sender, amount);

        assertEq(compositeAsset.balanceOf(sender), amount);

        uint256 senderBalBefore    = compositeAsset.balanceOf(sender);
        uint256 recipientBalBefore = compositeAsset.balanceOf(recipient);

        vm.prank(sender);
        compositeAsset.transfer(recipient, amount);

        assertEq(compositeAsset.balanceOf(sender),    senderBalBefore - amount);
        assertEq(compositeAsset.balanceOf(recipient), recipientBalBefore + amount);
    }

}
