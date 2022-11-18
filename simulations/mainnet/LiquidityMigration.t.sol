// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { SimulationBase } from "./SimulationBase.sol";

contract LiquidityMigrationTests is SimulationBase {

    function test_liquidityMigration_complete() external {
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
        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        // Dec 5
        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);         // 2 hours
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);         // 2 hours
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans); // 2 hours
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);        // 2 hours
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);        // 2 hours

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);

        // Dec 5-7
        mavenWethPoolManager         = deployAndMigratePool(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePool(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePool(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePool(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);

        compareLpPositions(mavenWethPoolV1,         mavenWethPoolManager.pool(),         mavenWethLps);
        compareLpPositions(mavenUsdcPoolV1,         mavenUsdcPoolManager.pool(),         mavenUsdcLps);
        compareLpPositions(mavenPermissionedPoolV1, mavenPermissionedPoolManager.pool(), mavenPermissionedLps);
        compareLpPositions(orthogonalPoolV1,        orthogonalPoolManager.pool(),        orthogonalLps);
        compareLpPositions(icebreakerPoolV1,        icebreakerPoolManager.pool(),        icebreakerLps);

        // Dec 7
        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));  // 2min

        // Dec 7
        payBackCashLoan(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        payBackCashLoan(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        payBackCashLoan(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        payBackCashLoan(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        payBackCashLoan(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);

        upgradeLoansToV401(mavenWethLoans);
        upgradeLoansToV401(mavenUsdcLoans);
        upgradeLoansToV401(mavenPermissionedLoans);
        upgradeLoansToV401(orthogonalLoans);
        upgradeLoansToV401(icebreakerLoans);

        transferPoolDelegate(mavenWethPoolManager,         finalPDs[address(mavenWethPoolV1)]);
        transferPoolDelegate(mavenUsdcPoolManager,         finalPDs[address(mavenUsdcPoolV1)]);
        transferPoolDelegate(mavenPermissionedPoolManager, finalPDs[address(mavenPermissionedPoolV1)]);
        transferPoolDelegate(orthogonalPoolManager,        finalPDs[address(orthogonalPoolV1)]);
        transferPoolDelegate(icebreakerPoolManager,        finalPDs[address(icebreakerPoolV1)]);

        // Dec 8
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        // Dec 8
        deprecatePoolV1(mavenWethPoolV1,         mavenWethRewards,         mavenWethStakeLocker,         125_049.87499e18);
        deprecatePoolV1(mavenUsdcPoolV1,         mavenUsdcRewards,         mavenUsdcStakeLocker,         153.022e18);
        deprecatePoolV1(mavenPermissionedPoolV1, mavenPermissionedRewards, mavenPermissionedStakeLocker, 16.319926286804447168e18);
        deprecatePoolV1(orthogonalPoolV1,        orthogonalRewards,        orthogonalStakeLocker,        175.122243323160822654e18);
        deprecatePoolV1(icebreakerPoolV1,        icebreakerRewards,        icebreakerStakeLocker,        104.254119288711119987e18);

        handleCoverProviderEdgeCase();

        // Make cover providers withdraw
        withdrawCover(mavenWethStakeLocker,         mavenWethRewards,         mavenWethCoverProviders);
        withdrawCover(mavenPermissionedStakeLocker, mavenPermissionedRewards, mavenPermissionedCoverProviders);
        withdrawCover(icebreakerStakeLocker,        icebreakerRewards,        icebreakerCoverProviders);
        withdrawCover(mavenUsdcStakeLocker,         mavenUsdcRewards,         mavenUsdcCoverProviders);
        withdrawCover(orthogonalStakeLocker,        orthogonalRewards,        orthogonalCoverProviders);

        // PoolV2 Lifecycle start
        depositCover(mavenWethPoolManager,         750e18);
        depositCover(mavenUsdcPoolManager,         1_000_000e6);
        depositCover(mavenPermissionedPoolManager, 1_750_000e6);
        depositCover(orthogonalPoolManager,        2_500_000e6);
        depositCover(icebreakerPoolManager,        500_000e6);

        increaseLiquidityCap(mavenWethPoolManager,         100_000e18);
        increaseLiquidityCap(mavenUsdcPoolManager,         100_000_000e6);
        increaseLiquidityCap(mavenPermissionedPoolManager, 100_000_000e6);
        increaseLiquidityCap(orthogonalPoolManager,        100_000_000e6);
        increaseLiquidityCap(icebreakerPoolManager,        100_000_000e6);

        makeDeposit(mavenWethPoolManager,         100e18);
        makeDeposit(mavenUsdcPoolManager,         100_000e6);
        makeDeposit(mavenPermissionedPoolManager, 100_000e6);
        makeDeposit(orthogonalPoolManager,        100_000e6);
        makeDeposit(icebreakerPoolManager,        100_000e6);
    }

}

contract LiquidityMigrationRollbackFrozenPoolTests is SimulationBase {

    function setUp() external {
        setUpLoanV301();

        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        deployProtocol();

        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshotted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_frozenPool_mavenWeth() external {
        snapshotPoolState(mavenWethPoolV1);

        freezePoolV1(mavenWethPoolV1, mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_frozenPool_mavenPermissioned() external {
        snapshotPoolState(mavenPermissionedPoolV1);

        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_frozenPool_mavenUsdc() external {
        snapshotPoolState(mavenUsdcPoolV1);

        freezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_frozenPool_orthogonal() external {
        snapshotPoolState(orthogonalPoolV1);

        freezePoolV1(orthogonalPoolV1, orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_frozenPool_icebreaker() external {
        snapshotPoolState(icebreakerPoolV1);

        freezePoolV1(icebreakerPoolV1, icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_frozenPool_allPools() external {
        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);

        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);

        unfreezePoolV1(mavenWethPoolV1,         mavenWethLoans,         35_000e18);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);
        unfreezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         350_000_000e6);
        unfreezePoolV1(orthogonalPoolV1,        orthogonalLoans,        450_000_000e6);
        unfreezePoolV1(icebreakerPoolV1,        icebreakerLoans,        300_000_000e6);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertPoolMatchesSnapshotted(icebreakerPoolV1);

        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

}

contract LiquidityMigrationRollbackTransferLoansTests is SimulationBase {

    function setUp() external {
        setUpLoanV301();

        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        deployProtocol();

        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);

        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);

        storeOriginalLoanLender(mavenWethLoans);
        storeOriginalLoanLender(mavenUsdcLoans);
        storeOriginalLoanLender(mavenPermissionedLoans);
        storeOriginalLoanLender(orthogonalLoans);
        storeOriginalLoanLender(icebreakerLoans);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);
    }

    function test_rollback_transferLoans_mavenWethPool() external {
        mavenWethPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0), mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_transferLoans_mavenUsdcPool() external {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0), mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_transferLoans_mavenPermissionedPool() external {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_transferLoans_orthogonalPool() external {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0), orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_transferLoans_icebreakerPool() external {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0), icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_transferLoans_allPools() external {
        mavenWethPoolManager         = deployAndMigratePoolUpToLoanManagerUpgrade(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePoolUpToLoanManagerUpgrade(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePoolUpToLoanManagerUpgrade(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePoolUpToLoanManagerUpgrade(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0),         mavenWethLoans);
        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0),         mavenUsdcLoans);
        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0),        orthogonalLoans);
        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0),        icebreakerLoans);

        unfreezePoolV1(mavenWethPoolV1,         mavenWethLoans,         35_000e18);
        unfreezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         350_000_000e6);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);
        unfreezePoolV1(orthogonalPoolV1,        orthogonalLoans,        450_000_000e6);
        unfreezePoolV1(icebreakerPoolV1,        icebreakerLoans,        300_000_000e6);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertPoolMatchesSnapshotted(icebreakerPoolV1);

        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

}

contract LiquidityMigrationRollbackFromUpgradedLoanManagerTests is SimulationBase {

    function setUp() external {
        setUpLoanV301();

        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        deployProtocol();

        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);

        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);

        storeOriginalLoanLender(mavenWethLoans);
        storeOriginalLoanLender(mavenUsdcLoans);
        storeOriginalLoanLender(mavenPermissionedLoans);
        storeOriginalLoanLender(orthogonalLoans);
        storeOriginalLoanLender(icebreakerLoans);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);
    }

    function test_rollback_upgradedLoanManager_mavenWethPool() external {
        mavenWethPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        setLoanTransferAdmin(mavenWethPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0), mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedLoanManager_mavenUsdcPool() external {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        setLoanTransferAdmin(mavenUsdcPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0), mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedLoanManager_mavenPermissionedPool() external {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        setLoanTransferAdmin(mavenPermissionedPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedLoanManager_orthogonalPool() external {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        setLoanTransferAdmin(orthogonalPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0), orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedLoanManager_icebreakerPool() external {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        setLoanTransferAdmin(icebreakerPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0), icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedLoanManager_allPools() external {
        mavenWethPoolManager         = deployAndMigratePoolUpToLoanUpgrade(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePoolUpToLoanUpgrade(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePoolUpToLoanUpgrade(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePoolUpToLoanUpgrade(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);

        setLoanTransferAdmin(mavenWethPoolManager);
        setLoanTransferAdmin(mavenUsdcPoolManager);
        setLoanTransferAdmin(mavenPermissionedPoolManager);
        setLoanTransferAdmin(orthogonalPoolManager);
        setLoanTransferAdmin(icebreakerPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0),         mavenWethLoans);
        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0),         mavenUsdcLoans);
        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0),        orthogonalLoans);
        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0),        icebreakerLoans);

        unfreezePoolV1(mavenWethPoolV1,         mavenWethLoans,         35_000e18);
        unfreezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         350_000_000e6);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);
        unfreezePoolV1(orthogonalPoolV1,        orthogonalLoans,        450_000_000e6);
        unfreezePoolV1(icebreakerPoolV1,        icebreakerLoans,        300_000_000e6);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertPoolMatchesSnapshotted(icebreakerPoolV1);

        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

}

