// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

import { SimulationBase } from "./SimulationBase.sol";

contract LiquidityMigrationTests is SimulationBase {

    function test_liquidityMigration_complete() public {
        performEntireMigration();
    }

}

contract RollbackBase is SimulationBase {

    modifier checkStateRestored() {
        snapshotAllPoolStates();

        _;

        assertAllPoolsMatchSnapshot();
    }

    modifier checkLoansBelongToRespectivePools() {
        _;

        assertAllLoansBelongToRespectivePools();
    }

    function goto_lmp_2() internal {
        setPoolAdminsToMigrationMultisig();  // LMP #1
    }

    function goto_lmp_3() internal {
        goto_lmp_2();
        zeroInvestorFeeAndTreasuryFee();  // LMP #2
    }

    function goto_lmp_4() internal {
        goto_lmp_3();
        payAndClaimAllUpcomingLoans();  // LMP #3
    }

    function goto_lmp_5() internal {
        goto_lmp_4();
        upgradeAllLoansToV301();  // LMP #4
    }

    function goto_lmp_6() internal {
        // NOTE: LMP #5 was already done on mainnet, so skip it.
        goto_lmp_5();
        // NOTE: LMP #5 was already done on mainnet, so skip it.
        // deployProtocol();  // LMP #5
    }

    function goto_lmp_7() internal {
        goto_lmp_6();
        // NOTE: LMP #6 was already done on mainnet, so skip it.
        // tempGovernorAcceptsV2Governorship();  // LMP #6
    }

    function goto_lmp_8() internal {
        goto_lmp_7();
        // NOTE: LMP #7 was already done on mainnet, so skip it.
        // migrationMultisigAcceptsMigrationAdministratorship();  // LMP #7
    }

    function goto_lmp_9() internal {
        goto_lmp_8();
        setupExistingFactories();  // LMP #8
    }

    function goto_lmp_10() internal {
        goto_lmp_9();
        upgradeAllDebtLockersToV400();  // LMP #9
    }

    function goto_lmp_11() internal {
        goto_lmp_10();
        claimAllLoans();  // LMP #10
    }

    function goto_lmp_12() internal {
        goto_lmp_11();
        upgradeAllLoansToV302();  // LMP #11
    }

    function goto_lmp_13() internal {
        goto_lmp_12();
        lockAllPoolV1Deposits();  // LMP #12
    }

    function goto_lmp_14() internal {
        goto_lmp_13();
        createAllMigrationLoans();  // LMP #13
    }

    function goto_lmp_15() internal {
        goto_lmp_14();
        // NOTE: Technically, each loan is funded and their DebtLockers are upgraded per pool before moving onto the next
        fundAllMigrationLoans();  // LMP #14
    }

    function goto_lmp_16() internal {
        goto_lmp_15();
        // NOTE: Technically, each loan is funded and their DebtLockers are upgraded per pool before moving onto the next
        upgradeAllMigrationLoanDebtLockers();  // LMP #15
    }

    function goto_lmp_17() internal {
        goto_lmp_16();
        upgradeAllMigrationLoansToV302();  // LMP #16
    }

    function goto_lmp_18() internal {
        goto_lmp_17();
        pauseV1Protocol();  // LMP #17
    }

    function goto_lmp_19() internal {
        goto_lmp_18();
        deployAllPoolV2s();  // LMP #18
    }

    function goto_lmp_20() internal {
        goto_lmp_19();
        addLoansToAllLoanManagers();  // LMP #19
    }

    function goto_lmp_21() internal {
        goto_lmp_20();
        activateAllPoolManagers();  // LMP #20
    }

    function goto_lmp_22() internal {
        goto_lmp_21();
        openOrAllowOnAllPoolV2s();  // LMP #21
    }

    function goto_lmp_23() internal {
        goto_lmp_22();
        airdropTokensForAllPools();  // LMP #22
    }

    function goto_lmp_24() internal {
        goto_lmp_23();
        setAllPendingLenders();  // LMP #23
    }

    function goto_lmp_25() internal {
        goto_lmp_24();
        takeAllOwnershipsOfLoans();  // LMP #24
    }

    function goto_lmp_26() internal {
        goto_lmp_25();
        upgradeAllLoanManagers();  // LMP #25
    }

}

