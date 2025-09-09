// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    ISyrupBitcoinRouter
} from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract AssetControllerSetRouterTests is SyrupBitcoinTestBase {

    ISyrupBitcoinRouter newRouter;

    function setUp() public virtual override {
        super.setUp();

        address bitcoinRouterImplementation_ = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        address bitcoinRouterInitializer_    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");

        newRouter = ISyrupBitcoinRouter(deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(bitcoinRouterImplementation_),
                address(bitcoinRouterInitializer_),
                abi.encodeWithSignature("initialize(address)", (address(poolManager)))
            )
        ));
    }

    function test_setRouter_revert_notGovernor() external {
        vm.expectRevert("AC:NOT_GOVERNOR");
        assetController.setRouter(address(newRouter));
    }

    function test_setRouter_revert_notRouter() external {
        vm.startPrank(governor);

        globals.setValidInstanceOf("SYRUP_BTC_ROUTER", address(newRouter), false);

        vm.expectRevert("AC:SR:NOT_ROUTER");
        assetController.setRouter(address(newRouter));

        vm.stopPrank();
    }

    function test_setRouter_success() external {
        assertEq(assetController.router(), address(bitcoinRouter));

        vm.startPrank(governor);

        globals.setValidInstanceOf("SYRUP_BTC_ROUTER", address(newRouter), true);

        assetController.setRouter(address(newRouter));

        vm.stopPrank();

        assertEq(assetController.router(), address(newRouter));
    }

}
