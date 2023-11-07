// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../../TestBase.sol";

// TODO: Add fuzz tests (random permission level, random entry function, random assets)
contract PoolEntryPermissionTestBase is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    uint256 assets     = 100e6;
    uint256 deadline   = 10e9 seconds;
    uint256 privateKey = 122524312;
    uint256 shares     = 100e6;

    address lp;

    uint8   v;
    bytes32 r;
    bytes32 s;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        lp = vm.addr(privateKey);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets, deadline, privateKey);

        erc20_mint(address(fundsAsset), lp, assets);
        erc20_approve(address(fundsAsset), lp, address(pool), assets);
    }

    modifier withAssertions() {
        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp),            assets);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.totalSupply(), 0);

        assertEq(poolManager.totalAssets(), 0);

        _;

        assertEq(fundsAsset.balanceOf(address(pool)), assets);
        assertEq(fundsAsset.balanceOf(lp),            0);

        assertEq(pool.balanceOf(lp), shares);
        assertEq(pool.totalSupply(), shares);

        assertEq(poolManager.totalAssets(), assets);
    }

}

contract PrivatePermissionTests is PoolEntryPermissionTestBase {

    function test_poolEntry_private_deposit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.deposit(assets, lp);
    }

    function test_poolEntry_private_depositWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.depositWithPermit(assets, lp, deadline, v, r, s);
    }

    function test_poolEntry_private_mint() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.mint(shares, lp);
    }

    function test_poolEntry_private_mintWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);
    }

}

contract FunctionLevelPermissionTests is PoolEntryPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
    }

    function test_poolEntry_functionLevel_deposit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setPoolBitmap(address(poolManager), "P:deposit", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.deposit(assets, lp);
    }

    function test_poolEntry_functionLevel_depositWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setPoolBitmap(address(poolManager), "P:depositWithPermit", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.depositWithPermit(assets, lp, deadline, v, r, s);
    }

    function test_poolEntry_functionLevel_mint() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setPoolBitmap(address(poolManager), "P:mint", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.mint(shares, lp);
    }

    function test_poolEntry_functionLevel_mintWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setPoolBitmap(address(poolManager), "P:mintWithPermit", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);
    }

}

contract PoolLevelPermissionTests is PoolEntryPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
    }

    function test_poolEntry_poolLevel_deposit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.deposit(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.deposit(assets, lp);
    }

    function test_poolEntry_poolLevel_depositWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.depositWithPermit(assets, lp, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.depositWithPermit(assets, lp, deadline, v, r, s);
    }

    function test_poolEntry_poolLevel_mint() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mint(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.mint(shares, lp);
    }

    function test_poolEntry_poolLevel_mintWithPermit() external withAssertions {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);
    }

}

contract PublicPermissionTests is PoolEntryPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), PUBLIC);
    }

    function test_poolEntry_public_deposit() external withAssertions {
        vm.prank(lp);
        pool.deposit(assets, lp);
    }

    function test_poolEntry_public_depositWithPermit() external withAssertions {
        vm.prank(lp);
        pool.depositWithPermit(assets, lp, deadline, v, r, s);
    }

    function test_poolEntry_public_mint() external withAssertions {
        vm.prank(lp);
        pool.mint(shares, lp);
    }

    function test_poolEntry_public_mintWithPermit() external withAssertions {
        vm.prank(lp);
        pool.mintWithPermit(shares, lp, assets, deadline, v, r, s);
    }

}
