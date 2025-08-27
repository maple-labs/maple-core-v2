// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISyrupBitcoinRouter } from "../../../modules/controller/contracts/interfaces/ISyrupBitcoinRouter.sol";

import { TestBase } from "../../TestBaseWithAssertions.sol";

contract DepositTestBase is TestBase {

    address controller = makeAddr("controller");

    address[] controllers;
    bool[]    flags;

    function setUp() public virtual override {
        _setupBitcoinPool();
    }

    function test_bitcoin_deposit() external {
        address depositor = makeAddr("lp");
        uint256 amount    = 125e8;

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        bitcoinRouter.deposit(address(depositAsset), amount, "", emptyPermit());
        vm.stopPrank();

        assertEq(depositAsset.balanceOf(address(depositor)),       0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), amount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);

        assertEq(compositeAsset.balanceOf(address(depositor)),       0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            amount);

        assertEq(pool.balanceOf(address(depositor)), amount);
    }

    function emptyPermit() internal returns (ISyrupBitcoinRouter.Permit memory permit) {
        permit = ISyrupBitcoinRouter.Permit(false, 0, 0, 0, 0);
    }

}
