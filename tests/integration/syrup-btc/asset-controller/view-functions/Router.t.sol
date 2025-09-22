// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISyrupBitcoinRouter } from "../../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract RouterTests is SyrupBitcoinTestBase {

    ISyrupBitcoinRouter newBitcoinRouter;

    address newBitcoinRouterProxy;

    function setUp() public virtual override {
        super.setUp();

        address newRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        address newRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");

        newBitcoinRouterProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(newRouterImplementation),
                address(newRouterInitializer),
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );

        newBitcoinRouter = ISyrupBitcoinRouter(newBitcoinRouterProxy);

        vm.startPrank(governor);
        newBitcoinRouter.setAssetController(address(depositAsset), address(assetController));
        compositeAsset.allowAllAddresses(true);
        globals.setValidInstanceOf("SYRUP_BTC_ROUTER", newBitcoinRouterProxy, true);
        vm.stopPrank();
    }

    function test_router_success() external {
        assertEq(assetController.router(), address(bitcoinRouter));

        vm.prank(governor);
        assetController.setRouter(newBitcoinRouterProxy);

        assertEq(assetController.router(), newBitcoinRouterProxy);

        depositAsset.mint(newBitcoinRouterProxy, 1);

        vm.prank(newBitcoinRouterProxy);
        assertEq(assetController.wrap(address(depositAsset), 1), 1);

        vm.prank(newBitcoinRouterProxy);
        assertEq(assetController.unwrap(address(depositAsset), 1), 1);
    }

}
