// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract TransferTests is SyrupBitcoinTestBase {

    address authorizedSender     = makeAddr("authorizedSender");
    address authorizedReceiver   = makeAddr("authorizedReceiver");
    address unauthorizedReceiver = makeAddr("unauthorizedReceiver");

    uint256 sendAmount = 100e8;

    function setUp() public override {
        super.setUp();

        address[] memory authorizedAddresses = new address[](2);
        bool[]    memory allowed             = new bool[](2);

        authorizedAddresses[0] = authorizedSender;
        authorizedAddresses[1] = authorizedReceiver;

        allowed[0] = true;
        allowed[1] = true;

        vm.prank(governor);
        compositeAsset.allowAddresses(authorizedAddresses, allowed);

        vm.prank(address(assetController));
        compositeAsset.mint(authorizedSender, sendAmount);

        assertEq(compositeAsset.allAllowed(), false);
    }

    function test_transfer_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(authorizedSender);
        vm.expectRevert("CT:PAUSED");
        compositeAsset.transfer(authorizedReceiver, sendAmount);
    }

    function test_transfer_revert_receiverNotAllowed() external {
        vm.prank(authorizedSender);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.transfer(unauthorizedReceiver, 1);
    }

    function test_transfer_revert_permissionRevoked() external {
        uint256 senderBalBefore   = compositeAsset.balanceOf(authorizedSender);
        uint256 receiverBalBefore = compositeAsset.balanceOf(authorizedReceiver);

        assertEq(compositeAsset.allowedAddresses(authorizedSender),   true);
        assertEq(compositeAsset.allowedAddresses(authorizedReceiver), true);

        vm.prank(authorizedSender);
        bool success = compositeAsset.transfer(authorizedReceiver, sendAmount / 2);

        assertEq(success,                                      true);
        assertEq(compositeAsset.balanceOf(authorizedSender),   senderBalBefore   - sendAmount / 2);
        assertEq(compositeAsset.balanceOf(authorizedReceiver), receiverBalBefore + sendAmount / 2);

        address[] memory revokeAddresses = new address[](1);
        revokeAddresses[0]               = authorizedReceiver;

        bool[] memory allowed = new bool[](1);
        allowed[0]            = false;

        vm.prank(governor);
        compositeAsset.allowAddresses(revokeAddresses, allowed);

        assertEq(compositeAsset.allowedAddresses(authorizedReceiver), false);

        vm.prank(authorizedSender);
        vm.expectRevert("CT:NOT_ALLOWED");
        compositeAsset.transfer(authorizedReceiver, 1);
    }

    function test_transfer_success_allowedReceiver() external {
        uint256 senderBalBefore   = compositeAsset.balanceOf(authorizedSender);
        uint256 receiverBalBefore = compositeAsset.balanceOf(authorizedReceiver);

        assertEq(compositeAsset.allowedAddresses(authorizedSender),   true);
        assertEq(compositeAsset.allowedAddresses(authorizedReceiver), true);

        vm.prank(authorizedSender);
        bool success = compositeAsset.transfer(authorizedReceiver, sendAmount);

        assertEq(success,                                      true);
        assertEq(compositeAsset.balanceOf(authorizedSender),   senderBalBefore   - sendAmount);
        assertEq(compositeAsset.balanceOf(authorizedReceiver), receiverBalBefore + sendAmount);
    }

    function test_transfer_success_allAllowed() external {
        assertEq(compositeAsset.allAllowed(), false);

        vm.prank(governor);
        compositeAsset.allowAllAddresses(true);

        assertEq(compositeAsset.allAllowed(), true);

        uint256 senderBalBefore   = compositeAsset.balanceOf(authorizedSender);
        uint256 receiverBalBefore = compositeAsset.balanceOf(unauthorizedReceiver);

        vm.prank(authorizedSender);
        bool success = compositeAsset.transfer(unauthorizedReceiver, sendAmount);

        assertEq(success,                                        true);
        assertEq(compositeAsset.balanceOf(authorizedSender),     senderBalBefore   - sendAmount);
        assertEq(compositeAsset.balanceOf(unauthorizedReceiver), receiverBalBefore + sendAmount);
    }

    function test_transfer_revert_insufficientBalance() external {
        vm.prank(authorizedSender);
        vm.expectRevert(arithmeticError);
        compositeAsset.transfer(authorizedReceiver, sendAmount + 1);
    }

    function test_transfer_success_zeroAmount() external {
        uint256 senderBalBefore   = compositeAsset.balanceOf(authorizedSender);
        uint256 receiverBalBefore = compositeAsset.balanceOf(authorizedReceiver);

        assertEq(compositeAsset.allowedAddresses(authorizedSender),   true);
        assertEq(compositeAsset.allowedAddresses(authorizedReceiver), true);

        vm.prank(authorizedSender);
        bool success = compositeAsset.transfer(authorizedReceiver, 0);

        assertEq(success,                                      true);
        assertEq(compositeAsset.balanceOf(authorizedSender),   senderBalBefore);
        assertEq(compositeAsset.balanceOf(authorizedReceiver), receiverBalBefore);
    }

}
