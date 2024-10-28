// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolPermissionManager }  from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract PoolExitPermissionsFuzzTests is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    uint256 constant MAX_AMOUNT = 1e29;

    address lp       = makeAddr("lp");
    address receiver = makeAddr("receiver");

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
        allowLender(address(poolManager), address(poolManager));

        ppm = IPoolPermissionManager(address(poolPermissionManager));
    }

    function setBitmaps(bytes32 functionId_, uint256 bitMap_) internal {
        functionIds.push(functionId_);
        poolBitmaps.push(bitMap_);
    }

    function testFuzz_poolExit_redeem(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        uint256 amount,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setManualWithdrawal(address(poolManager), lp, true);

        setBitmaps("P:deposit",       poolBitmap);
        setBitmaps("P:requestRedeem", poolBitmap);
        setBitmaps("P:redeem",        poolBitmap);
        setBitmaps("P:transfer",      poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp, "P:redeem")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp);
            pool.redeem(amount, receiver, lp);
            return;
        }

        deposit(address(pool), lp, amount);

        requestRedeem(address(pool), lp, amount);

        processRedemptions(address(pool), amount);  // assets <> shares conversion rate 1:1 due to single LP

        assertEq(fundsAsset.balanceOf(receiver),      0);
        assertEq(fundsAsset.balanceOf(address(pool)), amount);

        assertEq(pool.balanceOf(lp),               0);
        assertEq(pool.balanceOf(address(queueWM)), amount);
        assertEq(pool.totalSupply(),               amount);

        vm.prank(lp);
        pool.redeem(amount, receiver, lp);

        assertEq(fundsAsset.balanceOf(receiver),      amount);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.balanceOf(lp),               0);
        assertEq(pool.balanceOf(address(queueWM)), 0);
        assertEq(pool.totalSupply(),               0);
    }

    function testFuzz_poolExit_removeShares(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        uint256 depositAmount,
        uint256 sharesToRemove,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        depositAmount   = bound(depositAmount,   1,       MAX_AMOUNT);
        sharesToRemove  = bound(sharesToRemove,  1,       depositAmount);

        setBitmaps("P:deposit",       poolBitmap);
        setBitmaps("P:requestRedeem", poolBitmap);
        setBitmaps("P:removeShares",  poolBitmap);
        setBitmaps("P:transfer",      poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp, "P:removeShares")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp);
            pool.removeShares(sharesToRemove, lp);
            return;
        }

        deposit(address(pool), lp, depositAmount);

        requestRedeem(address(pool), lp, depositAmount);

        assertEq(pool.balanceOf(lp),               0);
        assertEq(pool.balanceOf(address(queueWM)), depositAmount);
        assertEq(pool.totalSupply(),               depositAmount);

        vm.prank(lp);
        pool.removeShares(sharesToRemove, lp);

        assertEq(pool.balanceOf(lp),               sharesToRemove);
        assertEq(pool.balanceOf(address(queueWM)), depositAmount - sharesToRemove);
        assertEq(pool.totalSupply(),               depositAmount);
    }

    function testFuzz_poolExit_requestRedeem(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        uint256 amount,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setBitmaps("P:deposit",       poolBitmap);
        setBitmaps("P:requestRedeem", poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp, "P:requestRedeem")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp);
            pool.requestRedeem(amount, lp);
            return;
        }

        deposit(address(pool), lp, amount);

        assertEq(pool.balanceOf(lp),               amount);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        vm.prank(lp);
        pool.requestRedeem(amount, lp);

        assertEq(pool.balanceOf(lp),               0);
        assertEq(pool.balanceOf(address(queueWM)), amount);
    }

    function testFuzz_poolExit_requestWithdraw(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        uint256 amount,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setBitmaps("P:deposit",         poolBitmap);
        setBitmaps("P:requestWithdraw", poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if(permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp, "P:requestWithdraw")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp);
            pool.requestWithdraw(amount, lp);
            return;
        }

        deposit(address(pool), lp, amount);

        assertEq(pool.balanceOf(lp), amount);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        vm.prank(lp);
        pool.requestWithdraw(amount, lp);
    }

    function testFuzz_poolExit_withdraw(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        uint256 amount,
        bool    isAllowed
    ) external {
        permissionLevel = bound(permissionLevel, PRIVATE, PUBLIC);
        amount          = bound(amount,          1,       MAX_AMOUNT);

        setBitmaps("P:deposit",  poolBitmap);
        setBitmaps("P:withdraw", poolBitmap);

        setPoolPermissionLevel(address(poolManager), permissionLevel);

        if (permissionLevel == PRIVATE) {
            setLenderAllowlist(address(poolManager), lp, isAllowed);
        } else {
            setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, lenderBitmap);

            permissionLevel == FUNCTION_LEVEL
            ? setPoolBitmaps(address(poolManager), functionIds, poolBitmaps)
            : setPoolBitmap(address(poolManager), bytes32(0), poolBitmap);
        }

        if (!ppm.hasPermission(address(poolManager), lp, "P:withdraw")) {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
            vm.prank(lp);
            pool.withdraw(amount, receiver, lp);
            return;
        }

        deposit(address(pool), lp, amount);

        assertEq(pool.balanceOf(lp), amount);

        vm.prank(lp);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(amount, receiver, lp);
    }

}
