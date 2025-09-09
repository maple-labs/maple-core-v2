// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AssetControllerTestBase } from "../AssetControllerTestBase.sol";

contract AssetControllerSetAssetsTests is AssetControllerTestBase {

    address[] newAssets;

    bool[] canWrap;
    bool[] canUnwrap;
    bool[] canDeploy;
    bool[] canReconcile;

    function setUp() public virtual override {
        super.setUp();

        newAssets = [address(0x01), address(0x02)];

        canWrap      = [true, true];
        canUnwrap    = [true, true];
        canDeploy    = [true, true];
        canReconcile = [true, true];

        vm.startPrank(governor);

        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[0], true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", newAssets[1], true);

        vm.stopPrank();
    }

    function test_setAssets_revert_notGovernor() external {
        vm.expectRevert("AC:NOT_GOVERNOR");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_noAssets() external {
        vm.prank(governor);
        vm.expectRevert("AC:SA:NO_ASSETS");
        assetController.setAssets(new address[](0), canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_lengthMismatch_canWrap() external {
        canWrap.pop();

        vm.prank(governor);
        vm.expectRevert("AC:SA:WRAP_MISMATCH");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_lengthMismatch_canUnwrap() external {
        canUnwrap.pop();

        vm.prank(governor);
        vm.expectRevert("AC:SA:UNWRAP_MISMATCH");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_lengthMismatch_canDeploy() external {
        canDeploy.push(true);

        vm.prank(governor);
        vm.expectRevert("AC:SA:DEPLOY_MISMATCH");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_lengthMismatch_canReconcile() external {
        canReconcile.push(false);

        vm.prank(governor);
        vm.expectRevert("AC:SA:RECONCILE_MISMATCH");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_notAsset_all() external {
        newAssets[0] = makeAddr("invalid_asset1");
        newAssets[1] = makeAddr("invalid_asset2");

        vm.prank(governor);
        vm.expectRevert("AC:SA:NOT_ASSET");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_revert_notAsset_one() external {
        newAssets[1] = makeAddr("invalid_asset");

        vm.prank(governor);
        vm.expectRevert("AC:SA:NOT_ASSET");
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);
    }

    function test_setAssets_success_setAssets() public {
        assertEq(assetController.canWrap(newAssets[0]), false);
        assertEq(assetController.canWrap(newAssets[1]), false);

        assertEq(assetController.canUnwrap(newAssets[0]), false);
        assertEq(assetController.canUnwrap(newAssets[1]), false);

        assertEq(assetController.canDeploy(newAssets[0]), false);
        assertEq(assetController.canDeploy(newAssets[1]), false);

        assertEq(assetController.canReconcile(newAssets[0]), false);
        assertEq(assetController.canReconcile(newAssets[1]), false);

        vm.prank(governor);
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);

        assertEq(assetController.canWrap(newAssets[0]), true);
        assertEq(assetController.canWrap(newAssets[1]), true);

        assertEq(assetController.canUnwrap(newAssets[0]), true);
        assertEq(assetController.canUnwrap(newAssets[1]), true);

        assertEq(assetController.canDeploy(newAssets[0]), true);
        assertEq(assetController.canDeploy(newAssets[1]), true);

        assertEq(assetController.canReconcile(newAssets[0]), true);
        assertEq(assetController.canReconcile(newAssets[1]), true);
    }

    function test_setAssets_success_removeAssets() external {
        assertEq(assetController.canWrap(newAssets[0]), false);
        assertEq(assetController.canWrap(newAssets[1]), false);

        assertEq(assetController.canUnwrap(newAssets[0]), false);
        assertEq(assetController.canUnwrap(newAssets[1]), false);

        assertEq(assetController.canDeploy(newAssets[0]), false);
        assertEq(assetController.canDeploy(newAssets[1]), false);

        assertEq(assetController.canReconcile(newAssets[0]), false);
        assertEq(assetController.canReconcile(newAssets[1]), false);

        vm.prank(governor);
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);

        assertEq(assetController.canWrap(newAssets[0]), true);
        assertEq(assetController.canWrap(newAssets[1]), true);

        assertEq(assetController.canUnwrap(newAssets[0]), true);
        assertEq(assetController.canUnwrap(newAssets[1]), true);

        assertEq(assetController.canDeploy(newAssets[0]), true);
        assertEq(assetController.canDeploy(newAssets[1]), true);

        assertEq(assetController.canReconcile(newAssets[0]), true);
        assertEq(assetController.canReconcile(newAssets[1]), true);

        canWrap  = [false, false];
        canUnwrap = [false, false];

        vm.prank(governor);
        assetController.setAssets(newAssets, canWrap, canUnwrap, canDeploy, canReconcile);

        assertEq(assetController.canWrap(newAssets[0]), false);
        assertEq(assetController.canWrap(newAssets[1]), false);

        assertEq(assetController.canUnwrap(newAssets[0]), false);
        assertEq(assetController.canUnwrap(newAssets[1]), false);

        assertEq(assetController.canDeploy(newAssets[0]), true);
        assertEq(assetController.canDeploy(newAssets[1]), true);

        assertEq(assetController.canReconcile(newAssets[0]), true);
        assertEq(assetController.canReconcile(newAssets[1]), true);
    }

}
