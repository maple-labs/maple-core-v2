// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";

import { DebtLocker as DebtLockerV4 } from "../../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerV4Migrator }       from "../../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { MapleGlobals }                           from "../../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy as MapleGlobalsNTP } from "../../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MapleLoan as MapleLoanV4 }                       from "../../../modules/loan/contracts/MapleLoan.sol";
import { MapleLoanFeeManager }                            from "../../../modules/loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MapleLoanV4Initializer } from "../../../modules/loan/contracts/MapleLoanInitializer.sol";
import { MapleLoanV4Migrator }                            from "../../../modules/loan/contracts/MapleLoanV4Migrator.sol";

import { MapleLoan as MapleLoanV301 } from "../../../modules/loan-v301/contracts/MapleLoan.sol";
import { MapleLoan as MapleLoanV302 } from "../../../modules/loan-v302/contracts/MapleLoan.sol";

import { AccountingChecker }                         from "../../../modules/migration-helpers/contracts/checkers/AccountingChecker.sol";
import { DeactivationOracle }                        from "../../../modules/migration-helpers/contracts/DeactivationOracle.sol";
import { MigrationHelper }                           from "../../../modules/migration-helpers/contracts/MigrationHelper.sol";
import { NonTransparentProxy as MigrationHelperNTP } from "../../../modules/migration-helpers/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { LoanManager }            from "../../../modules/pool-v2/contracts/LoanManager.sol";
import { LoanManagerFactory }     from "../../../modules/pool-v2/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../../../modules/pool-v2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolDeployer }           from "../../../modules/pool-v2/contracts/PoolDeployer.sol";
import { PoolManager }            from "../../../modules/pool-v2/contracts/PoolManager.sol";
import { PoolManagerFactory }     from "../../../modules/pool-v2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer } from "../../../modules/pool-v2/contracts/proxy/PoolManagerInitializer.sol";
import { TransitionLoanManager }  from "../../../modules/pool-v2/contracts/TransitionLoanManager.sol";

import { WithdrawalManager }            from "../../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../../../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../../../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

import {
    IDebtLockerLike,
    IERC20Like,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleProxiedLike,
    IPoolLike,
    IPoolManagerLike,
    ITransitionLoanManagerLike
} from "./Interfaces.sol";

