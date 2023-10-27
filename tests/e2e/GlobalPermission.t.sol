// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract GlobalPermissionTests is TestBase {

    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;

    address integrator    = makeAddr("integrator");
    address lender        = makeAddr("lender");
    address poolDelegate2 = makeAddr("poolDelegate2");

    address pool1;
    address pool2;

    address poolManager1;
    address poolManager2;

    address withdrawalManager1;
    address withdrawalManager2;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _setTreasury();

        start = block.timestamp;

        // Add another pool delegate.
        vm.prank(governor);
        globals.setValidPoolDelegate(poolDelegate2, true);

        // Create two pools.
        ( pool1, poolManager1, withdrawalManager1 ) = _createPool(start, 1 weeks, 2 days);
        ( pool2, poolManager2, withdrawalManager2 ) = _createPool(poolDelegate2, "Maple Pool 2");

        // Active both pools.
        activatePoolManager(poolManager1);
        activatePoolManager(poolManager2);

        // Set pool permission levels to use bitmaps.
        setPoolPermissionLevel(poolManager1, POOL_LEVEL);
        setPoolPermissionLevel(poolManager2, FUNCTION_LEVEL);

        // Whitelist contracts to enable redemption workflow.
        setLenderAllowlist(poolManager1, poolManager1,       true);
        setLenderAllowlist(poolManager1, withdrawalManager1, true);
        setLenderAllowlist(poolManager2, poolManager2,       true);
        setLenderAllowlist(poolManager2, withdrawalManager2, true);

        // Set pool bitmaps for each pool.
        setPoolBitmap(poolManager1, "",                createBitmap([1]));
        setPoolBitmap(poolManager2, "P:transfer",      createBitmap([1]));
        setPoolBitmap(poolManager2, "P:transferFrom",  createBitmap([1]));
        setPoolBitmap(poolManager2, "P:deposit",       createBitmap([1, 3]));
        setPoolBitmap(poolManager2, "P:requestRedeem", createBitmap([1, 3]));
        setPoolBitmap(poolManager2, "P:redeem",        createBitmap([1, 3]));

        // Set the lender bitmap.
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, lender,     createBitmap([1, 3]));
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, integrator, createBitmap([1, 3]));

        // Enable manual withdrawals for the integrator.
        setManualWithdrawal(poolManager2, integrator, true);
    }

    function test_e2e_globalPermission() external {
        deposit(pool1, lender,     1_250_000e6);
        deposit(pool1, integrator, 1_000_000e6);
        deposit(pool2, lender,     1_000_000e6);
        deposit(pool2, integrator, 2_000_000e6);

        vm.warp(start + 1 weeks);
        requestRedeem(pool1, lender,     250_000e6);
        requestRedeem(pool1, integrator, 500_000e6);

        assertEq(fundsAsset.balanceOf(lender),     0);
        assertEq(fundsAsset.balanceOf(integrator), 0);

        assertEq(IWithdrawalManagerCyclical(withdrawalManager1).lockedShares(lender),     250_000e6);
        assertEq(IWithdrawalManagerCyclical(withdrawalManager1).lockedShares(integrator), 500_000e6);

        vm.warp(start + 2 weeks);
        requestRedeem(pool2, lender,     500_000e6);
        requestRedeem(pool2, integrator, 1_500_000e6);

        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(lender),     0);
        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(integrator), 0);

        vm.warp(start + 3 weeks);
        redeem(pool1, lender,     250_000e6);
        redeem(pool1, integrator, 500_000e6);

        assertEq(fundsAsset.balanceOf(lender),     250_000e6);
        assertEq(fundsAsset.balanceOf(integrator), 500_000e6);

        assertEq(IWithdrawalManagerCyclical(withdrawalManager1).lockedShares(lender),     0);
        assertEq(IWithdrawalManagerCyclical(withdrawalManager1).lockedShares(integrator), 0);

        vm.warp(start + 4 weeks);
        processRedemptions(pool2, 1_750_000e6);

        assertEq(fundsAsset.balanceOf(lender),     250_000e6 + 500_000e6);
        assertEq(fundsAsset.balanceOf(integrator), 500_000e6 + 0);

        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(lender),     0);
        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(integrator), 1_250_000e6);

        vm.warp(start + 5 weeks);
        redeem(pool2, integrator, 1_250_000e6);

        assertEq(fundsAsset.balanceOf(lender),     250_000e6 + 500_000e6);
        assertEq(fundsAsset.balanceOf(integrator), 500_000e6 + 1_250_000e6);

        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(lender),     0);
        assertEq(IWithdrawalManagerQueue(withdrawalManager2).lockedShares(integrator), 0);
    }

}
