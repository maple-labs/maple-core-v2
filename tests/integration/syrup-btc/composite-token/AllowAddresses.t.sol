// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract CompositeTokenAllowAddressesTests is SyrupBitcoinTestBase {

    address[] addresses;
    bool[]    allowed;

    function setUp() public override {
        super.setUp();

        addresses.push(makeAddr("newAddress1"));
        addresses.push(makeAddr("newAddress2"));

        allowed.push(true);
        allowed.push(true);
    }

    function test_allowAddresses_revert_notProtocolAdmins() external {
        vm.expectRevert("CT:NOT_AUTHORIZED");
        compositeAsset.allowAddresses(new address[](0), new bool[](0));
    }

    function test_allowAddresses_revert_noAddresses() external {
        vm.prank(governor);
        vm.expectRevert("CT:A:NO_ADDRESSES");
        compositeAsset.allowAddresses(new address[](0), new bool[](0));

        vm.prank(operationalAdmin);
        vm.expectRevert("CT:A:NO_ADDRESSES");
        compositeAsset.allowAddresses(new address[](0), new bool[](0));
    }

    function test_allowAddresses_revert_lengthMismatch() external {
        vm.prank(governor);
        vm.expectRevert("CT:A:LENGTH_MISMATCH");
        compositeAsset.allowAddresses(new address[](1), new bool[](2));

        vm.prank(operationalAdmin);
        vm.expectRevert("CT:A:LENGTH_MISMATCH");
        compositeAsset.allowAddresses(new address[](1), new bool[](2));
    }

    function test_allowAddresses_success_governor() external {
        assertEq(compositeAsset.allowedAddresses(addresses[0]), false);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), false);

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, allowed);

        assertEq(compositeAsset.allowedAddresses(addresses[0]), true);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), true);

        allowed[0] = false;
        allowed[1] = false;

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, allowed);

        assertEq(compositeAsset.allowedAddresses(addresses[0]), false);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), false);
    }

    function test_allowAddresses_success_operationalAdmin() external {
        assertEq(compositeAsset.allowedAddresses(addresses[0]), false);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), false);

        vm.prank(operationalAdmin);
        compositeAsset.allowAddresses(addresses, allowed);

        assertEq(compositeAsset.allowedAddresses(addresses[0]), true);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), true);

        allowed[0] = false;
        allowed[1] = false;

        vm.prank(operationalAdmin);
        compositeAsset.allowAddresses(addresses, allowed);

        assertEq(compositeAsset.allowedAddresses(addresses[0]), false);
        assertEq(compositeAsset.allowedAddresses(addresses[1]), false);
    }

}

