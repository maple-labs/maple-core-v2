// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LifecycleBase } from "./LifecycleBase.sol";

contract Lifecycle is LifecycleBase {

    function setUp() external {
        performEntireMigration();
    }

    function test_simpleLifecycle() external {
        payOffAllLoanWhenDue();
        exitFromAllPoolsWhenPossible();
        withdrawAllPoolCoverFromAllPools();
    }

    // function test_complexLifecycle(uint256 seed) external {
    //     performComplexLifecycle(mavenPermissionedPoolManager, mavenPermissionedLoans, mavenPermissionedLps, seed);
    //     performComplexLifecycle(mavenUsdcPoolManager,         mavenUsdcLoans,         mavenUsdcLps,         seed);
    //     performComplexLifecycle(mavenWethPoolManager,         mavenWethLoans,         mavenWethLps,         seed);
    //     performComplexLifecycle(orthogonalPoolManager,        orthogonalLoans,        orthogonalLps,        seed);
    //     performComplexLifecycle(icebreakerPoolManager,        icebreakerLoans,        icebreakerLps,        seed);
    // }

}
