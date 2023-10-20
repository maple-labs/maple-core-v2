// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../TestBase.sol";

// TODO: Add fuzz tests (random permission level, random entry function, random assets)
contract PoolExitPermissionTestBase is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    address lp = makeAddr("lp");

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

        erc20_mint(address(fundsAsset), lp, assets);
        erc20_approve(address(fundsAsset), lp, address(pool), assets);

        setLenderAllowlist(address(poolManager), address(lp),          true);
        setLenderAllowlist(address(poolManager), address(poolManager), true);
        setLenderAllowlist(address(poolManager), address(cyclicalWM),  true);

        vm.prank(lp);
        pool.deposit(assets, lp);

        setLenderAllowlist(address(poolManager), address(lp), false);
    }

}

contract PrivatePermissionTests is PoolExitPermissionTestBase {

    function test_poolExit_private_requestWithdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);
    }

    function test_poolExit_private_withdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function test_poolExit_private_requestRedeem() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);
    }

    function test_poolExit_private_removeShares() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        vm.prank(lp);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
    }

    function test_poolExit_private_redeem() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setLenderAllowlist(address(poolManager), lp, true);

        assertEq(fundsAsset.balanceOf(address(pool)), assets);
        assertEq(fundsAsset.balanceOf(lp),            0);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        assertEq(poolManager.totalAssets(), assets);

        vm.prank(lp);
        pool.redeem(shares, lp, lp);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp),            assets);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        assertEq(poolManager.totalAssets(), 0);
    }

}

contract FunctionLevelPermissionTests is PoolExitPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
    }

    function test_poolExit_functionLevel_requestWithdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setPoolBitmap(address(poolManager), "P:requestWithdraw", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);
    }

    function test_poolExit_functionLevel_withdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setPoolBitmap(address(poolManager), "P:withdraw", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function test_poolExit_functionLevel_requestRedeem() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setPoolBitmap(address(poolManager), "P:requestRedeem", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);
    }

    function test_poolExit_functionLevel_removeShares() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setPoolBitmap(address(poolManager), "P:removeShares", createBitmap([2]));
        setPoolBitmap(address(poolManager), "P:transfer",     createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        vm.prank(lp);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
    }

    function test_poolExit_functionLevel_redeem() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setPoolBitmap(address(poolManager), "P:redeem",   createBitmap([2]));
        setPoolBitmap(address(poolManager), "P:transfer", createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(fundsAsset.balanceOf(address(pool)), assets);
        assertEq(fundsAsset.balanceOf(lp),            0);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        assertEq(poolManager.totalAssets(), assets);

        vm.prank(lp);
        pool.redeem(shares, lp, lp);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp),            assets);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        assertEq(poolManager.totalAssets(), 0);
    }

}

contract PoolLevelPermissionTests is PoolExitPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
    }

    function test_poolExit_poolLevel_requestWithdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestWithdraw(assets, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);
    }

    function test_poolExit_poolLevel_withdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.withdraw(assets, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        vm.prank(lp);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function test_poolExit_poolLevel_requestRedeem() external {
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.requestRedeem(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);
    }

    function test_poolExit_poolLevel_removeShares() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(shares, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(pool.balanceOf(lp),                 0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        vm.prank(lp);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp),                 shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
    }

    function test_poolExit_poolLevel_redeem() external {
        setLenderAllowlist(address(poolManager), lp, true);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        setLenderAllowlist(address(poolManager), lp, false);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([1]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setPoolBitmap(address(poolManager), bytes32(0), createBitmap([2]));

        vm.prank(lp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.redeem(shares, lp, lp);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lp, createBitmap([2, 3]));

        assertEq(fundsAsset.balanceOf(address(pool)), assets);
        assertEq(fundsAsset.balanceOf(lp),            0);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        assertEq(poolManager.totalAssets(), assets);

        vm.prank(lp);
        pool.redeem(shares, lp, lp);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp),            assets);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        assertEq(poolManager.totalAssets(), 0);
    }

}

contract PublicPermissionTests is PoolExitPermissionTestBase {

    function setUp() public virtual override {
        super.setUp();

        setPoolPermissionLevel(address(poolManager), PUBLIC);
    }

    function test_poolExit_public_requestWithdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(assets, lp);
    }

    function test_poolExit_public_withdraw() external {
        vm.prank(lp);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets, lp, lp);
    }

    function test_poolExit_public_requestRedeem() external {
        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);
    }

    function test_poolExit_public_removeShares() external {
        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        pool.removeShares(shares, lp);

        assertEq(pool.balanceOf(lp),                  shares);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
    }

    function test_poolExit_public_redeem() external {
        vm.prank(lp);
        pool.requestRedeem(shares, lp);

        assertEq(fundsAsset.balanceOf(address(pool)), assets);
        assertEq(fundsAsset.balanceOf(lp),            0);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), shares);

        assertEq(poolManager.totalAssets(), assets);

        vm.warp(start + 2 weeks);
        vm.prank(lp);
        pool.redeem(shares, lp, lp);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lp),            assets);

        assertEq(pool.balanceOf(lp),                  0);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        assertEq(poolManager.totalAssets(), 0);
    }

}
