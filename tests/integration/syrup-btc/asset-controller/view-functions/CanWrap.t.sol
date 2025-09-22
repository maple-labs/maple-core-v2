// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract CanWrapTests is SyrupBitcoinTestBase {

    function test_canWrap_revert_assetApprovalRemoved() external {
        uint256 amount = 1e8;

        uint256 depositAssetsBefore = assetController.depositAssets(address(depositAsset));
        uint256 poolAssetsBefore    = assetController.poolAssets(address(depositAsset));
        uint256 expectedOut         = assetController.previewDeploy(address(depositAsset), amount);

        depositAsset.mint(address(bitcoinRouter), amount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)), amount);

        vm.prank(address(bitcoinRouter));
        assetController.wrap(address(depositAsset), amount);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAssetsBefore + amount);
        assertEq(assetController.poolAssets(address(depositAsset)),    poolAssetsBefore + expectedOut);

        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = false;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = true;

        assertEq(assetController.canWrap(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canWrap(address(depositAsset)), false);

        vm.prank(address(bitcoinRouter));
        vm.expectRevert("AC:W:INVALID_ASSET");
        assetController.wrap(address(depositAsset), 1);
    }

    function test_canWrap_success_randomAsset_false() external {
        address random = makeAddr("randomAsset");

        assertEq(assetController.canWrap(address(depositAsset)), true);
        assertEq(assetController.canWrap(random),                false);
    }

    function test_canWrap_success_modifyFlags() external {
        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = false;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = true;

        assertEq(assetController.canWrap(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canWrap(address(depositAsset)), false);

        canWrapFlags[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canWrap(address(depositAsset)), true);
    }

}
