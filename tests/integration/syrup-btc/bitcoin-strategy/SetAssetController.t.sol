// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SetAssetControllerTests is SyrupBitcoinTestBase {

    uint256 constant MAX_UINT = type(uint256).max;

    address controllerA;
    address controllerB;

    function setUp() public virtual override {
        super.setUp();

        controllerA = makeAddr("controllerA");
        controllerB = makeAddr("controllerB");

        vm.startPrank(governor);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", address(depositAsset), true);
        globals.setValidInstanceOf("ASSET_CONTROLLER",        controllerA,           true);
        globals.setValidInstanceOf("ASSET_CONTROLLER",        controllerB,           true);
        vm.stopPrank();
    }

    function test_setAssetController_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);
    }

    function test_setAssetController_revert_notAdmin() external {
        vm.expectRevert("MBS:NOT_ADMIN");
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);
    }

    function test_setAssetController_revert_invalidAsset() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", address(depositAsset), false);

        vm.expectRevert("MBS:SAC:INVALID_ASSET");
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);
        vm.stopPrank();
    }

    function test_setAssetController_revert_invalidController() external {
        address invalidController = makeAddr("invalidController");
        address beforeController  = bitcoinStrategy.controllers(address(depositAsset));

        assertEq(beforeController, address(assetController));

        vm.startPrank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", invalidController, false);

        vm.expectRevert("MBS:SAC:INVALID_CONTROLLER");
        bitcoinStrategy.setAssetController(address(depositAsset), invalidController);
        vm.stopPrank();
    }

    function test_setAssetController_revert_depositAsset_approveZero() external {
        vm.startPrank(governor);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));

        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerA);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              MAX_UINT);

        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSignature("approve(address,uint256)", controllerA, 0),
            abi.encode(false)
        );

        vm.expectRevert("MBS:SAC:DA_APPROVE0_FAIL");
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));
        vm.stopPrank();
    }

    function test_setAssetController_revert_poolAsset_approveZero() external {
        vm.startPrank(governor);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));

        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerA);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              MAX_UINT);

        vm.mockCall(
            address(compositeAsset),
            abi.encodeWithSignature("approve(address,uint256)", controllerA, 0),
            abi.encode(false)
        );

        vm.expectRevert("MBS:SAC:PA_APPROVE0_FAIL");
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));
        vm.stopPrank();
    }

    function test_setAssetController_revert_depositAsset_approveMax() external {
        vm.startPrank(governor);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));

        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(0));

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);

        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSignature("approve(address,uint256)", controllerA, MAX_UINT),
            abi.encode(false)
        );

        vm.expectRevert("MBS:SAC:DA_APPROVE_FAIL");
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);
        vm.stopPrank();
    }

    function test_setAssetController_revert_poolAsset_approveMax() external {
        vm.startPrank(governor);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));

        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(0));

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);

        vm.mockCall(
            address(compositeAsset),
            abi.encodeWithSignature("approve(address,uint256)", controllerA, MAX_UINT),
            abi.encode(false)
        );

        vm.expectRevert("MBS:SAC:PA_APPROVE_FAIL");
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);
        vm.stopPrank();
    }

    function test_setAssetController_success_swapControllers_updatesAllowances() external {
        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(assetController));

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), MAX_UINT);
        assertEq(depositAsset.allowance(controllerA,                address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), MAX_UINT);
        assertEq(compositeAsset.allowance(controllerA,              address(bitcoinStrategy)), 0);

        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerA);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              MAX_UINT);

        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), controllerB);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerB);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerB), MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerB), MAX_UINT);
    }

    function test_setAssetController_success_removeController_revokesApprovals() external {
        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerA);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              MAX_UINT);

        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), address(0));

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              0);
    }

    function test_setAssetController_success_idempotent_setSameController_keepsMaxApprovals() external {
        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        uint256 beforeDep  = depositAsset.allowance(address(bitcoinStrategy), controllerA);
        uint256 beforePool = compositeAsset.allowance(address(bitcoinStrategy), controllerA);

        assertEq(bitcoinStrategy.controllers(address(depositAsset)), controllerA);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
        assertEq(beforeDep,                                          MAX_UINT);
        assertEq(beforePool,                                         MAX_UINT);

        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), controllerA);

        assertEq(depositAsset.allowance(address(bitcoinStrategy),   controllerA),              MAX_UINT);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), controllerA),              MAX_UINT);
        assertEq(depositAsset.allowance(address(bitcoinStrategy),   address(assetController)), 0);
        assertEq(compositeAsset.allowance(address(bitcoinStrategy), address(assetController)), 0);
    }

}