contract LiquidityMigrationTest is TestUtils, AddressRegistry {

    address migrationMultisig = address(new Address());

    AccountingChecker accountingChecker;
    MigrationHelper   migrationHelper;

    MapleGlobals        mapleGlobalsV2;
    MapleLoanFeeManager feeManager;
    PoolDeployer        poolDeployer;

    LoanManagerFactory       loanManagerFactory;
    PoolManagerFactory       poolManagerFactory;
    WithdrawalManagerFactory withdrawalManagerFactory;

    function test_liquidityMigration() external {
        createGlobals();
        createHelpers();
        createFactories();
        setupFactories();

        assertInitialState();

        migratePool(mavenWethPoolV1,         mavenWethLoans,         mavenWethLps);
        migratePool(mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps);
        migratePool(mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps);
        migratePool(orthogonalPoolV1,        orthogonalLoans,        orthogonalLps);
        migratePool(icebreakerPoolV1,        icebreakerLoans,        icebreakerLps);

        assertFinalState();
    }

    /******************************************************************************************************************************/
    /*** Setup Functions                                                                                                        ***/
    /******************************************************************************************************************************/

    function createFactories() internal {
        poolManagerFactory       = new PoolManagerFactory(address(mapleGlobalsV2));
        loanManagerFactory       = new LoanManagerFactory(address(mapleGlobalsV2));
        withdrawalManagerFactory = new WithdrawalManagerFactory(address(mapleGlobalsV2));

        vm.startPrank(governor);

        mapleGlobalsV2.setValidFactory("LOAN",               address(loanFactory),              true);
        mapleGlobalsV2.setValidFactory("LOAN_MANAGER",       address(loanManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("POOL_MANAGER",       address(poolManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("WITHDRAWAL_MANAGER", address(withdrawalManagerFactory), true);

        vm.stopPrank();
    }

    function createGlobals() internal {
        mapleGlobalsV2 = MapleGlobals(address(new MapleGlobalsNTP(governor, address(new MapleGlobals()))));
        feeManager     = new MapleLoanFeeManager(address(mapleGlobalsV2));
        poolDeployer   = new PoolDeployer(address(mapleGlobalsV2));

        vm.startPrank(governor);

        mapleGlobalsV2.setMapleTreasury(mapleTreasury);
        mapleGlobalsV2.setValidPoolDeployer(address(poolDeployer), true);

        mapleGlobalsV2.setValidPoolAsset(address(usdc), true);
        mapleGlobalsV2.setValidPoolAsset(address(wbtc), true);
        mapleGlobalsV2.setValidPoolAsset(address(weth), true);

        mapleGlobalsV2.setValidPoolDelegate(mavenPermissionedPoolV1.poolDelegate(), true);
        mapleGlobalsV2.setValidPoolDelegate(mavenUsdcPoolV1.poolDelegate(),         true);
        mapleGlobalsV2.setValidPoolDelegate(mavenWethPoolV1.poolDelegate(),         true);
        mapleGlobalsV2.setValidPoolDelegate(orthogonalPoolV1.poolDelegate(),        true);
        mapleGlobalsV2.setValidPoolDelegate(icebreakerPoolV1.poolDelegate(),        true);

        vm.stopPrank();
    }

    function createHelpers() internal {
        accountingChecker = new AccountingChecker(address(mapleGlobalsV2));
        migrationHelper   = MigrationHelper(address(new MigrationHelperNTP(migrationMultisig, address(new MigrationHelper()))));

        vm.prank(migrationMultisig);
        migrationHelper.setGlobals(address(mapleGlobalsV2));

        vm.prank(governor);
        mapleGlobalsV2.setMigrationAdmin(address(migrationHelper));
    }

    function setupFactories() internal {
        vm.startPrank(governor);

        debtLockerFactory.registerImplementation(400, address(new DebtLockerV4()), address(debtLockerV3Initializer));
        debtLockerFactory.enableUpgradePath(200, 400, address(new DebtLockerV4Migrator()));
        debtLockerFactory.enableUpgradePath(300, 400, address(new DebtLockerV4Migrator()));

        loanFactory.registerImplementation(301, address(new MapleLoanV301()), address(loanV3Initializer));
        loanFactory.registerImplementation(302, address(new MapleLoanV302()), address(0));
        loanFactory.registerImplementation(400, address(new MapleLoanV4()),   address(new MapleLoanV4Initializer()));
        loanFactory.enableUpgradePath(200, 301, address(0));
        loanFactory.enableUpgradePath(300, 301, address(0));
        loanFactory.enableUpgradePath(301, 302, address(0));
        loanFactory.enableUpgradePath(302, 400, address(new MapleLoanV4Migrator()));
        loanFactory.setDefaultVersion(301);

        loanManagerFactory.registerImplementation(100, address(new TransitionLoanManager()), address(new LoanManagerInitializer()));
        loanManagerFactory.registerImplementation(200, address(new LoanManager()),           address(new LoanManagerInitializer()));
        loanManagerFactory.enableUpgradePath(100, 200, address(0));
        loanManagerFactory.setDefaultVersion(100);

        poolManagerFactory.registerImplementation(100, address(new PoolManager()), address(new PoolManagerInitializer()));
        poolManagerFactory.setDefaultVersion(100);

        withdrawalManagerFactory.registerImplementation(100, address(new WithdrawalManager()), address(new WithdrawalManagerInitializer()));
        withdrawalManagerFactory.setDefaultVersion(100);

        vm.stopPrank();
    }

    /******************************************************************************************************************************/
    /*** Migration Functions                                                                                                    ***/
    /******************************************************************************************************************************/

    function migratePool(IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps) internal {

        /*******************************************/
        /*** Step 1: Upgrade all Loans to v3.0.1 ***/
        /*******************************************/

        upgradeLoansToV301(loans);

        /*************************************************/
        /*** Step 2: Upgrade all DebtLockers to v4.0.0 ***/
        /*************************************************/

        upgradeDebtLockersToV4(poolV1, loans);

        /*******************************************/
        /** Step 3: Ensure all loans are claimed ***/
        /*******************************************/

        claimAllLoans(poolV1, loans);

        /***************************************************************************/
        /*** Step 4: Lock all actions on the loan by migrating it to v3.02       ***/
        /***************************************************************************/

        upgradeLoansToV302(loans);

        /******************************************************************/
        /*** Step 5: Lock Pool deposits by setting liquidityCap to zero ***/
        /******************************************************************/

        lockPoolV1Deposits(poolV1);

        /***************************************************************************/
        /*** Step 6: Lock Pool withdrawals by funding a loan with remaining cash ***/
        /***************************************************************************/

        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);
        IMapleLoanLike migrationLoan;

        if (availableLiquidity > 0) {
            // Create a loan using all of the available cash in the pool (if there is any).
            migrationLoan = createMigrationLoan(poolV1, loans, availableLiquidity);

            // Upgrade the newly created debt locker of the migration loan.
            upgradeDebtLockerToV4(poolV1, migrationLoan);

            vm.prank(globalAdmin);
            migrationLoan.upgrade(302, new bytes(0));
        }

        /*******************************/
        /*** Step 7: Deploy new Pool ***/
        /*******************************/

        // Deploy the new version of the pool.
        IPoolManagerLike           poolManager           = IPoolManagerLike(deployPoolV2(poolV1));
        ITransitionLoanManagerLike transitionLoanManager = ITransitionLoanManagerLike(poolManager.loanManagerList(0));
        IPoolLike                  poolV2                = IPoolLike(poolManager.pool());

        // TODO: Add cover

        /***************************************************************/
        /*** Step 8: Add Loans to LM, setting up parallel accounting ***/
        /***************************************************************/

        address[] memory loanAddresses = convertToAddresses(loans);

        vm.prank(migrationMultisig);
        migrationHelper.addLoansToLM(address(transitionLoanManager), loanAddresses);

        uint256 loansAddedTimestamp = block.timestamp;

        /**********************************************/
        /*** Step 9: Activate the Pool from Globals ***/
        /**********************************************/

        vm.prank(governor);
        mapleGlobalsV2.activatePoolManager(address(poolManager));

        /******************************************************************************/
        /*** Step 10: Open the Pool or allowlist the pool to allow airdrop to occur ***/
        /******************************************************************************/

        openPoolV2(poolManager);  // TODO: Add whitelisting for permissioned pools.

        /***********************************************************/
        /*** Step 11: Airdrop PoolV2 LP tokens to all PoolV1 LPs ***/
        /***********************************************************/

        // TODO: Add functionality to allowlist LPs in case of permissioned pool prior to airdrop.
        vm.startPrank(migrationMultisig);
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps);

        assertPoolAccounting(poolManager, loans, loansAddedTimestamp);

        /******************************************************************************/
        /*** Step 12: Set the pending lender in all outstanding Loans to be the TLM ***/
        /******************************************************************************/

        migrationHelper.setPendingLenders(address(poolV1), address(poolManager), address(loanFactory), loanAddresses);

        assertPoolAccounting(poolManager, loans, loansAddedTimestamp);

        /*********************************************************************************/
        /*** Step 13: Accept the pending lender in all outstanding Loans to be the TLM ***/
        /*********************************************************************************/

        migrationHelper.takeOwnershipOfLoans(address(transitionLoanManager), loanAddresses);

        assertPoolAccounting(poolManager, loans, loansAddedTimestamp);

        /*****************************************************/
        /*** Step 14: Upgrade the LoanManager from the TLM ***/
        /*****************************************************/

        migrationHelper.upgradeLoanManager(address(transitionLoanManager), 200);

        vm.stopPrank();

        assertEq(poolV2.totalSupply(), getPoolV1TotalValue(poolV1));

        assertPrincipalOut(transitionLoanManager, loans);  // TODO: Add assertions against PoolV1

        assertPoolAccounting(poolManager, loans, loansAddedTimestamp);

        /****************************************/
        /*** Step 15: Upgrade all loans to V4 ***/
        /****************************************/

        upgradeLoansToV4(loans);

        /******************************************************************/
        /*** Step 16: Close the cash loan, adding liquidity to the pool ***/
        /******************************************************************/

        if (availableLiquidity > 0) {
            closeMigrationLoan(migrationLoan, loans);
        }

        assertPoolAccounting(poolManager, loans, loansAddedTimestamp);

        /***********************************/
        /*** Step 17: Deactivate Pool V1 ***/
        /***********************************/

        deactivatePoolV1(poolV1);  // TODO: Investigate and possibly move to another function.
    }

    /******************************************************************************************************************************/
    /*** Utility Functions                                                                                                      ***/
    /******************************************************************************************************************************/

    function assertFinalState() internal {
        // TODO: Add additional assertions here.
    }

    function assertInitialState() internal {
        // TODO: Add additional assertions here.
        assertTrue(debtLockerFactory.upgradeEnabledForPath(200, 400));
    }

    // TODO: What amount of difference should we expect here? Does the passage of time have any side effects on the simulation?
    // TODO: 0xF6950F28353cA676100C2a92DD360DEa16A213cE in mavenUsedLoans is a few hours from being late, so it warps to become late. This messes up the accounting checker. Make for loops 120 to expose.
    function assertPoolAccounting(IPoolManagerLike poolManager, IMapleLoanLike[] storage loans, uint256 loansAddedTimestamp) internal {
        for (uint256 i; i < 60; ++i) {
            ( uint256 expectedTotalAssets, uint256 returnedTotalAssets ) = accountingChecker.checkTotalAssets(address(poolManager), convertToAddresses(loans), loansAddedTimestamp);
            assertWithinDiff(expectedTotalAssets, returnedTotalAssets, loans.length);
            vm.warp(block.timestamp + 1 minutes);
        }
    }

    function assertPrincipalOut(ITransitionLoanManagerLike transitionLoanManager, IMapleLoanLike[] storage loans) internal {
        uint256 totalPrincipal;
        for (uint i = 0; i < loans.length; i++) {
            totalPrincipal += loans[i].principal();
        }

        assertEq(transitionLoanManager.principalOut(), totalPrincipal);
    }

    function calculateAvailableLiquidity(IPoolLike poolV1) internal view returns (uint256 availableLiquidity) {
        availableLiquidity = IERC20Like(poolV1.liquidityAsset()).balanceOf(poolV1.liquidityLocker());
    }

    function claimAllLoans(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        address poolDelegate = poolV1.poolDelegate();

        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);
            if (loan.claimableFunds() > 0) {
                vm.startPrank(poolDelegate);
                poolV1.claim(address(loan), address(IMapleProxiedLike(loan.lender()).factory()));
                vm.stopPrank();
            }
        }
    }


    function closeMigrationLoan(IMapleLoanLike migrationLoan, IMapleLoanLike[] storage loans) internal {
        vm.prank(migrationLoan.borrower());
        migrationLoan.closeLoan(0);
        loans.pop();
    }

    function convertToAddresses(IMapleLoanLike[] storage inputArray) internal view returns (address[] memory outputArray) {
        outputArray = new address[](inputArray.length);
        for (uint256 i = 0; i < inputArray.length; i++) {
            outputArray[i] = address(inputArray[i]);
        }
    }

    // TODO: Do we need to claim every loan in order to ensure all available cash is in the liquidity locker?
    function createMigrationLoan(IPoolLike poolV1, IMapleLoanLike[] storage loans, uint256 liquidity) internal returns (IMapleLoanLike migrationLoan) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        address[2] memory assets      = [address(asset), address(asset)];
        uint256[3] memory termDetails = [uint256(0), uint256(30 days), uint256(1)];
        uint256[3] memory requests    = [uint256(0), liquidity, liquidity];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory args = abi.encode(address(this), assets, termDetails, requests, rates);
        bytes32 salt      = keccak256(abi.encode(address(poolV1)));
        migrationLoan     = IMapleLoanLike(loanFactory.createInstance(args, salt));

        vm.prank(poolV1.poolDelegate());
        poolV1.fundLoan(address(migrationLoan), address(debtLockerFactory), liquidity);

        assertEq(asset.balanceOf(poolV1.liquidityLocker()), 0);

        loans.push(migrationLoan);
    }

    // TODO: Update this so it doesn't create a separate oracle for each USDC pool.
    function deactivatePoolV1(IPoolLike poolV1) internal {
        address asset = poolV1.liquidityAsset();
        DeactivationOracle oracle = new DeactivationOracle();

        vm.prank(governor);
        mapleGlobalsV1.setPriceOracle(asset, address(oracle));

        vm.prank(poolV1.poolDelegate());
        poolV1.deactivate();
    }

    function deployPoolV2(IPoolLike poolV1) internal returns (IPoolManagerLike poolManager) {
        address[3] memory factories = [
            address(poolManagerFactory),
            address(loanManagerFactory),
            address(withdrawalManagerFactory)
        ];

        address[3] memory initializers = [
            poolManagerFactory.migratorForPath(100, 100),
            loanManagerFactory.migratorForPath(100, 100),
            withdrawalManagerFactory.migratorForPath(100, 100)
        ];

        uint256[6] memory configParams = [
            type(uint256).max,
            0.1e6,
            0,
            7 days,
            2 days,
            getPoolV1TotalValue(poolV1)
        ];

        vm.startPrank(poolV1.poolDelegate());
        ( address poolManagerAddress, , ) = PoolDeployer(poolDeployer).deployPool(
            factories,
            initializers,
            poolV1.liquidityAsset(),
            poolV1.name(),
            poolV1.symbol(),
            configParams
        );
        vm.stopPrank();

        poolManager = IPoolManagerLike(poolManagerAddress);
    }

    function getPoolV1TotalValue(IPoolLike poolV1) internal view returns (uint256 totalValue) {
        totalValue = poolV1.totalSupply() + poolV1.interestSum() - poolV1.poolLosses();
    }

    function lockPoolV1Deposits(IPoolLike poolV1) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setLiquidityCap(0);

        assertEq(poolV1.liquidityCap(), 0);
    }

    function openPoolV2(IPoolManagerLike poolManager) internal {
        vm.prank(poolManager.poolDelegate());
        poolManager.setOpenToPublic();
    }

    function upgradeDebtLockersToV4(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            vm.prank(poolV1.poolDelegate());
            debtLocker.upgrade(400, abi.encode(migrationHelper));
        }

        // Assert all debt lockers are upgraded.
        for (uint i = 0; i < loans.length; i++) {
            IMapleLoanLike debtLocker = IMapleLoanLike(loans[i].lender());
            assertEq(debtLockerFactory.implementationOf(400), debtLocker.implementation());
        }
    }

    function upgradeDebtLockerToV4(IPoolLike poolV1, IMapleLoanLike loan) internal {
        IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());
        vm.prank(poolV1.poolDelegate());
        debtLocker.upgrade(400, abi.encode(migrationHelper));
    }

    function upgradeLoansToV301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(loans[i].borrower());
            loans[i].upgrade(301, new bytes(0));
        }

        // TODO: Assert all loans are upgraded.
    }

    function upgradeLoansToV302(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(globalAdmin);
            loans[i].upgrade(302, new bytes(0));
        }
    }

    function upgradeLoansToV4(IMapleLoanLike[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(globalAdmin);
            loans[i].upgrade(400, abi.encode(address(feeManager)));
        }

        // TODO: Assert all loans are upgraded.
    }

}