// Rollback LMP #4
contract RollbackFromV301LoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_4();
    }

    function test_rollback_from_V301_loans() public checkStateRestored checkLoansBelongToRespectivePools {
        upgradeAllLoansToV301();  // LMP #4

        enableLoanDowngradeFromV301();
        disableLoanUpgradeFromV300();
        downgradeAllLoansFromV301();  // Rollback LMP #4
    }

}

// Rollback LMP #9
contract RollbackFromV400DebtLockersTests is RollbackBase {

    function setUp() public {
        goto_lmp_9();
    }

    function test_rollback_from_V400_debtLockers() public checkStateRestored checkLoansBelongToRespectivePools {
        upgradeAllDebtLockersToV400();  // LMP #9

        enableDebtLockerDowngradeFromV400();
        disableDebtLockerUpgradeFromV300();
        downgradeAllDebtLockersFromV400();  // Rollback LMP #9
    }

}

// Rollback LMP #11
contract RollbackFromV302LoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_11();
    }

    function test_rollback_from_V400_debtLockers() public checkStateRestored checkLoansBelongToRespectivePools {
        upgradeAllLoansToV302();  // LMP #11

        enableLoanDowngradeFromV302();
        downgradeAllLoansFromV302();  // Rollback LMP #11
    }

}

// Rollback LMP #14
contract RollbackFromFundedMigrationLoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_14();
    }

    function test_rollback_from_V400_debtLockers() public checkStateRestored checkLoansBelongToRespectivePools {
        fundAllMigrationLoans();  // LMP #14

        paybackAllMigrationLoansToPoolV1s();  // Rollback LMP #14
    }

}

// Rollback LMP #15
contract RollbackFromV400DebtLockersOfMigrationLoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_15();
    }

    function test_rollback_from_V400_debtLockers() public checkStateRestored checkLoansBelongToRespectivePools {
        upgradeAllMigrationLoanDebtLockers();  // LMP #15

        enableDebtLockerDowngradeFromV400();
        downgradeAllMigrationLoanDebtLockersFromV400();  // Rollback LMP #15
    }

}

// Rollback LMP #16
contract RollbackFromV302MigrationLoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_16();
    }

    function test_rollback_from_V302_migration_loans() public checkStateRestored checkLoansBelongToRespectivePools {
        upgradeAllMigrationLoansToV302();  // LMP #16

        enableLoanDowngradeFromV302();
        downgradeAllMigrationLoansFromV302();  // Rollback LMP #15
    }

}

// Rollback LMP #23
contract RollbackFromSetPendingLenderTests is RollbackBase {

    function setUp() public {
        goto_lmp_23();
    }

    function test_rollback_from_setPendingLender() public checkStateRestored checkLoansBelongToRespectivePools {
        setAllPendingLenders();  // LMP #23

        unsetPendingLendersForAllPools();  // Rollback LMP #23
    }

}

// Rollback LMP #24
contract RollbackFromTransferredOwnershipOsLoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_24();
    }

    function test_rollback_from_setPendingLender() public checkStateRestored checkLoansBelongToRespectivePools {
        takeAllOwnershipsOfLoans();  // LMP #24

        revertOwnershipOfLoansForAllPools();  // Rollback LMP #24
    }

}

// Rollback LMP #25
// TODO: Test rolling back further to return the loans to the original pools.
contract RollbackFromV200LoanManagersTests is RollbackBase {

    function setUp() public {
        goto_lmp_25();
    }

    function test_rollback_from_v200_loanManagers() public checkStateRestored {
        upgradeAllLoanManagers();  // LMP #25

        enableLoanManagerDowngradeFromV200();
        downgradeAllLoanManagersFromV200();    // Rollback LMP #25
    }

}

// Rollback LMP #26
// TODO: Test rolling back further to return the loans to the original pools.
contract RollbackFromV400LoansTests is RollbackBase {

    function setUp() public {
        goto_lmp_26();
    }

    function test_rollback_from_v400_loans() public checkStateRestored {
        upgradeAllLoansToV400();  // LMP #26

        enableLoanDowngradeFromV400();
        disableLoanUpgradeFromV302();
        unpauseV1Protocol();
        setGlobalsOfLoanFactoryToV2();

        downgradeAllLoansFromV400();  // Rollback LMP #26

        setGlobalsOfLoanFactoryToV1();
    }

}