contract LiquidityMigrationRollbackFromUpgradedV4LoanTests is SimulationBase {

    function setUp() external {
        setUpLoanV301();

        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        deployProtocol();

        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);

        freezePoolV1(mavenWethPoolV1,         mavenWethLoans);
        freezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        freezePoolV1(orthogonalPoolV1,        orthogonalLoans);
        freezePoolV1(icebreakerPoolV1,        icebreakerLoans);

        storeOriginalLoanLender(mavenWethLoans);
        storeOriginalLoanLender(mavenUsdcLoans);
        storeOriginalLoanLender(mavenPermissionedLoans);
        storeOriginalLoanLender(orthogonalLoans);
        storeOriginalLoanLender(icebreakerLoans);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);
    }

    function test_rollback_upgradedV4Loans_mavenWethPool() external {
        mavenWethPoolManager = deployAndMigratePool(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(mavenWethLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(mavenWethPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0), mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedV4Loans_mavenUsdcPool() external {
        mavenUsdcPoolManager = deployAndMigratePool(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(mavenUsdcLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(mavenUsdcPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0), mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedV4Loans_mavenPermissionedPool() external {
        mavenPermissionedPoolManager = deployAndMigratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(mavenPermissionedLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(mavenPermissionedPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedV4Loans_orthogonalPool() external {
        orthogonalPoolManager = deployAndMigratePool(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(orthogonalLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(orthogonalPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0), orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedV4Loans_icebreakerPool() external {
        icebreakerPoolManager = deployAndMigratePool(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(icebreakerLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(icebreakerPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0), icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedV4Loans_allPools() external {
        mavenWethPoolManager         = deployAndMigratePool(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePool(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePool(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePool(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(mavenWethLoans);
        downgradeLoans400To302(mavenUsdcLoans);
        downgradeLoans400To302(mavenPermissionedLoans);
        downgradeLoans400To302(orthogonalLoans);
        downgradeLoans400To302(icebreakerLoans);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV1));

        setLoanTransferAdmin(mavenWethPoolManager);
        setLoanTransferAdmin(mavenUsdcPoolManager);
        setLoanTransferAdmin(mavenPermissionedPoolManager);
        setLoanTransferAdmin(orthogonalPoolManager);
        setLoanTransferAdmin(icebreakerPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0),         mavenWethLoans);
        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0),         mavenUsdcLoans);
        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0),        orthogonalLoans);
        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0),        icebreakerLoans);

        unfreezePoolV1(mavenWethPoolV1,         mavenWethLoans,         35_000e18);
        unfreezePoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         350_000_000e6);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);
        unfreezePoolV1(orthogonalPoolV1,        orthogonalLoans,        450_000_000e6);
        unfreezePoolV1(icebreakerPoolV1,        icebreakerLoans,        300_000_000e6);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertPoolMatchesSnapshotted(icebreakerPoolV1);

        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

}
