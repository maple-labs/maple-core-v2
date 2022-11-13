// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

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

contract LiquidityMigrationRollbackFrozenPoolTests is SimulationBase {
    /******************************************************************************************************************************/
    /*** Contingency Measures                                                                                                   ***/
    /*******************************************************************************************************************************

    * Stage:    Frozen Pool
      Measures: The goal would be to get back to the state prior to freezing the pool which would involve:
                1. Set loan and debtLocker factories to allow the downgrade path.
                2. Reverting the debt lockers back to V300
                3. Reverting the loans back to V301
                4. Pay back migration loan
                5. Remove the 0 liquidity cap on the pool to 'unlock' it
    *******************************************************************************************************************************/

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

contract LiquidityMigrationRollbackTransferLoans is SimulationBase {
    /******************************************************************************************************************************/
    /*** Contingency Measures                                                                                                   ***/
    /*******************************************************************************************************************************
    * Stage:    Deploy and Migrate Pool (Assuming we haven't upgrade to loan V4 yet)
                Note: Rollback occurs slightly differently depending on if we have upgraded to the LM from the TLM
      Measures: The goal would be to get back to the state prior to deploying and migrating the pool which would involve:
                1. Ignoring the pools v2 deployment
                2. We call the loanManager v200 implementation to give ownership of the loans back to the debt lockers
                this involves calling the setOwnershipTo() and takeOwnership() functions
                3. Apply measures from Frozen Pool stage if we wish to revert back to starting state
    *******************************************************************************************************************************/

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
        mavenWethPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0), mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_transferLoans_mavenUsdcPool() external {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0), mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_transferLoans_mavenPermissionedPool() external {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_transferLoans_orthogonalPool() external {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0), orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_transferLoans_icebreakerPool() external {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps);

        // Rollback
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0), icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_transferLoans_allPools() external {
        mavenWethPoolManager         = deployAndMigratePoolUpToLoanManagerUpgrade(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps);
        mavenUsdcPoolManager         = deployAndMigratePoolUpToLoanManagerUpgrade(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps);
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);
        orthogonalPoolManager        = deployAndMigratePoolUpToLoanManagerUpgrade(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps);
        icebreakerPoolManager        = deployAndMigratePoolUpToLoanManagerUpgrade(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps);

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

contract LiquidityMigrationRollbackFromUpgradedLoanManager is SimulationBase {
    /******************************************************************************************************************************/
    /*** Contingency Measures                                                                                                   ***/
    /*******************************************************************************************************************************
    * Stage:    Deploy and Migrate Pool (Assuming we haven't upgrade to loan V4 yet)
                Note: Rollback occurs slightly differently depending on if we have upgraded to the LM from the TLM
      Measures: The goal would be to get back to the state prior to deploying and migrating the pool which would involve
                1. We can ignore the pools v2 deployment
                2. We call the loanManager v200 implementation to give ownership of the loans back to the debt lockers
                this involves calling the setOwnershipTo() and takeOwnership() functions
                3. Apply measures from Frozen Pool stage if we wish to revert back to starting state
    *******************************************************************************************************************************/

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
        mavenWethPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps);

        setLoanTransferAdmin(mavenWethPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0), mavenWethLoans);
        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshotted(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedLoanManager_mavenUsdcPool() external {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps);

        setLoanTransferAdmin(mavenUsdcPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0), mavenUsdcLoans);
        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshotted(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedLoanManager_mavenPermissionedPool() external {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);

        setLoanTransferAdmin(mavenPermissionedPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshotted(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedLoanManager_orthogonalPool() external {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps);

        setLoanTransferAdmin(orthogonalPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0), orthogonalLoans);
        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshotted(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedLoanManager_icebreakerPool() external {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps);

        setLoanTransferAdmin(icebreakerPoolManager);

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);

        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0), icebreakerLoans);
        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshotted(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedLoanManager_allPools() external {
        mavenWethPoolManager         = deployAndMigratePoolUpToLoanUpgrade(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps);
        mavenUsdcPoolManager         = deployAndMigratePoolUpToLoanUpgrade(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps);
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);
        orthogonalPoolManager        = deployAndMigratePoolUpToLoanUpgrade(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps);
        icebreakerPoolManager        = deployAndMigratePoolUpToLoanUpgrade(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps);

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
