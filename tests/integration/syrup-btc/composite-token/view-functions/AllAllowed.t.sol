// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract AllAllowedTests is SyrupBitcoinTestBase {

    function test_allAllowed_revert_allAllowed_disabled() external {
        address sender     = makeAddr("sender");
        address recipient  = makeAddr("recipient");

        uint256 amount = 1e8;

        assertEq(compositeAsset.allAllowed(),                false);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        vm.prank(governor);
        compositeAsset.allowAllAddresses(true);

        assertEq(compositeAsset.allAllowed(), true);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(sender, amount);

        assertEq(compositeAsset.balanceOf(sender), amount);

        uint256 senderBalBefore    = compositeAsset.balanceOf(sender);
        uint256 recipientBalBefore = compositeAsset.balanceOf(recipient);

        vm.prank(sender);
        compositeAsset.transfer(recipient, amount / 3);

        assertEq(compositeAsset.balanceOf(sender),    senderBalBefore - (amount / 3));
        assertEq(compositeAsset.balanceOf(recipient), recipientBalBefore + (amount / 3));

        vm.prank(governor);
        compositeAsset.allowAllAddresses(false);

        assertEq(compositeAsset.allAllowed(),                false);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        vm.prank(sender);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.transfer(recipient, amount / 3);
    }

    function test_success_allowAllAddresses() external {
        uint256 amount = 1e8;

        address sender     = makeAddr("sender");
        address recipient  = makeAddr("recipient");

        assertEq(compositeAsset.allAllowed(),                false);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        vm.prank(governor);
        compositeAsset.allowAllAddresses(true);

        assertEq(compositeAsset.allAllowed(),                true);
        assertEq(compositeAsset.allowedAddresses(recipient), false);

        vm.prank(assetControllerProxy);
        compositeAsset.mint(sender, amount);

        uint256 senderBalBefore    = compositeAsset.balanceOf(sender);
        uint256 recipientBalBefore = compositeAsset.balanceOf(recipient);

        vm.prank(sender);
        compositeAsset.transfer(recipient, amount);

        assertEq(compositeAsset.balanceOf(sender),    senderBalBefore - amount);
        assertEq(compositeAsset.balanceOf(recipient), recipientBalBefore + amount);
    }

}
