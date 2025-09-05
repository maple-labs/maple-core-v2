// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AssetControllerTestBase } from "../AssetControllerTestBase.sol";

contract AssetControllerSetAssetsTests is AssetControllerTestBase {

    address[] newAssets;

    bool[] canDeposit;
    bool[] canWithdraw;

    function setUp() public virtual override {
        super.setUp();

        newAssets   = [address(0x01), address(0x02)];
        canDeposit  = [true, true];
        canWithdraw = [true, true];

        vm.startPrank(governor);

        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[0], true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[1], true);

        vm.stopPrank();
    }

    function test_setAssets_revert_notGovernor() external {
        vm.expectRevert("AC:NOT_GOVERNOR");
        assetController.setAssets(newAssets, canDeposit, canWithdraw);
    }

    function test_setAssets_revert_noAssets() external {
        vm.prank(governor);
        vm.expectRevert("AC:SA:NO_ASSETS");
        assetController.setAssets(new address[](0), canDeposit, canWithdraw);
    }

    function test_setAssets_revert_lengthMismatch_canDeposit() external {
        canDeposit.pop();

        vm.prank(governor);
        vm.expectRevert("AC:SA:LENGTH_MISMATCH");
        assetController.setAssets(newAssets, canDeposit, canWithdraw);
    }

    function test_setAssets_revert_lengthMismatch_canWithdraw() external {
        canWithdraw.pop();

        vm.prank(governor);
        vm.expectRevert("AC:SA:LENGTH_MISMATCH");
        assetController.setAssets(newAssets, canDeposit, canWithdraw);
    }

    function test_setAssets_revert_notAsset_all() external {
        address[] memory invalidAssets = new address[](2);
        invalidAssets[0] = makeAddr("invalid_asset1");
        invalidAssets[1] = makeAddr("invalid_asset2");

        vm.prank(governor);
        vm.expectRevert("AC:SA:NOT_ASSET");
        assetController.setAssets(invalidAssets, canDeposit, canWithdraw);
    }

    function test_setAssets_revert_notAsset_one() external {
        newAssets[1] = makeAddr("invalid_asset");

        vm.prank(governor);
        vm.expectRevert("AC:SA:NOT_ASSET");
        assetController.setAssets(newAssets, canDeposit, canWithdraw);
    }

    function test_setAssets_success_setAssets() public {
        vm.startPrank(governor);

        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[0], true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[1], true);

        assertEq(assetController.canDeposit(newAssets[0]), false);
        assertEq(assetController.canDeposit(newAssets[1]), false);

        assertEq(assetController.canWithdraw(newAssets[0]), false);
        assertEq(assetController.canWithdraw(newAssets[1]), false);

        assetController.setAssets(newAssets, canDeposit, canWithdraw);

        vm.stopPrank();

        assertEq(assetController.canDeposit(newAssets[0]), true);
        assertEq(assetController.canDeposit(newAssets[1]), true);

        assertEq(assetController.canWithdraw(newAssets[0]), true);
        assertEq(assetController.canWithdraw(newAssets[1]), true);
    }

    function test_setAssets_success_removeAssets() external {
        vm.startPrank(governor);

        // TODO: Upcoming change to the assetController may make setting globals unnecessary. Revisit after the PR is merged. 
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[0], true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[1], true);

        assertEq(assetController.canDeposit(newAssets[0]), false);
        assertEq(assetController.canDeposit(newAssets[1]), false);

        assertEq(assetController.canWithdraw(newAssets[0]), false);
        assertEq(assetController.canWithdraw(newAssets[1]), false);

        assetController.setAssets(newAssets, canDeposit, canWithdraw);

        vm.stopPrank();

        assertEq(assetController.canDeposit(newAssets[0]), true);
        assertEq(assetController.canDeposit(newAssets[1]), true);

        assertEq(assetController.canWithdraw(newAssets[0]), true);
        assertEq(assetController.canWithdraw(newAssets[1]), true);

        canDeposit  = [false, false];
        canWithdraw = [false, false];

        vm.prank(governor);
        assetController.setAssets(newAssets, canDeposit, canWithdraw);

        assertEq(assetController.canDeposit(newAssets[0]), false);
        assertEq(assetController.canDeposit(newAssets[1]), false);

        assertEq(assetController.canWithdraw(newAssets[0]), false);
        assertEq(assetController.canWithdraw(newAssets[1]), false);
    }

}
