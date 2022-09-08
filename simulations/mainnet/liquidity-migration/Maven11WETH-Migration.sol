// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address } from "../../../modules/contract-test-utils/contracts/test.sol";

import { Pool } from "../../../modules/pool-v2/contracts/Pool.sol";

import { MapleLoanFeeManager } from "../../../modules/loan/contracts/MapleLoanFeeManager.sol";

import { AccountingChecker } from "../../../modules/migration-helpers/contracts/checkers/AccountingChecker.sol";

import {
    IERC20Like,
    ILoanFactoryLike,
    ILoanInitializerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleProxyFactoryLike,
    IMapleProxiedLike,
    IMplRewardsLike,
    IPoolLike,
    IStakeLockerLike
} from "./Interfaces.sol";

import { LiquidityMigrationBase } from "./LiquidityMigrationBase.t.sol";

contract Maven11WETHMigration is LiquidityMigrationBase {

    AccountingChecker   accountingChecker;

    function setUp() public override {
        super.setUp();

        // Set poolV1 variables
        poolDelegate = address(new Address());
        globalsV1    = IMapleGlobalsLike(MAPLE_GLOBALS);
        poolV1       = IPoolLike(MAVEN11_POOL);
        stakeLocker  = IStakeLockerLike(MAVEN11_SL);
        asset        = WETH;

        // Steps that need to be performed once
        _setUpPoolV2Deployment();
        _registerDebtLockerV4();
        _registerLoanVersions();
        _setUpTransitionLoanManagerFactory();  // TODO: Change name

        accountingChecker = new AccountingChecker(address(globals));
    }

    function test_fullMigration() external {
        // Initial assertions
        assertTrue(IMapleProxyFactoryLike(DL_FACTORY).upgradeEnabledForPath(200, 400));

        // Upgrade all loans to v3.01
        _upgradeLoansToV301(MAVEN11_LOANS);

        // Upgrade debt lockers
        _upgradeDebtLockers(MAVEN11_PD, MAVEN11_LOANS, 400);

        // Assert all debt lockers are upgraded
        address implementation = IMapleProxyFactoryLike(DL_FACTORY).implementationOf(400);
        for (uint i = 0; i < MAVEN11_LOANS.length; i++) {
            address debtLocker = IMapleLoanLike(MAVEN11_LOANS[i]).lender();

            assertEq(implementation, IMapleLoanLike(debtLocker).implementation());
        }

        // Time sensitive operation starts here
        _lockPoolDeposits();
        assertEq(IPoolLike(poolV1).liquidityCap(), 0);

        // Create loan with cash available
        _createAndFundLoan(IERC20Like(asset).balanceOf(MAVEN11_LL), MAVEN11_PD);
        assertEq(IERC20Like(asset).balanceOf(address(poolV1)), 0);

        // Upgrade the recently created DL to V4
        address[] memory loanArray = new address[](1);
        loanArray[0] = MAVEN11_LOANS[MAVEN11_LOANS.length - 1];

        _upgradeDebtLockers(MAVEN11_PD, loanArray, 400);

        // Deploy the poolV2
        _deployPoolV2();

        // Add loans to the transition LM
        _addLoansToTransitionLM(MAVEN11_LOANS);

        // Assert that pool accounting is in steady state.
        for (uint256 i; i < 120; ++i) {
            ( uint256 expectedTotalAssets_, uint256 returnedTotalAssets_ ) = accountingChecker.checkTotalAssets(address(poolManager), MAVEN11_LOANS);
            assertWithinDiff(expectedTotalAssets_, returnedTotalAssets_, 3);
            vm.warp(start + i * 1 minutes);
        }

        Pool pool = Pool(poolManager.pool());

        // Perform accounting checks
        assertEq(pool.totalSupply(),                   _getPoolV1TotalValue());
        assertEq(transitionLoanManager.principalOut(), poolV1.principalOut());

        // Set pending lender as the transition loan manager
        migrationHelper.setPendingLender(MAVEN11_LOANS, address(transitionLoanManager));

        // Check that all loans have the loan manager as pending lender
        for (uint i = 0; i < MAVEN11_LOANS.length; i++) {
            assertEq(address(transitionLoanManager), IMapleLoanLike(MAVEN11_LOANS[i]).pendingLender());
        }

        // Assert that pool accounting is in steady state.
        for (uint256 i; i < 120; ++i) {
            ( uint256 expectedTotalAssets_, uint256 returnedTotalAssets_ ) = accountingChecker.checkTotalAssets(address(poolManager), MAVEN11_LOANS);
            assertWithinDiff(expectedTotalAssets_, returnedTotalAssets_, 3);
            vm.warp(start + i * 1 minutes);
        }

        // Finish ownership migration
        vm.prank(MIGRATION_ADMIN);
        transitionLoanManager.takeOwnership(MAVEN11_LOANS);

        // Assert that investment manager owns all loans
        for (uint i = 0; i < MAVEN11_LOANS.length; i++) {
            assertEq(address(transitionLoanManager), IMapleLoanLike(MAVEN11_LOANS[i]).lender());
        }

        // Upgrade all loans
        _upgradeLoansToV4(MAVEN11_LOANS);

        // Upgrade transition loan manager to regular loan manager
        vm.prank(MIGRATION_ADMIN);
        transitionLoanManager.upgrade(200, new bytes(0));

        // Assert that pool accounting is in steady state.
        start = block.timestamp;
        for (uint256 i; i < 120; ++i) {
            ( uint256 expectedTotalAssets_, uint256 returnedTotalAssets_ ) = accountingChecker.checkTotalAssets(address(poolManager), MAVEN11_LOANS);
            assertWithinDiff(expectedTotalAssets_, returnedTotalAssets_, 4);
            vm.warp(start + i * 1 minutes);
        }

        // Post Migration Steps
        // Open pool so Lps can receive tokens
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
        _airdropTokens(address(poolV1), address(pool), MIGRATION_ADMIN, MAVEN11_LPS);

        _payBackLoan();

        MAVEN11_LOANS.pop();  // Remove cash loan from array for checks.

        // Assert that pool accounting is in steady state.
        start = block.timestamp;
        for (uint256 i; i < 120; ++i) {
            ( uint256 expectedTotalAssets_, uint256 returnedTotalAssets_ ) = accountingChecker.checkTotalAssets(address(poolManager), MAVEN11_LOANS);
            assertWithinDiff(expectedTotalAssets_, returnedTotalAssets_, 4);
            vm.warp(start + i * 1 minutes);
        }

        // Deactivation of poolV1 will be made once all pools have migrated, but for completeness we do it here
        _deactivatePool(address(poolV1), MAVEN11_PD);
    }

}
