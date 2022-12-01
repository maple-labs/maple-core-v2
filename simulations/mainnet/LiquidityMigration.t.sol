// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { SimulationBase } from "./SimulationBase.sol";

import { IMapleLoanLike, IPoolLike, IPoolManagerLike } from "./Interfaces.sol";

contract LiquidityMigrationTests is SimulationBase {

    function test_liquidityMigration_complete() public {
        upgradeAllLoansToV301();

        deployProtocol();

        tempGovernorAcceptsV2Governorship();

        migrationMultisigAcceptsMigrationAdministratorship();

        storeCoverAmounts();
        setupExistingFactories();

        migrateAllPools();
        postMigration();

        // PoolV2 Lifecycle start
        depositAllCovers();
        increaseAllLiquidityCaps();

        // TODO: Remove these arbitrary tests as lifecycle tests are better.
        depositLiquidity(mavenWethPoolManager.pool(),         address(new Address()), 100e18);
        depositLiquidity(mavenUsdcPoolManager.pool(),         address(new Address()), 100_000e6);
        depositLiquidity(mavenPermissionedPoolManager.pool(), address(new Address()), 100_000e6);
        depositLiquidity(orthogonalPoolManager.pool(),        address(new Address()), 100_000e6);
        depositLiquidity(icebreakerPoolManager.pool(),        address(new Address()), 100_000e6);
    }

}

