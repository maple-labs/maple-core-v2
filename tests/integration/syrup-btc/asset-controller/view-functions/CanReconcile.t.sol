// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract CanReconcileTests is SyrupBitcoinTestBase {

    function test_canReconcile_revert_assetApprovalRemoved() external {
        uint256 amount = 2e8;

        address strategy = poolManager.strategyList(0);

        uint256 depositAssetsBefore = assetController.depositAssets(address(depositAsset));
        uint256 poolAssetsBefore = assetController.poolAssets(address(depositAsset));
        uint256 expectedOut      = assetController.previewDeploy(address(depositAsset), amount);

        depositAsset.mint(strategy, amount);

        vm.startPrank(strategy);
        depositAsset.approve(address(assetController), amount);
        assetController.reconcile(address(depositAsset), amount);
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)), depositAssetsBefore + amount);
        assertEq(assetController.poolAssets(address(depositAsset)),    poolAssetsBefore + expectedOut);

        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = false;

        assertEq(assetController.canReconcile(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canReconcile(address(depositAsset)), false);

        vm.prank(strategy);
        vm.expectRevert("AC:R:INVALID_ASSET");
        assetController.reconcile(address(depositAsset), 1);
    }

    function test_canReconcile_success_randomAsset_false() external {
        address random = makeAddr("randomAsset");
        assertEq(assetController.canReconcile(address(depositAsset)), true);
        assertEq(assetController.canReconcile(random),                false);
    }

    function test_canReconcile_success_modifyFlags() external {
        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = false;

        assertEq(assetController.canReconcile(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canReconcile(address(depositAsset)), false);

        canReconcileFlags[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canReconcile(address(depositAsset)), true);
    }

}
