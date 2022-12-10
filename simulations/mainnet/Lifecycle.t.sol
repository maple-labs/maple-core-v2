// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { LifecycleBase } from "./LifecycleBase.sol";

contract Lifecycle is LifecycleBase {

    function test_simpleLifecycle() external {
        int256[][5] memory balances = getStartingFundsAssetBalances();

        performEntireMigration();

        performAdditionalGlobalsSettings();

        simpleLifecycle();

        writeAllBalanceChanges("./output/simple-lifecycle", balances);
    }

    // function test_complexLifecycle_icebreaker() external {
    //     migrateAllPools();
    //     performComplexLifecycle(icebreakerPoolManager, icebreakerLoans, icebreakerLps, 0);
    // }

    // function test_complexLifecycle_mavenPermissioned() external {
    //     migrateAllPools();
    //     performComplexLifecycle(mavenPermissionedPoolManager, mavenPermissionedLoans, mavenPermissionedLps, 0);
    // }

    // function test_complexLifecycle_mavenUsdc() external {
    //     int256[] memory balances = getBalances(USDC, mavenUsdcLps);

    //     migrateAllPools();
    //     performComplexLifecycle(mavenUsdcPoolManager, mavenUsdcLoans, mavenUsdcLps, 2);

    //     makeDir("./output/complex-lifecycle");
    //     writeAllBalanceChanges("./output/complex-lifecycle/mavenUsdc-lp-balance-changes.csv", mavenUsdcLps, getBalanceChanges(USDC, mavenUsdcLps, balances));
    // }

    // function test_complexLifecycle_mavenWeth() external {
    //     migrateAllPools();
    //     performComplexLifecycle(mavenWethPoolManager, mavenWethLoans, mavenWethLps, 0);
    // }

    // function test_complexLifecycle_orthogonal() external {
    //     migrateAllPools();
    //     performComplexLifecycle(orthogonalPoolManager, orthogonalLoans, orthogonalLps, 0);
    // }

}
