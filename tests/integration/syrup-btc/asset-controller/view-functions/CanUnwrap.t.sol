// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract CanUnwrapTests is SyrupBitcoinTestBase {

    function test_canUnwrap_revert_assetApprovalRemoved() external {
        uint256 amount = 5e7;

        uint256 expectedPool = assetController.previewDeploy(address(depositAsset), amount);

        depositAsset.mint(address(bitcoinRouter), amount);

        vm.prank(address(bitcoinRouter));
        assetController.wrap(address(depositAsset), amount);

        uint256 depBefore  = assetController.depositAssets(address(depositAsset));
        uint256 poolBefore = assetController.poolAssets(address(depositAsset));

        vm.prank(address(bitcoinRouter));
        assetController.unwrap(address(depositAsset), expectedPool);

        assertEq(assetController.depositAssets(address(depositAsset)), depBefore - expectedPool);
        assertEq(assetController.poolAssets(address(depositAsset)),    poolBefore - expectedPool);

        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = false;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = true;

        assertEq(assetController.canUnwrap(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canUnwrap(address(depositAsset)), false);

        vm.prank(address(bitcoinRouter));
        vm.expectRevert("AC:U:INVALID_ASSET");
        assetController.unwrap(address(depositAsset), 1);
    }

    function test_canUnwrap_success_randomAsset_false() external {
        address random = makeAddr("randomAsset");

        assertEq(assetController.canUnwrap(address(depositAsset)), true);
        assertEq(assetController.canUnwrap(random),                false);
    }

    function test_canUnwrap_success_modifyFlags() external {
        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = false;
        canDeployFlags[0]    = true;
        canReconcileFlags[0] = true;

        assertEq(assetController.canUnwrap(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canUnwrap(address(depositAsset)), false);

        canUnwrapFlags[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canUnwrap(address(depositAsset)), true);
    }

}