contract LiquidityMigrationRollbackFrozenPoolTests is SimulationBase {

    function setUp() public {
        upgradeAllLoansToV301();

        deployProtocol();

        tempGovernorAcceptsV2Governorship();

        migrationMultisigAcceptsMigrationAdministratorship();

        storeCoverAmounts();
        setupExistingFactories();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshotted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();
    }

    function test_rollback_frozenPool_mavenWeth() public {
        migrationKickoffOnPoolV1(mavenWethPoolV1, mavenWethLoans, tempMavenWethPD);

        rollbackMigrationKickoffOnPoolV1(mavenWethPoolV1, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_frozenPool_mavenPermissioned() public {
        migrationKickoffOnPoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, tempMavenPermissionedPD);

        rollbackMigrationKickoffOnPoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_frozenPool_mavenUsdc() public {
        migrationKickoffOnPoolV1(mavenUsdcPoolV1, mavenUsdcLoans, tempMavenUsdcPD);

        rollbackMigrationKickoffOnPoolV1(mavenUsdcPoolV1, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_frozenPool_orthogonal() public {
        migrationKickoffOnPoolV1(orthogonalPoolV1, orthogonalLoans, tempOrthogonalPD);

        rollbackMigrationKickoffOnPoolV1(orthogonalPoolV1, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_frozenPool_icebreaker() public {
        migrationKickoffOnPoolV1(icebreakerPoolV1, icebreakerLoans, tempIcebreakerPD);

        rollbackMigrationKickoffOnPoolV1(icebreakerPoolV1, icebreakerLoans, 300_000_000e6);

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

        tempGovernorAcceptsV2Governorship();

        migrationMultisigAcceptsMigrationAdministratorship();

        storeCoverAmounts();
        setupExistingFactories();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_transferLoans_mavenWethPool() public {
        mavenWethPoolManager = migrationStepsUpToLoanManagerUpgrade(tempMavenWethPD, mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        rollbackFromTransferredLoans(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_transferLoans_mavenUsdcPool() public {
        mavenUsdcPoolManager = migrationStepsUpToLoanManagerUpgrade(tempMavenUsdcPD, mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        rollbackFromTransferredLoans(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_transferLoans_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = migrationStepsUpToLoanManagerUpgrade(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        rollbackFromTransferredLoans(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_transferLoans_orthogonalPool() public {
        orthogonalPoolManager = migrationStepsUpToLoanManagerUpgrade(tempOrthogonalPD, orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        rollbackFromTransferredLoans(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_transferLoans_icebreakerPool() public {
        icebreakerPoolManager = migrationStepsUpToLoanManagerUpgrade(tempIcebreakerPD, icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

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

        tempGovernorAcceptsV2Governorship();

        migrationMultisigAcceptsMigrationAdministratorship();

        storeCoverAmounts();
        setupExistingFactories();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_upgradedLoanManager_mavenWethPool() public {
        mavenWethPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempMavenWethPD, mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        rollbackFromUpgradedLoanManager(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedLoanManager_mavenUsdcPool() public {
        mavenUsdcPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempMavenUsdcPD, mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        rollbackFromUpgradedLoanManager(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedLoanManager_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        rollbackFromUpgradedLoanManager(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedLoanManager_orthogonalPool() public {
        orthogonalPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempOrthogonalPD, orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        rollbackFromUpgradedLoanManager(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedLoanManager_icebreakerPool() public {
        icebreakerPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempIcebreakerPD, icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        rollbackFromUpgradedLoanManager(icebreakerPoolV1, icebreakerPoolManager, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedLoanManager_allPools() public {
        deployAndMigrateAllPoolsUpToLoanUpgrade();

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

        tempGovernorAcceptsV2Governorship();

        migrationMultisigAcceptsMigrationAdministratorship();

        storeCoverAmounts();
        setupExistingFactories();

        payAndClaimAllUpcomingLoans();

        // Orthogonal has a loan with claimable funds that it's more than 5 days from payment away. We need to claim it here before the pool is snapshoted
        claimAllLoans(orthogonalPoolV1, orthogonalLoans);

        snapshotAllPoolStates();

        freezeAllPoolV1s();

        storeAllOriginalLoanLenders();

        setV1ProtocolPause(true);
    }

    function test_rollback_upgradedV4Loans_mavenWethPool() public {
        mavenWethPoolManager = deployAndMigratePool(tempMavenWethPD, mavenWethPoolV1, mavenWethLoans, mavenWethLps, true);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenWethPoolV1, mavenWethPoolManager, mavenWethLoans, 35_000e18);

        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertLoansBelongToPool(mavenWethPoolV1, mavenWethLoans);
    }

    function test_rollback_upgradedV4Loans_mavenUsdcPool() public {
        mavenUsdcPoolManager = deployAndMigratePool(tempMavenUsdcPD, mavenUsdcPoolV1, mavenUsdcLoans, mavenUsdcLps, true);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenUsdcPoolV1, mavenUsdcPoolManager, mavenUsdcLoans, 350_000_000e6);

        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertLoansBelongToPool(mavenUsdcPoolV1, mavenUsdcLoans);
    }

    function test_rollback_upgradedV4Loans_mavenPermissionedPool() public {
        mavenPermissionedPoolManager = deployAndMigratePool(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 60_000_000e6);

        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
    }

    function test_rollback_upgradedV4Loans_orthogonalPool() public {
        orthogonalPoolManager = deployAndMigratePool(tempOrthogonalPD, orthogonalPoolV1, orthogonalLoans, orthogonalLps, true);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(orthogonalPoolV1, orthogonalPoolManager, orthogonalLoans, 450_000_000e6);

        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertLoansBelongToPool(orthogonalPoolV1, orthogonalLoans);
    }

    function test_rollback_upgradedV4Loans_icebreakerPool() public {
        icebreakerPoolManager = deployAndMigratePool(tempIcebreakerPD, icebreakerPoolV1, icebreakerLoans, icebreakerLps, false);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        rollbackFromUpgradedV4Loans(icebreakerPoolV1, icebreakerPoolManager, icebreakerLoans, 300_000_000e6);

        assertPoolMatchesSnapshot(icebreakerPoolV1);
        assertLoansBelongToPool(icebreakerPoolV1, icebreakerLoans);
    }

    function test_rollback_upgradedV4Loans_allPools() public {
        deployAndMigrateAllPools();

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));

        // Start rollback
        vm.prank(tempGovernor);
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeAllLoans400To302();

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV1));

        setAllLoanTransferAdmins();

        setV1ProtocolPause(false);

        returnAllLoansToDebtLockers();

        unfreezeAllPoolV1s();

        assertAllPoolsMatchSnapshot();

        assertAllLoansBelongToRespectivePools();
    }

}
