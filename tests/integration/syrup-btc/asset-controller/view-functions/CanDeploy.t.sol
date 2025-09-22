// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract CanDeployTests is SyrupBitcoinTestBase {

    function test_canDeploy_revert_assetApprovalRemoved() external {
        uint256 amount = 1e8;

        address strategy = poolManager.strategyList(0);

        uint256 depositAssetsBefore = assetController.depositAssets(address(depositAsset));
        uint256 poolAssetsBefore    = assetController.poolAssets(address(depositAsset));

        assertEq(assetController.canDeploy(address(depositAsset)), true);

        depositAsset.mint(strategy, amount);

        vm.startPrank(strategy);
        depositAsset.approve(address(assetController), amount);
        assetController.reconcile(address(depositAsset), amount);
        assetController.deploy(address(depositAsset), amount);
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)), depositAssetsBefore);
        assertEq(assetController.poolAssets(address(depositAsset)),    poolAssetsBefore);

        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = false;
        canReconcileFlags[0] = true;

        assertEq(assetController.canDeploy(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canDeploy(address(depositAsset)), false);

        vm.prank(strategy);
        vm.expectRevert("AC:D:INVALID_ASSET");
        assetController.deploy(address(depositAsset), 1);
    }

    function test_canDeploy_success_randomAsset_false() external {
        address random = makeAddr("randomAsset");

        assertEq(assetController.canDeploy(address(depositAsset)), true);
        assertEq(assetController.canDeploy(random),                false);
    }

    function test_canDeploy_success_modifyFlags() external {
        address[] memory assets            = new address[](1);
        bool[]    memory canWrapFlags      = new bool[](1);
        bool[]    memory canUnwrapFlags    = new bool[](1);
        bool[]    memory canDeployFlags    = new bool[](1);
        bool[]    memory canReconcileFlags = new bool[](1);

        assets[0]            = address(depositAsset);
        canWrapFlags[0]      = true;
        canUnwrapFlags[0]    = true;
        canDeployFlags[0]    = false;
        canReconcileFlags[0] = true;

        assertEq(assetController.canDeploy(address(depositAsset)), true);

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canDeploy(address(depositAsset)), false);

        canDeployFlags[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canDeploy(address(depositAsset)), true);
    }

    function test_canDeploy_success_multipleDepositAsset_removeOneAsset() external {
        address secondAsset = makeAddr("secondAsset");

        vm.prank(governor);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", secondAsset, true);

        assertEq(assetController.canDeploy(address(depositAsset)), true);
        assertEq(assetController.canDeploy(secondAsset),          false);

        address[] memory assets            = new address[](2);
        bool[]    memory canWrapFlags      = new bool[](2);
        bool[]    memory canUnwrapFlags    = new bool[](2);
        bool[]    memory canDeployFlags    = new bool[](2);
        bool[]    memory canReconcileFlags = new bool[](2);

        assets[0] = address(depositAsset);
        assets[1] = secondAsset;

        canWrapFlags[0]      = true;
        canWrapFlags[1]      = true;
        canUnwrapFlags[0]    = true;
        canUnwrapFlags[1]    = true;
        canDeployFlags[0]    = true;
        canDeployFlags[1]    = true;
        canReconcileFlags[0] = true;
        canReconcileFlags[1] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrapFlags, canUnwrapFlags, canDeployFlags, canReconcileFlags);

        assertEq(assetController.canDeploy(address(depositAsset)), true);
        assertEq(assetController.canDeploy(secondAsset),           true);

        address[] memory remainingAssets            = new address[](1);
        bool[]    memory remainingCanWrapFlags      = new bool[](1);
        bool[]    memory remainingCanUnwrapFlags    = new bool[](1);
        bool[]    memory remainingCanDeployFlags    = new bool[](1);
        bool[]    memory remainingCanReconcileFlags = new bool[](1);

        remainingAssets[0] = address(depositAsset);

        remainingCanWrapFlags[0]      = true;
        remainingCanUnwrapFlags[0]    = true;
        remainingCanDeployFlags[0]    = false;
        remainingCanReconcileFlags[0] = true;

        vm.prank(governor);
        assetController.setAssets(
            remainingAssets,
            remainingCanWrapFlags,
            remainingCanUnwrapFlags,
            remainingCanDeployFlags,
            remainingCanReconcileFlags
        );

        assertEq(assetController.canDeploy(address(depositAsset)), false);
        assertEq(assetController.canDeploy(secondAsset),           true);
    }

}
