// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBaseWithAssertions.sol";

// TODO: Update to deployer Controller/ Price Oracle and syrupBTCRouter
contract DepositTestBase is TestBase {

    address controller = makeAddr("controller");

    address[] controllers;
    bool[]    flags;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createBitcoinPool();

        // NOTE: Move into setup function later.
        controllers.push(controller);
        flags.push(true);

        vm.prank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", controller, true);

        vm.prank(governor);
        compositeAsset.setAssetControllers(controllers, flags);
    }

    function test_bitcoin_deposit() external {
        address depositor = makeAddr("depositor");
        uint256 amount    = 125e8;

        vm.prank(controller);
        compositeAsset.mint(depositor, amount);

        address[] memory depositors_ = new address[](1);
        bool[] memory flags_         = new bool[](1);

        depositors_[0] = depositor;
        flags_[0]      = true;

        vm.prank(governor);
        poolPermissionManager.setLenderAllowlist(address(poolManager), depositors_, flags_);

        vm.startPrank(depositor);
        compositeAsset.approve(address(pool), amount);
        pool.deposit(amount, address(depositor));
        vm.stopPrank();

        assertEq(compositeAsset.balanceOf(depositor), 0);
        assertEq(pool.balanceOf(depositor),           amount);
    }

}
