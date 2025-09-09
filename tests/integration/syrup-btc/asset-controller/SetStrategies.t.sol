// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract AssetControllerSetStrategiesTests is SyrupBitcoinTestBase {

    address[] newStrategies;
    
    bool[] flags;

    function setUp() public virtual override {
        super.setUp();

        newStrategies = [address(0x01), address(0x02)];
        flags         = [true, true];

        vm.startPrank(governor);

        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[0], true);
        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[1], true);

        vm.stopPrank();
    }

    function test_setStrategies_revert_notGovernor() external  {
        vm.expectRevert("AC:NOT_GOVERNOR");
        assetController.setStrategies(newStrategies, flags);
    }

    function test_setStrategies_revert_noAddresses() external {
        vm.prank(governor);
        vm.expectRevert("AC:SS:NO_ADDRESSES");
        assetController.setStrategies(new address[](0), flags);
    }

    function test_setStrategies_revert_lengthMismatch() external {
        flags.pop();

        vm.prank(governor);
        vm.expectRevert("AC:SS:LENGTH_MISMATCH");
        assetController.setStrategies(newStrategies, flags);
    }

    function test_setStrategies_revert_notStrategy() external {
        vm.startPrank(governor);

        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[0], false);
        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[1], false);

        vm.expectRevert("AC:SS:NOT_STRATEGY");
        assetController.setStrategies(newStrategies, flags);

        vm.stopPrank();
    }

    function test_setStrategies_success_trueFlag_keySet() external {
        assertEq(assetController.isStrategy(newStrategies[0]), false);
        assertEq(assetController.isStrategy(newStrategies[1]), false);

        vm.prank(governor);
        assetController.setStrategies(newStrategies, flags);

        assertEq(assetController.isStrategy(newStrategies[0]), true);
        assertEq(assetController.isStrategy(newStrategies[1]), true);
    }

    function test_setStrategies_success_falseFlag_keyNotSet() external {
        flags = [false, false];
        
        vm.startPrank(governor);

        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[0], false);
        globals.setValidInstanceOf("BITCOIN_STRATEGY", newStrategies[1], false);

        assertEq(assetController.isStrategy(newStrategies[0]), false);
        assertEq(assetController.isStrategy(newStrategies[1]), false);

        assetController.setStrategies(newStrategies, flags);

        vm.stopPrank();

        assertEq(assetController.isStrategy(newStrategies[0]), false);
        assertEq(assetController.isStrategy(newStrategies[1]), false);
    }

}
