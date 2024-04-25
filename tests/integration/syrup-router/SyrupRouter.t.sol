// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../../TestBase.sol";

import { SyrupRouter } from "../../../modules/syrup-router/contracts/SyrupRouter.sol";

contract SyrupRouterTests is TestBase {

    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;

    address liquidityProvider = makeAddr("liquidityProvider");

    bytes32 functionId = "P:deposit";

    uint256 depositAmount = 100_000e6;

    uint256 insufficientBitmap = 0x1;  // 0b0001
    uint256 requiredBitmap     = 0x3;  // 0b0011
    uint256 sufficientBitmap   = 0xB;  // 0b1011
    uint256 zeroBitmap         = 0x0;  // 0b0000

    SyrupRouter public syrupRouter;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        syrupRouter = new SyrupRouter(address(pool));

        allowLender(address(poolManager), address(syrupRouter));
    }

    /**************************************************************************************************************************************/
    /*** Private Pool - Router Tests                                                                                                    ***/
    /**************************************************************************************************************************************/

    function test_route_private_unauthorized() external {
        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_private_insufficientApproval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_private_insufficientAmount() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_private_zeroShares() external {
        allowLender(address(poolManager), liquidityProvider);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_route_private_approval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_private_infiniteApproval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Function Level Pool - Router Tests                                                                                             ***/
    /**************************************************************************************************************************************/

    function test_route_function_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_function_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_function_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_function_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_function_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_route_function_approval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_function_infiniteApproval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_function_allowlisted() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Pool Level Pool - Router Tests                                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_route_pool_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_pool_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_pool_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_pool_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_pool_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_route_pool_approval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_pool_infiniteApproval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_pool_allowlisted() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Public Pool - Router Tests                                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_route_public_insufficientApproval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_public_insufficientAmount() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_route_public_zeroShares() external {
        openPool(address(poolManager));

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_route_public_approval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_route_public_infiniteApproval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

}

