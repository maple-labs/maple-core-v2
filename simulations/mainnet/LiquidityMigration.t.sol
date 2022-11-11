// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { SimulationBase } from "./SimulationBase.sol";

contract LiquidityMigrationTests is SimulationBase {

    function test_liquidityMigration_approach1() external {
        // Nov 4
        setUpLoanV301();

        // Pre-migration steps
        // Nov 4 - Dec 5
        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        // Dec 1
        deployProtocol();

        // Dec 3
        payUpcomingLoans(mavenWethLoans);
        payUpcomingLoans(mavenUsdcLoans);
        payUpcomingLoans(mavenPermissionedLoans);
        payUpcomingLoans(orthogonalLoans);
        payUpcomingLoans(icebreakerLoans);

        // Dec 5
        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);         // 2 hours
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);         // 2 hours
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans); // 2 hours
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);        // 2 hours
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);        // 2 hours

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);

        // Dec 5-7
        mavenWethPoolManager         = deployAndMigratePool(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps);
        mavenUsdcPoolManager         = deployAndMigratePool(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps);
        mavenPermissionedPoolManager = deployAndMigratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);
        orthogonalPoolManager        = deployAndMigratePool(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps);
        icebreakerPoolManager        = deployAndMigratePool(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps);

        // Dec 7
        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));  // 2min

        // Dec 7
        payBackCashLoan(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        payBackCashLoan(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        payBackCashLoan(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        payBackCashLoan(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        payBackCashLoan(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);

        transferPoolDelegate(mavenWethPoolManager,         mavenWethPoolV1.poolDelegate());
        transferPoolDelegate(mavenUsdcPoolManager,         mavenUsdcPoolV1.poolDelegate());
        transferPoolDelegate(mavenPermissionedPoolManager, mavenPermissionedPoolV1.poolDelegate());
        transferPoolDelegate(orthogonalPoolManager,        orthogonalPoolV1.poolDelegate());
        transferPoolDelegate(icebreakerPoolManager,        icebreakerPoolV1.poolDelegate());

        // Dec 8
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        // Dec 8
        deprecatePoolV1(mavenWethPoolV1,         mavenWethRewards,         mavenWethStakeLocker,         125_049.87499e18);
        deprecatePoolV1(mavenUsdcPoolV1,         mavenUsdcRewards,         mavenUsdcStakeLocker,         153.022e18);
        deprecatePoolV1(mavenPermissionedPoolV1, mavenPermissionedRewards, mavenPermissionedStakeLocker, 16.319926286804447168e18);
        deprecatePoolV1(orthogonalPoolV1,        orthogonalRewards,        orthogonalStakeLocker,        175.122243323160822654e18);
        deprecatePoolV1(icebreakerPoolV1,        icebreakerRewards,        icebreakerStakeLocker,        0);

        // Make cover providers withdraw
        // TODO: Move these before and make another function to do all payments
        withdrawCover(mavenUsdcStakeLocker,  mavenUsdcRewards,  mavenUsdcCoverProviders);
        withdrawCover(orthogonalStakeLocker, orthogonalRewards, orthogonalCoverProviders);
    }

}
