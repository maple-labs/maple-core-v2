// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract PoolTransferPermissionTestBase is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    address caller = makeAddr("caller");
    address from   = makeAddr("from");
    address to     = makeAddr("to");

    uint256 assets = 100e6;
    uint256 shares = 100e6;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        erc20_mint(address(fundsAsset), from, assets);
        erc20_approve(address(fundsAsset), from, address(pool), assets);
        erc20_approve(address(pool), from, caller, shares);

        setLenderAllowlist(address(poolManager), from, true);

        vm.prank(from);
        pool.deposit(assets, from);

        setLenderAllowlist(address(poolManager), from, false);
    }

    modifier withAssertions {
        assertEq(pool.balanceOf(from), shares);
        assertEq(pool.balanceOf(to),   0);

        _;

        assertEq(pool.balanceOf(from), 0);
        assertEq(pool.balanceOf(to),   shares);
    }

}

contract PrivatePermissionTests is PoolTransferPermissionTestBase {

    function test_poolTransfer_private_transfer() external withAssertions {
        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderAllowlist(address(poolManager), from, true);

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderAllowlist(address(poolManager), to, true);

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_private_transferFrom() external withAssertions {
        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderAllowlist(address(poolManager), from, true);

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderAllowlist(address(poolManager), to, true);

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

}

contract FunctionLevelPermissionTests is PoolTransferPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
    }

    function test_poolTransfer_functionLevel_transfer() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transfer", createBitmap([2]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([2, 3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to, createBitmap([2, 3]));

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_functionLevel_transfer_zeroPoolBitmap_zeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transfer", createBitmap([2]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setPoolBitmap(address(poolManager), "P:transfer", 0);

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_functionLevel_transfer_zeroPoolBitmap_nonZeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transfer", createBitmap([2]));

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setPoolBitmap(address(poolManager), "P:transfer", 0);

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_functionLevel_transferFrom() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transferFrom", createBitmap([2]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([2, 3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to, createBitmap([2, 3]));

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

    function test_poolTransfer_functionLevel_transferFrom_zeroPoolBitmap_zeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transferFrom", createBitmap([2]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setPoolBitmap(address(poolManager), "P:transferFrom", 0);

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

    function test_poolTransfer_functionLevel_transferFrom_zeroPoolBitmap_nonZeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), "P:transferFrom", createBitmap([2]));

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setPoolBitmap(address(poolManager), "P:transferFrom", 0);

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

}

contract PoolLevelPermissionTests is PoolTransferPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
    }

    function test_poolTransfer_poolLevel_transfer() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([2, 3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to, createBitmap([2, 3]));

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_poolLevel_transfer_zeroPoolBitmap_zeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setPoolBitmap(address(poolManager), bytes32(0), 0);

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_poolLevel_transfer_zeroPoolBitmap_nonZeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(from);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transfer(to, shares);

        setPoolBitmap(address(poolManager), bytes32(0), 0);

        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_poolLevel_transferFrom() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([2, 3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to, createBitmap([2, 3]));

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

    function test_poolTransfer_poolLevel_transferFrom_zeroPoolBitmap_zeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setPoolBitmap(address(poolManager), bytes32(0), 0);

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

    function test_poolTransfer_poolLevel_transferFrom_zeroPoolBitmap_nonZeroLenderBitmaps() external withAssertions {
        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, from, createBitmap([1]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, to,   createBitmap([3]));

        vm.prank(caller);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.transferFrom(from, to, shares);

        setPoolBitmap(address(poolManager), bytes32(0), 0);

        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

}

contract PublicPermissionTests is PoolTransferPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), PUBLIC);
    }

    function test_poolTransfer_public_transfer() external withAssertions {
        vm.prank(from);
        pool.transfer(to, shares);
    }

    function test_poolTransfer_public_transferFrom() external withAssertions {
        vm.prank(caller);
        pool.transferFrom(from, to, shares);
    }

}
