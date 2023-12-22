// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPoolPermissionManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract PoolEntryPermissionsFuzzTests is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    address lp1;
    address lp2;

    uint256 deadline   = 50e9 seconds;
    uint256 privateKey = 100;

    uint8   v;
    bytes32 r;
    bytes32 s;

    IPoolPermissionManager ppm;

    function setUp() public virtual override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        allowLender(address(poolManager), address(queueWM));

        lp1 = makeAddr("lp");
        lp2 = vm.addr(privateKey);

        ppm = IPoolPermissionManager(address(poolPermissionManager));
    }

    function testFuzz_poolEntryTests_deposit(
        uint256 permissionLevel,
        uint256 assets,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        assets          = bound(assets,          1,       1e29);

        erc20_mint(address(fundsAsset), lp1, assets);
        erc20_approve(address(fundsAsset), lp1, address(pool), assets);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp1, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp1, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmap(address(poolManager), "P:deposit", poolBitmap)
            : setPoolBitmap(address(poolManager), bytes32(0),  poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp1, "P:deposit")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp1);
            pool.deposit(assets, lp1);
            return;
        }

        assertEq(fundsAsset.balanceOf(lp1),           assets);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.totalSupply(),  0);

        vm.prank(lp1);
        pool.deposit(assets, lp1);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), assets);

        assertEq(pool.balanceOf(lp1), assets);
        assertEq(pool.totalSupply(),  assets);
    }

    function testFuzz_poolEntryTests_depositWithPermit(
        uint256 permissionLevel,
        uint256 assets,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        assets          = bound(assets,          1,       1e29);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), assets, deadline, privateKey);

        erc20_mint(address(fundsAsset), lp2, assets);
        erc20_approve(address(fundsAsset), lp2, address(pool), assets);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp2, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp2, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmap(address(poolManager), "P:depositWithPermit", poolBitmap)
            : setPoolBitmap(address(poolManager), bytes32(0),            poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp2, "P:depositWithPermit")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp2);
            pool.depositWithPermit(assets, lp2, deadline, v, r, s);
            return;
        }

        assertEq(fundsAsset.balanceOf(lp2),           assets);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.totalSupply(),  0);

        vm.prank(lp2);
        pool.depositWithPermit(assets, lp2, deadline, v, r, s);

        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), assets);

        assertEq(pool.balanceOf(lp2), assets);
        assertEq(pool.totalSupply(),  assets);
    }

    function testFuzz_poolEntryTests_mint(
        uint256 permissionLevel,
        uint256 amount,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       1e29);

        erc20_mint(address(fundsAsset), lp1, amount);
        erc20_approve(address(fundsAsset), lp1, address(pool), amount);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp1, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp1, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmap(address(poolManager), "P:mint",   poolBitmap)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp1, "P:mint")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp1);
            pool.mint(amount, lp1);
            return;
        }

        assertEq(fundsAsset.balanceOf(lp1),           amount);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.totalSupply(),  0);

        vm.prank(lp1);
        pool.mint(amount, lp1);

        assertEq(fundsAsset.balanceOf(lp1),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), amount);

        assertEq(pool.balanceOf(lp1), amount);
        assertEq(pool.totalSupply(),  amount);
    }

    function testFuzz_poolEntryTests_mintWithPermit(
        uint256 permissionLevel,
        uint256 amount,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       1e29);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), amount, deadline, privateKey);

        erc20_mint(address(fundsAsset), lp2, amount);
        erc20_approve(address(fundsAsset), lp2, address(pool), amount);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp2, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp2, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmap(address(poolManager), "P:mintWithPermit", poolBitmap)
            : setPoolBitmap(address(poolManager), bytes32(0),         poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp2, "P:mintWithPermit")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp2);
            pool.mintWithPermit(amount, lp2, amount, deadline, v, r, s);
            return;
        }

        assertEq(fundsAsset.balanceOf(lp2),           amount);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.totalSupply(),  0);

        vm.prank(lp2);
        pool.mintWithPermit(amount, lp2, amount, deadline, v, r, s);

        assertEq(fundsAsset.balanceOf(lp2),           0);
        assertEq(fundsAsset.balanceOf(address(pool)), amount);

        assertEq(pool.balanceOf(lp2), amount);
        assertEq(pool.totalSupply(),  amount);
    }

}
