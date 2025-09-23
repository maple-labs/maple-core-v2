// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract ControllersTests is SyrupBitcoinTestBase {

    function test_controllers_default() external {
        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));
    }

    function testFuzz_controllers_random(address asset) external {
        vm.assume(asset != address(depositAsset));

        assertEq(bitcoinStrategy.controllers(asset), address(0));
    }

    function test_controllers_revoke() external {
        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(0));
    }

    function test_controllers_replace() external {
        address newAssetController = makeAddr("newAssetController");

        vm.prank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", address(newAssetController), true);

        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), address(newAssetController));

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(newAssetController));
    }

}
