// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolPermissionManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract PoolTransferPermissionsFuzzTests is TestBase {

    address owner     = makeAddr("owner");
    address recipient = makeAddr("recipient");
    address user      = makeAddr("user");

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    uint256 constant MAX_AMOUNT = 1e29;

    address[] lenders = [owner, recipient];

    uint256[] poolBitmaps;

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

        ppm = IPoolPermissionManager(address(poolPermissionManager));
    }

    function setBitmaps(bytes32 functionId_, uint256 bitMap_) internal {
        functionIds.push(functionId_);
        poolBitmaps.push(bitMap_);
    }

    function testFuzz_poolTransfer(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 ownerBitmap,
        uint256 recipientBitmap,
        uint256 amount,
        bool    isOwnerAllowed,
        bool    isRecipientAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setBitmaps("P:deposit",  poolBitmap);
        setBitmaps("P:transfer", poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), owner,     isOwnerAllowed);
            setLenderAllowlist(address(poolManager), recipient, isRecipientAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, owner,     ownerBitmap);
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, recipient, recipientBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lenders, "P:transfer")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(owner);
            pool.transfer(recipient, amount);
            return;
        }

        deposit(address(pool), owner, amount);

        assertEq(pool.balanceOf(owner),     amount);
        assertEq(pool.balanceOf(recipient), 0);

        vm.prank(owner);
        pool.transfer(recipient, amount);

        assertEq(pool.balanceOf(owner),     0);
        assertEq(pool.balanceOf(recipient), amount);
    }

    function testFuzz_poolTransferFrom(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 ownerBitmap,
        uint256 recipientBitmap,
        uint256 amount,
        bool    isOwnerAllowed,
        bool    isRecipientAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setBitmaps("P:deposit",      poolBitmap);
        setBitmaps("P:transferFrom", poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), owner,     isOwnerAllowed);
            setLenderAllowlist(address(poolManager), recipient, isRecipientAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, owner,     ownerBitmap);
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, recipient, recipientBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lenders, "P:transferFrom")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(user);
            pool.transferFrom(owner, recipient, amount);
            return;
        }

        deposit(address(pool), owner, amount);

        erc20_approve(address(pool), owner, user, amount);

        assertEq(pool.balanceOf(owner),     amount);
        assertEq(pool.balanceOf(recipient), 0);

        vm.prank(user);
        pool.transferFrom(owner, recipient, amount);

        assertEq(pool.balanceOf(owner),     0);
        assertEq(pool.balanceOf(recipient), amount);
    }

}
