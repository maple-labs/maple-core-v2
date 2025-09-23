// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20Like } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterSetAssetControllerTests is SyrupBitcoinTestBase {

    address newAssetController;

    function setUp() public virtual override {
        super.setUp();

        newAssetController = makeAddr("new_asset_controller");

        vm.startPrank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", address(newAssetController), true);
        vm.stopPrank();
    }

    function test_setAssetController_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_notAuthorized() external {
        vm.expectRevert("SBR:NOT_GOV_OR_OPS_ADMIN");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_invalidAsset() external {
        vm.prank(governor);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", address(depositAsset), false);

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:INVALID_ASSET");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_assetApproveFail() external {
        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(assetController));

        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSelector(IERC20Like.approve.selector, address(assetController), 0),
            abi.encode(false)
        );

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:ASSET_APPROVE_FAIL");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_poolAssetApproveFail() external {
        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(assetController));

        vm.mockCall(
            pool.asset(),
            abi.encodeWithSelector(IERC20Like.approve.selector, address(assetController), 0),
            abi.encode(false)
        );

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:POOL_ASSET_APPROVE_FAIL");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_invalidController() external {
        address invalidController = makeAddr("invalid_Controller");

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:INVALID_CONTROLLER");
        bitcoinRouter.setAssetController(address(depositAsset), invalidController);
    }

    function test_setAssetController_revert_newController_noOldController_assetApproveFail() external {
        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(0));

        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSelector(IERC20Like.approve.selector, address(newAssetController), type(uint256).max),
            abi.encode(false)
        );

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:ASSET_APPROVE_FAIL");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_revert_newController_noOldController_poolAssetApproveFail() external {
        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(0));

        vm.mockCall(
            pool.asset(),
            abi.encodeWithSelector(IERC20Like.approve.selector, address(newAssetController), type(uint256).max),
            abi.encode(false)
        );

        vm.prank(governor);
        vm.expectRevert("SBR:SAC:POOL_ASSET_APPROVE_FAIL");
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));
    }

    function test_setAssetController_success() external {
        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(assetController));

        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));

        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(newAssetController));

        assertEq(IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(assetController)), 0);
        assertEq(IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(assetController)), 0);

        assertEq(IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(newAssetController)), type(uint256).max);
        assertEq(IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(newAssetController)), type(uint256).max);
    }

    function test_setAssetController_success_removeController_zeroAddress_revokesApprovals() external {
        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));

        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(newAssetController));

        assertEq(IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(newAssetController)), type(uint256).max);
        assertEq(IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(newAssetController)), type(uint256).max);

        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(0));

        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(0));

        assertEq(IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(newAssetController)), 0);
        assertEq(IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(newAssetController)), 0);
    }

    function test_setAssetController_success_idempotent_setSameController_keepsMaxApprovals() external {
        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));

        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(newAssetController));

        uint256 beforeDep  = IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(newAssetController));
        uint256 beforePool = IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(newAssetController));
        assertEq(beforeDep,  type(uint256).max);
        assertEq(beforePool, type(uint256).max);

        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(newAssetController));

        assertEq(bitcoinRouter.assetController(address(depositAsset)), address(newAssetController));

        assertEq(IERC20Like(address(depositAsset)).allowance(address(bitcoinRouter), address(newAssetController)), type(uint256).max);
        assertEq(IERC20Like(pool.asset()).allowance(address(bitcoinRouter),          address(newAssetController)), type(uint256).max);
    }

}
