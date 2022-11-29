// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { SimulationBase } from "./SimulationBase.sol";

import { IMapleLoanLike, IPoolLike, IPoolManagerLike } from "./Interfaces.sol";

contract LiquidityMigrationTests is SimulationBase {

    function test_liquidityMigration_complete() public {
        deployAndMigrate();

        // PoolV2 Lifecycle start
        depositAllCovers();
        increaseAllLiquidityCaps();
        makeAllDeposits();
    }

}

contract LiquidityMigrationRollbackFrozenPoolTests is SimulationBase {

    function setUp() public {
        upgradeAllLoansToV301();

        deployProtocol();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshotted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();
    }

    function test_rollback_frozenPool_mavenWeth() public {
        freezePoolV1(mavenWethPoolV1, mavenWethLoans);

        unfreezePoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_frozenPool_mavenPermissioned() public {
        freezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);

        unfreezePoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_frozenPool_mavenUsdc() public {
        freezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans);

        unfreezePoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_frozenPool_orthogonal() public {
        freezePoolV1(orthogonalPoolV1, orthogonalLoans);

        unfreezePoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_frozenPool_icebreaker() public {
        freezePoolV1(icebreakerPoolV1, icebreakerLoans);

        unfreezePoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_frozenPool_allPools() public {
        snapshotAllPoolStates();

        freezeAllPoolV1s();

        unfreezeAllPoolV1s();

        assertAllPoolsMatchSnapshot();

        assertAllLoansBelongToRespectivePools();
    }

}

contract LiquidityMigrationRollbackTransferLoansTests is SimulationBase {

    function setUp() public {
        upgradeAllLoansToV301();

        deployProtocol();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_transferLoans_mavenWethPool() public {
        mavenWethPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        rollbackFromTransferredLoans(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_transferLoans_mavenUsdcPool() public {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        rollbackFromTransferredLoans(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_transferLoans_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        rollbackFromTransferredLoans(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_transferLoans_orthogonalPool() public {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        rollbackFromTransferredLoans(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_transferLoans_icebreakerPool() public {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanManagerUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        rollbackFromTransferredLoans(icebreakerPoolV1, icebreakerPoolManager, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_transferLoans_allPools() public {
        deployAndMigrateAllPoolsUpToLoanManagerUpgrade();

        // Rollback
        setV1ProtocolPause(false);

        returnAllLoansToDebtLockers();

        unfreezeAllPoolV1s();

        assertAllPoolsMatchSnapshot();

        assertAllLoansBelongToRespectivePools();
    }

}

contract LiquidityMigrationRollbackFromUpgradedLoanManagerTests is SimulationBase {

    function setUp() public {
        upgradeAllLoansToV301();

        deployProtocol();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_upgradedLoanManager_mavenWethPool() public {
        mavenWethPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        rollbackFromUpgradedLoanManager(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedLoanManager_mavenUsdcPool() public {
        mavenUsdcPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        rollbackFromUpgradedLoanManager(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedLoanManager_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = deployAndMigratePoolUpToLoanUpgrade(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        rollbackFromUpgradedLoanManager(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedLoanManager_orthogonalPool() public {
        orthogonalPoolManager = deployAndMigratePoolUpToLoanUpgrade(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        rollbackFromUpgradedLoanManager(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedLoanManager_icebreakerPool() public {
        icebreakerPoolManager = deployAndMigratePoolUpToLoanUpgrade(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        rollbackFromUpgradedLoanManager(icebreakerPoolV1, icebreakerPoolManager, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedLoanManager_allPools() public {
        deployAndMigratePoolUpToLoanUpgrade();

        setAllLoanTransferAdmins();

        setV1ProtocolPause(false);

        returnAllLoansToDebtLockers();

        unfreezeAllPoolV1s();

        assertAllPoolsMatchSnapshot();

        assertAllLoansBelongToRespectivePools();
    }

}

contract LiquidityMigrationRollbackFromUpgradedV4LoanTests is SimulationBase {

    function setUp() public {
        upgradeAllLoansToV301();

        deployProtocol();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_upgradedV4Loans_mavenWethPool() public {
        mavenWethPoolManager = deployAndMigratePool(mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedV4Loans_mavenUsdcPool() public {
        mavenUsdcPoolManager = deployAndMigratePool(mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedV4Loans_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = deployAndMigratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedV4Loans_orthogonalPool() public {
        orthogonalPoolManager = deployAndMigratePool(orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedV4Loans_icebreakerPool() public {
        icebreakerPoolManager = deployAndMigratePool(icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(icebreakerPoolV1, icebreakerPoolManager, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedV4Loans_allPools() public {
        deployAndMigrateAllPools();

        setGlobals(address(loanFactory), address(mapleGlobalsV2));

        // Start rollback

        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeAllLoans400To302();

        setGlobals(address(loanFactory), address(mapleGlobalsV1));

        setAllLoanTransferAdmins();

        setV1ProtocolPause(false);

        returnAllLoansToDebtLockers();

        unfreezeAllPoolV1s();

        assertAllPoolsMatchSnapshot();

        assertAllLoansBelongToRespectivePools();
    }

}
