// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { DebtLocker as DebtLockerV4 } from "../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerV4Migrator }       from "../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { MapleGlobals as MapleGlobalsV2 }         from "../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy as MapleGlobalsNTP } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { Liquidator }            from "../../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory }     from "../../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleLoan as MapleLoanV400 }                     from "../../modules/loan-v400/contracts/MapleLoan.sol";
import { MapleLoanFeeManager }                            from "../../modules/loan-v400/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MapleLoanV4Initializer } from "../../modules/loan-v400/contracts/MapleLoanInitializer.sol";
import { MapleLoanV4Migrator }                            from "../../modules/loan-v400/contracts/MapleLoanV4Migrator.sol";
import { Refinancer }                                     from "../../modules/loan-v400/contracts/Refinancer.sol";

import { MapleLoan as MapleLoanV301 } from "../../modules/loan-v301/contracts/MapleLoan.sol";
import { MapleLoan as MapleLoanV302 } from "../../modules/loan-v302/contracts/MapleLoan.sol";
import { MapleLoan as MapleLoanV401 } from "../../modules/loan-v401/contracts/MapleLoan.sol";

import { AccountingChecker }                         from "../../modules/migration-helpers/contracts/checkers/AccountingChecker.sol";
import { DeactivationOracle }                        from "../../modules/migration-helpers/contracts/DeactivationOracle.sol";
import { MigrationHelper }                           from "../../modules/migration-helpers/contracts/MigrationHelper.sol";
import { NonTransparentProxy as MigrationHelperNTP } from "../../modules/migration-helpers/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { LoanManager }            from "../../modules/pool-v2/contracts/LoanManager.sol";
import { LoanManagerFactory }     from "../../modules/pool-v2/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../../modules/pool-v2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolDeployer }           from "../../modules/pool-v2/contracts/PoolDeployer.sol";
import { PoolManager }            from "../../modules/pool-v2/contracts/PoolManager.sol";
import { PoolManagerFactory }     from "../../modules/pool-v2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer } from "../../modules/pool-v2/contracts/proxy/PoolManagerInitializer.sol";
import { TransitionLoanManager }  from "../../modules/pool-v2/contracts/TransitionLoanManager.sol";

import { WithdrawalManager }            from "../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

import { GenericActions } from "./GenericActions.sol";

import {
    IDebtLockerLike,
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleLoanV4Like,
    IMapleProxiedLike,
    IMapleProxyFactoryLike,
    IMplRewardsLike,
    IPoolLike,
    IPoolV2Like,
    IPoolManagerLike,
    IStakeLockerLike,
    ITransitionLoanManagerLike
} from "./Interfaces.sol";

contract SimulationBase is GenericActions, AddressRegistry {

    struct PoolState {
        uint256 cash;
        uint256 interestSum;
        uint256 liquidityCap;
        uint256 poolLosses;
        uint256 principalOut;
        uint256 totalSupply;
    }

    // Deployment Addresses
    address debtLockerV4Migrator;
    address debtLockerV4Implementation;
    address deactivationOracle;

    address mapleLoanV302Implementation;
    address mapleLoanV400Implementation;
    address mapleLoanV401Implementation;
    address mapleLoanV4Initializer;
    address mapleLoanV4Migrator;

    address liquidatorImplementation;
    address liquidatorInitializer;

    address loanManagerImplementation;
    address loanManagerInitializer;
    address transitionLoanManagerImplementation;

    address poolManagerImplementation;
    address poolManagerInitializer;

    address withdrawalManagerImplementation;
    address withdrawalManagerInitializer;

    AccountingChecker internal accountingChecker;
    MigrationHelper   internal migrationHelper;

    MapleGlobalsV2      internal mapleGlobalsV2;
    MapleLoanFeeManager internal feeManager;
    PoolDeployer        internal poolDeployer;
    Refinancer          internal refinancer;

    LiquidatorFactory        internal liquidatorFactory;
    LoanManagerFactory       internal loanManagerFactory;
    PoolManagerFactory       internal poolManagerFactory;
    WithdrawalManagerFactory internal withdrawalManagerFactory;

    IPoolManagerLike internal icebreakerPoolManager;
    IPoolManagerLike internal mavenPermissionedPoolManager;
    IPoolManagerLike internal mavenUsdcPoolManager;
    IPoolManagerLike internal mavenWethPoolManager;
    IPoolManagerLike internal orthogonalPoolManager;

    mapping(address => IMapleLoanLike) internal migrationLoans;

    mapping(address => PoolState) internal poolStateSnapshot;

    mapping(address => address) internal loansOriginalLender;    // Store DebtLocker of loan for rollback
    mapping(address => address) internal temporaryPDs;

    mapping(address => uint256) internal coverAmounts;
    mapping(address => uint256) internal lastUpdatedTimestamps;  // Last timestamp that a LoanManager's accounting was updated
    mapping(address => uint256) internal loansAddedTimestamps;   // Timestamp when loans were added

    /******************************************************************************************************************************/
    /*** Migration lifecycle Functions                                                                                          ***/
    /******************************************************************************************************************************/

    function deployProtocol() internal {
        // Step 1: Deploy Globals (Set Governor to deployer)
        address mapleGlobalsV2Implementation = address(new MapleGlobalsV2());

        mapleGlobalsV2 = MapleGlobalsV2(address(new MapleGlobalsNTP(deployer, mapleGlobalsV2Implementation)));

        // Step 2: Deploy FeeManager
        feeManager = new MapleLoanFeeManager(address(mapleGlobalsV2));

        // Step 3: Deploy PoolDeployer
        poolDeployer = new PoolDeployer(address(mapleGlobalsV2));

        // Step 4: Liquidator Factory Deployments and Configuration
        liquidatorFactory        = new LiquidatorFactory(address(mapleGlobalsV2));
        liquidatorImplementation = address(new Liquidator());
        liquidatorInitializer    = address(new LiquidatorInitializer());

        liquidatorFactory.registerImplementation(200, liquidatorImplementation, liquidatorInitializer);
        liquidatorFactory.setDefaultVersion(200);

        // Step 5: Loan Manager Factory Deployments and Configuration
        loanManagerFactory                  = new LoanManagerFactory(address(mapleGlobalsV2));
        loanManagerImplementation           = address(new LoanManager());
        loanManagerInitializer              = address(new LoanManagerInitializer());
        transitionLoanManagerImplementation = address(new TransitionLoanManager());

        loanManagerFactory.registerImplementation(100, transitionLoanManagerImplementation, loanManagerInitializer);
        loanManagerFactory.registerImplementation(200, loanManagerImplementation,           loanManagerInitializer);
        loanManagerFactory.enableUpgradePath(100, 200, address(0));
        loanManagerFactory.setDefaultVersion(100);

        // Step 6: Pool Manager Factory Deployments and Configuration
        poolManagerFactory        = new PoolManagerFactory(address(mapleGlobalsV2));
        poolManagerImplementation = address(new PoolManager());
        poolManagerInitializer    = address(new PoolManagerInitializer());

        poolManagerFactory.registerImplementation(100, poolManagerImplementation, poolManagerInitializer);
        poolManagerFactory.setDefaultVersion(100);

        // Step 7: Withdrawal Manager Factory Deployments and Configuration
        withdrawalManagerFactory        = new WithdrawalManagerFactory(address(mapleGlobalsV2));
        withdrawalManagerImplementation = address(new WithdrawalManager());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        withdrawalManagerFactory.registerImplementation(100, withdrawalManagerImplementation, withdrawalManagerInitializer);
        withdrawalManagerFactory.setDefaultVersion(100);

        // Step 8: Loan Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        mapleLoanV302Implementation = address(new MapleLoanV302());
        mapleLoanV4Initializer      = address(new MapleLoanV4Initializer());
        mapleLoanV400Implementation = address(new MapleLoanV400());
        mapleLoanV401Implementation = address(new MapleLoanV401());
        mapleLoanV4Migrator         = address(new MapleLoanV4Migrator());

        // Step 9: DebtLocker Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        debtLockerV4Migrator       = address(new DebtLockerV4Migrator());
        debtLockerV4Implementation = address(new DebtLockerV4());

        // Step 10: Deploy MigrationHelper, AccountingChecker, and DeactivationOracle
        accountingChecker  = new AccountingChecker(address(mapleGlobalsV2));
        deactivationOracle = address(new DeactivationOracle());

        address migrationHelperImplementation = address(new MigrationHelper());

        migrationHelper = MigrationHelper(address(new MigrationHelperNTP(deployer, migrationHelperImplementation)));

        // TODO: This is needed, but should be after the loan stuff, which will result in different addresses for contracts after it.
        refinancer = new Refinancer();

        // Step 11: Configure MigrationHelper
        migrationHelper.setPendingAdmin(migrationMultisig);
        migrationHelper.setGlobals(address(mapleGlobalsV2));

        // Step 12: Configure Globals Addresses
        mapleGlobalsV2.setMapleTreasury(mapleTreasury);
        mapleGlobalsV2.setSecurityAdmin(securityAdminMultisig);
        mapleGlobalsV2.setMigrationAdmin(address(migrationHelper));

        // Step 13: Set Globals Valid Addresses
        mapleGlobalsV2.setValidPoolDeployer(address(poolDeployer), true);

        mapleGlobalsV2.setValidPoolDelegate(tempMavenPermissionedPD, true);
        mapleGlobalsV2.setValidPoolDelegate(tempMavenUsdcPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(tempMavenWethPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(tempOrthogonalPD,        true);
        mapleGlobalsV2.setValidPoolDelegate(tempIcebreakerPD,        true);

        // NOTE: Remove any where final PD is same as v1 PD
        mapleGlobalsV2.setValidPoolDelegate(finalMavenPermissionedPD, true);
        mapleGlobalsV2.setValidPoolDelegate(finalMavenUsdcPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(finalMavenWethPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(finalOrthogonalPD,        true);
        mapleGlobalsV2.setValidPoolDelegate(finalIcebreakerPD,        true);

        // NOTE: Not setting wbtc as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidPoolAsset(address(usdc), true);
        mapleGlobalsV2.setValidPoolAsset(address(weth), true);

        // NOTE: Not setting usdc and weth as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidCollateralAsset(address(wbtc), true);

        mapleGlobalsV2.setValidFactory("LIQUIDATOR",         address(liquidatorFactory),        true);
        mapleGlobalsV2.setValidFactory("LOAN",               address(loanFactory),              true);
        mapleGlobalsV2.setValidFactory("LOAN_MANAGER",       address(loanManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("POOL_MANAGER",       address(poolManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("WITHDRAWAL_MANAGER", address(withdrawalManagerFactory), true);

        // Step 14: Configure Globals Values
        mapleGlobalsV2.setBootstrapMint(address(usdc), 0.100000e6);
        mapleGlobalsV2.setBootstrapMint(address(weth), 0.0001e18);

        mapleGlobalsV2.setDefaultTimelockParameters(1 weeks, 2 days);

        // Step 15: Configure oracles
        mapleGlobalsV2.setPriceOracle(address(wbtc), address(btcUsdOracle));
        mapleGlobalsV2.setPriceOracle(address(usdc), address(usdUsdOracle));
        mapleGlobalsV2.setPriceOracle(address(weth), address(ethUsdOracle));

        // Step 16: Transfer governor
        mapleGlobalsV2.setPendingGovernor(tempGovernor);
    }

    function storeCoverAmounts() internal {
        // Save the necessary pool cover amount for each pool
        coverAmounts[address(mavenPermissionedPoolV1)] = 1_750_000e6;
        coverAmounts[address(mavenUsdcPoolV1)]         = 1_000_000e6;
        coverAmounts[address(mavenWethPoolV1)]         = 750e18;
        coverAmounts[address(orthogonalPoolV1)]        = 2_500_000e6;
        coverAmounts[address(icebreakerPoolV1)]        = 500_000e6;
    }

    function performAdditionalGlobalsSettings() internal {
        vm.startPrank(governor);

        mapleGlobalsV2.setValidPoolAsset(address(wbtc), true);

        mapleGlobalsV2.setValidCollateralAsset(address(usdc), true);
        mapleGlobalsV2.setValidCollateralAsset(address(weth), true);

        vm.stopPrank();
    }

    function tempGovernorAcceptsV2Governorship() internal {
        vm.prank(tempGovernor);
        mapleGlobalsV2.acceptGovernor();
    }

    function migrationMultisigAcceptsMigrationAdministratorship() internal {
        vm.prank(migrationMultisig);
        migrationHelper.acceptOwner();
    }

    function setupExistingFactories() internal {
        vm.startPrank(governor);

        debtLockerFactory.registerImplementation(400, address(new DebtLockerV4()), debtLockerV3Initializer);
        debtLockerFactory.enableUpgradePath(200, 400, debtLockerV4Migrator);
        debtLockerFactory.enableUpgradePath(300, 400, debtLockerV4Migrator);

        loanFactory.registerImplementation(302, address(new MapleLoanV302()), loanV3Initializer);
        loanFactory.registerImplementation(400, address(new MapleLoanV400()), mapleLoanV4Initializer);
        loanFactory.registerImplementation(401, address(new MapleLoanV401()), mapleLoanV4Initializer);
        loanFactory.enableUpgradePath(301, 302, address(0));
        loanFactory.enableUpgradePath(302, 400, address(new MapleLoanV4Migrator()));
        loanFactory.enableUpgradePath(400, 401, address(0));
        loanFactory.setDefaultVersion(301);

        vm.stopPrank();
    }

    function finalizeFactories() internal {
        vm.startPrank(governor);

        loanFactory.setDefaultVersion(401);
        loanManagerFactory.setDefaultVersion(200);

        vm.stopPrank();
    }

    function migrateAllPools() internal {
        payAndClaimAllUpcomingLoans();

        freezeAllPoolV1s();        // 2 hours * 5 pools
        setV1ProtocolPause(true);

        deployAndMigrateAllPools();
        compareAllLpPositions();

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));  // 2min

        payBackAllCashLoan();
        upgradeAllLoansToV401();
        transferAllPoolDelegates();

        vm.prank(tempGovernor);
        mapleGlobalsV2.setPendingGovernor(governor);
    }

    function postMigration() internal {
        vm.prank(governor);
        mapleGlobalsV2.acceptGovernor();

        // Dec 8
        setV1ProtocolPause(false);

        // Dec 8
        deprecateAllPoolV1s();
        handleCoverProviderEdgeCase();

        // Make cover providers withdraw
        withdrawAllCovers();

        // TODO: Reconsider when this should be done, as new loans for PoolV2s will be an incompatible version
        finalizeFactories();
    }

    /******************************************************************************************************************************/
    /*** Migration Building Blocks                                                                                              ***/
    /******************************************************************************************************************************/

    function payAndClaimUpcomingLoans(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length;) {
            IMapleLoanLike loan       = loans[i];
            IERC20Like     fundsAsset = IERC20Like(loan.fundsAsset());

            uint256 paymentDueDate = loan.nextPaymentDueDate();

            // If the loan is more than 5 days early, skip it
            if (paymentDueDate > block.timestamp && paymentDueDate - block.timestamp >= 5 days) {
                ++i;
                continue;
            }

            ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = loan.getNextPaymentBreakdown();

            uint256 paymentAmount = principal + interest + delegateFee + treasuryFee;

            erc20_mint(address(fundsAsset), loan.borrower(), paymentAmount);

            vm.startPrank(loan.borrower());

            fundsAsset.approve(address(loan), paymentAmount);
            loan.makePayment(paymentAmount);

            vm.stopPrank();

            IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

            IPoolLike pool = IPoolLike(debtLocker.pool());

            vm.prank(debtLocker.poolDelegate());
            pool.claim(address(loan), address(debtLockerFactory));

            if (loan.paymentsRemaining() > 0) {
                ++i;
                continue;
            }

            // Remove loan from array as it no longer needs to be migrated.
            // NOTE: Since ith loan is replaced with the last loan, don't increment i.
            loans[i] = loans[loans.length - 1];
            loans.pop();
        }

        // Check skimmable amount
        checkUnaccountedAmount(loans);
    }

    function migrationKickoffOnPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans, address temporaryPoolDelegate) internal {
        /*************************************************/
        /*** Step 1: Upgrade all DebtLockers to v4.0.0 ***/
        /*************************************************/

        upgradeDebtLockersToV400(loans);  // 30min

        /******************************************************************/
        /*** Step 2: Lock Pool deposits by setting liquidityCap to zero ***/
        /******************************************************************/

        lockPoolV1Deposits(poolV1);  // 5min

        /*******************************************/
        /** Step 3: Ensure all loans are claimed ***/
        /*******************************************/

        claimAllLoans(poolV1, loans);  // 20min

        /***************************************************************************/
        /*** Step 4: Lock all actions on the loan by migrating it to v3.02       ***/
        /***************************************************************************/

        upgradeLoansToV302(loans);  // 30min (should pre-build transaction)

        // TODO: Add step to check claimable again here.

        /***************************************************************************/
        /*** Step 5: Lock Pool withdrawals by funding a loan with remaining cash ***/
        /***************************************************************************/

        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);

        if (availableLiquidity > 0) {
            // Create a loan using all of the available cash in the pool (if there is any).
            IMapleLoanLike migrationLoan = createMigrationLoan(temporaryPoolDelegate, poolV1, loans, availableLiquidity);  // 5min

            // Upgrade the newly created debt locker of the migration loan.
            upgradeDebtLockerToV400(migrationLoan);  // 5min

            // Upgrade migration loan to 302
            upgradeLoanToV302(migrationLoan);
        }
    }

    function addLoansToLoanManager(IPoolManagerLike poolManager, address poolV1, IMapleLoanLike[] storage loans) internal {
        ITransitionLoanManagerLike transitionLoanManager = ITransitionLoanManagerLike(poolManager.loanManagerList(0));

        vm.prank(migrationMultisig);
        migrationHelper.addLoansToLoanManager(poolV1, address(transitionLoanManager), convertToAddresses(loans), 201e6);  // TODO: Change to 2 once Ortho loans are claimed pre-deployment
    }

    function activatePoolManager(address poolManager) internal {
        vm.prank(tempGovernor);
        mapleGlobalsV2.activatePoolManager(poolManager);
    }

    function allowLendersAndWithdrawalManager(IPoolManagerLike poolManager, address[] storage lenders) internal {
        for (uint256 i; i < lenders.length; ++i) {
            allowLender(address(poolManager), lenders[i]);
        }

        allowLender(address(poolManager), poolManager.withdrawalManager());
    }

    function airdropTokens(address poolV1, address poolManager, address[] storage lps) internal {
        // TODO: Add functionality to allowlist LPs in case of permissioned pool prior to airdrop.
        vm.startPrank(migrationMultisig);
        migrationHelper.airdropTokens(poolV1, address(poolManager), lps, lps, lps.length * 2);
        vm.stopPrank();
    }

    function setPendingLenders(address poolV1, address poolManager, IMapleLoanLike[] storage loans) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.setPendingLenders(address(poolV1), address(poolManager), address(loanFactory), convertToAddresses(loans), 201e6);
        vm.stopPrank();
    }

    function takeOwnershipOfLoans(address poolV1, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.takeOwnershipOfLoans(poolV1, poolManager.loanManagerList(0), convertToAddresses(loans), 201e6);
        vm.stopPrank();
    }

    function migrationStepsUpToLoanManagerUpgrade(address temporaryPD, IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        /*******************************/
        /*** Step 4: Deploy new Pool ***/
        /*******************************/

        // Deploy the new version of the pool.
        poolManager = IPoolManagerLike(deployPoolV2(temporaryPD, poolV1));  // 30min

        /***************************************************************/
        /*** Step 5: Add Loans to LM, setting up parallel accounting ***/
        /***************************************************************/

        addLoansToLoanManager(poolManager, address(poolV1), loans);

        loansAddedTimestamps[address(poolManager)] = lastUpdatedTimestamps[address(poolManager)] = block.timestamp;

        /**********************************************/
        /*** Step 6: Activate the Pool from Globals ***/
        /**********************************************/

        activatePoolManager(address(poolManager));  // 2min

        /*****************************************************************************/
        /*** Step 7: Open the Pool or allowlist the pool to allow airdrop to occur ***/
        /*****************************************************************************/

        if (open) {
            openPool(address(poolManager));  // 5min
        } else {
            allowLendersAndWithdrawalManager(poolManager, lps);  // 5min
        }

        /**********************************************************/
        /*** Step 8: Airdrop PoolV2 LP tokens to all PoolV1 LPs ***/
        /**********************************************************/

        airdropTokens(address(poolV1), address(poolManager), lps);  // 1 hour

        assertPoolAccounting(poolManager, loans);

        /*****************************************************************************/
        /*** Step 9: Set the pending lender in all outstanding Loans to be the TLM ***/
        /*****************************************************************************/

        setPendingLenders(address(poolV1), address(poolManager), loans);

        assertPoolAccounting(poolManager, loans);

        /*********************************************************************************/
        /*** Step 10: Accept the pending lender in all outstanding Loans to be the TLM ***/
        /*********************************************************************************/

        takeOwnershipOfLoans(address(poolV1), poolManager, loans);

        assertPoolAccounting(poolManager, loans);
    }

    function upgradeLoanManager(address transitionLoanManager) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.upgradeLoanManager(transitionLoanManager, 200);
        vm.stopPrank();
    }

    function migrationStepsIncludingLoanManagerUpgrade(address temporaryPD, IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        poolManager = migrationStepsUpToLoanManagerUpgrade(temporaryPD, poolV1, loans, lps, open);

        /*****************************************************/
        /*** Step 11: Upgrade the LoanManager from the TLM ***/
        /*****************************************************/

        upgradeLoanManager(poolManager.loanManagerList(0));

        // NOTE: transitionLoanManager is now a normal loanManager.
        assertPrincipalOut(poolManager.loanManagerList(0), loans);
        assertEq(IPoolLike(poolManager.pool()).totalSupply(), getPoolV1TotalValue(poolV1));
        assertPoolAccounting(poolManager, loans);

        // TODO: Add assertions against PoolV1
    }

    function setCoverParameters(address poolManager, address poolV1) internal {
        // Configure the min cover amount in globals
        vm.startPrank(tempGovernor);
        mapleGlobalsV2.setMinCoverAmount(poolManager, coverAmounts[poolV1]);
        mapleGlobalsV2.setMaxCoverLiquidationPercent(poolManager, 0.5e6);
        vm.stopPrank();
    }

    function deployAndMigratePool(address temporaryPD, IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        poolManager = migrationStepsIncludingLoanManagerUpgrade(temporaryPD, poolV1, loans, lps, open);

        setCoverParameters(address(poolManager), address(poolV1));

        /****************************************/
        /*** Step 12: Upgrade all loans to V4 ***/
        /****************************************/

        assertPoolAccounting(poolManager, loans);

        upgradeLoansToV400(loans);
    }

    function payBackCashLoan(address poolV1, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        /******************************************************************/
        /*** Step 13: Close the cash loan, adding liquidity to the pool ***/
        /******************************************************************/

        IMapleLoanLike migrationLoan = migrationLoans[poolV1];

        assertPoolAccounting(poolManager, loans);

        if (address(migrationLoan) != address(0)) {
            closeMigrationLoan(migrationLoan, loans);
            lastUpdatedTimestamps[address(poolManager)] = block.timestamp;
        }

        assertPoolAccounting(poolManager, loans);
    }

    function deprecatePoolV1(IPoolLike poolV1, IMplRewardsLike rewards, IStakeLockerLike stakeLocker, uint256 delegateBalance_) internal {
        address poolDelegate_ = poolV1.poolDelegate();

        /***********************************/
        /*** Step 1: Deactivate Pool V1 ***/
        /***********************************/

        deactivatePoolV1(poolV1);

        /********************************/
        /*** Step 2: Exit MPL Rewards ***/
        /********************************/

        if (address(rewards) != address(0)) {
            exitRewards(rewards, stakeLocker, poolDelegate_);
        }

        /**********************************/
        /*** Step 3: Request to unstake ***/
        /**********************************/

        // Assert that the provided balance matches the stake locker balance.
        assertEq(stakeLocker.balanceOf(poolDelegate_), delegateBalance_);

        if (delegateBalance_ > 0) {
            requestUnstake(stakeLocker, poolDelegate_);

            unstakeDelegateCover(stakeLocker, poolDelegate_, delegateBalance_);
        }
    }

    /******************************************************************************************************************************/
    /*** Contingency Helpers                                                                                                    ***/
    /******************************************************************************************************************************/

    function enableLoanAndDebtLockerDowngrades() internal {
        vm.startPrank(governor);
        debtLockerFactory.enableUpgradePath(400, 300, address(0));
        loanFactory.enableUpgradePath(302, 301, address(0));
        vm.stopPrank();
    }

    function configureLoanFactoryFor400To302Downgrade() internal {
        vm.prank(mapleGlobalsV2.governor());
        loanFactory.enableUpgradePath(400, 302, address(0));
    }

    function setLoanTransferAdmin(IPoolManagerLike poolManager) internal {
        ILoanManagerLike loanManager = ILoanManagerLike(poolManager.loanManagerList(0));

        vm.prank(poolManager.poolDelegate());
        loanManager.setLoanTransferAdmin(address(migrationHelper));
    }

    function rollbackMigrationKickoffOnPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans, uint256 liquidityCap) internal {
        enableLoanAndDebtLockerDowngrades();

        downgradeLoans302To301(loans);

        downgradeDebtLockersTo300(loans);

        paybackMigrationLoanToPoolV1(poolV1, loans);

        setLiquidityCap(address(poolV1), liquidityCap);
    }

    function rollbackFromTransferredLoans(IPoolLike pool, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans, uint256 liquidityCap) internal {
        setV1ProtocolPause(false);

        returnLoansToDebtLocker(poolManager.loanManagerList(0), loans);
        rollbackMigrationKickoffOnPoolV1(pool, loans, liquidityCap);
    }

    function rollbackFromUpgradedLoanManager(IPoolLike pool, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans, uint256 liquidityCap) internal {
        setLoanTransferAdmin(poolManager);

        rollbackFromTransferredLoans(pool, poolManager, loans, liquidityCap);
    }

    function rollbackFromUpgradedV4Loans(IPoolLike pool, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans, uint256 liquidityCap) internal {
        vm.prank(mapleGlobalsV2.governor());
        loanFactory.enableUpgradePath(400, 302, address(0));

        downgradeLoans400To302(loans);

        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV1));

        rollbackFromUpgradedLoanManager(pool, poolManager, loans, liquidityCap);
    }

    /****************************************************************************************************************************/
    /*** Batch Functions                                                                                                      ***/
    /****************************************************************************************************************************/

    function upgradeAllLoansToV301() internal {
        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);
    }

    function payAndClaimAllUpcomingLoans() internal {
        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);
    }

    function freezeAllPoolV1s() internal {
        migrationKickoffOnPoolV1(mavenWethPoolV1,         mavenWethLoans,         tempMavenWethPD);
        migrationKickoffOnPoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         tempMavenUsdcPD);
        migrationKickoffOnPoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, tempMavenPermissionedPD);
        migrationKickoffOnPoolV1(orthogonalPoolV1,        orthogonalLoans,        tempOrthogonalPD);
        migrationKickoffOnPoolV1(icebreakerPoolV1,        icebreakerLoans,        tempIcebreakerPD);
    }

    function deployAndMigrateAllPools() internal {
        mavenWethPoolManager         = deployAndMigratePool(tempMavenWethPD,         mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePool(tempMavenUsdcPD,         mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePool(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePool(tempOrthogonalPD,        orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePool(tempIcebreakerPD,        icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);
    }

    function compareAllLpPositions() internal {
        compareLpPositions(mavenWethPoolV1,         mavenWethPoolManager.pool(),         mavenWethLps);
        compareLpPositions(mavenUsdcPoolV1,         mavenUsdcPoolManager.pool(),         mavenUsdcLps);
        compareLpPositions(mavenPermissionedPoolV1, mavenPermissionedPoolManager.pool(), mavenPermissionedLps);
        compareLpPositions(orthogonalPoolV1,        orthogonalPoolManager.pool(),        orthogonalLps);
        compareLpPositions(icebreakerPoolV1,        icebreakerPoolManager.pool(),        icebreakerLps);
    }

    function payBackAllCashLoan() internal {
        payBackCashLoan(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        payBackCashLoan(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        payBackCashLoan(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        payBackCashLoan(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        payBackCashLoan(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);
    }

    function upgradeAllLoansToV401() internal {
        upgradeLoansToV401(mavenWethLoans);
        upgradeLoansToV401(mavenUsdcLoans);
        upgradeLoansToV401(mavenPermissionedLoans);
        upgradeLoansToV401(orthogonalLoans);
        upgradeLoansToV401(icebreakerLoans);
    }

    function transferAllPoolDelegates() internal {
        transferPoolDelegate(mavenWethPoolManager,         finalMavenWethPD);
        transferPoolDelegate(mavenUsdcPoolManager,         finalMavenUsdcPD);
        transferPoolDelegate(mavenPermissionedPoolManager, finalMavenPermissionedPD);
        transferPoolDelegate(orthogonalPoolManager,        finalOrthogonalPD);
        transferPoolDelegate(icebreakerPoolManager,        finalIcebreakerPD);
    }

    function deprecateAllPoolV1s() internal {
        deprecatePoolV1(mavenWethPoolV1,         mavenWethRewards,         mavenWethStakeLocker,         125_049.87499e18);
        deprecatePoolV1(mavenUsdcPoolV1,         mavenUsdcRewards,         mavenUsdcStakeLocker,         153.022e18);
        deprecatePoolV1(mavenPermissionedPoolV1, mavenPermissionedRewards, mavenPermissionedStakeLocker, 16.319926286804447168e18);
        deprecatePoolV1(orthogonalPoolV1,        orthogonalRewards,        orthogonalStakeLocker,        175.122243323160822654e18);
        deprecatePoolV1(icebreakerPoolV1,        icebreakerRewards,        icebreakerStakeLocker,        104.254119288711119987e18);
    }

    function withdrawAllCovers() internal {
        withdrawCover(mavenWethStakeLocker,         mavenWethRewards,         mavenWethCoverProviders);
        withdrawCover(mavenPermissionedStakeLocker, mavenPermissionedRewards, mavenPermissionedCoverProviders);
        withdrawCover(icebreakerStakeLocker,        icebreakerRewards,        icebreakerCoverProviders);
        withdrawCover(mavenUsdcStakeLocker,         mavenUsdcRewards,         mavenUsdcCoverProviders);
        withdrawCover(orthogonalStakeLocker,        orthogonalRewards,        orthogonalCoverProviders);
    }

    function depositAllCovers() internal {
        depositCover(address(mavenWethPoolManager),         750e18);
        depositCover(address(mavenUsdcPoolManager),         1_000_000e6);
        depositCover(address(mavenPermissionedPoolManager), 1_750_000e6);
        depositCover(address(orthogonalPoolManager),        2_500_000e6);
        depositCover(address(icebreakerPoolManager),        500_000e6);
    }

    function increaseAllLiquidityCaps() internal {
        setLiquidityCap(address(mavenWethPoolManager),         100_000e18);
        setLiquidityCap(address(mavenUsdcPoolManager),         100_000_000e6);
        setLiquidityCap(address(mavenPermissionedPoolManager), 100_000_000e6);
        setLiquidityCap(address(orthogonalPoolManager),        100_000_000e6);
        setLiquidityCap(address(icebreakerPoolManager),        100_000_000e6);
    }

    function snapshotAllPoolStates() internal {
        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);
    }

    function unfreezeAllPoolV1s() internal {
        rollbackMigrationKickoffOnPoolV1(mavenWethPoolV1,         mavenWethLoans,         35_000e18);
        rollbackMigrationKickoffOnPoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans, 60_000_000e6);
        rollbackMigrationKickoffOnPoolV1(mavenUsdcPoolV1,         mavenUsdcLoans,         350_000_000e6);
        rollbackMigrationKickoffOnPoolV1(orthogonalPoolV1,        orthogonalLoans,        450_000_000e6);
        rollbackMigrationKickoffOnPoolV1(icebreakerPoolV1,        icebreakerLoans,        300_000_000e6);
    }

    function assertAllPoolsMatchSnapshot() internal {
        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertPoolMatchesSnapshot(icebreakerPoolV1);
    }

    function assertAllLoansBelongToRespectivePools() internal {
        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

    function storeAllOriginalLoanLenders() internal {
        storeOriginalLoanLender(mavenWethLoans);
        storeOriginalLoanLender(mavenUsdcLoans);
        storeOriginalLoanLender(mavenPermissionedLoans);
        storeOriginalLoanLender(orthogonalLoans);
        storeOriginalLoanLender(icebreakerLoans);
    }

    function deployAndMigrateAllPoolsUpToLoanManagerUpgrade() internal {
        mavenWethPoolManager         = migrationStepsUpToLoanManagerUpgrade(tempMavenWethPD,         mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = migrationStepsUpToLoanManagerUpgrade(tempMavenUsdcPD,         mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = migrationStepsUpToLoanManagerUpgrade(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = migrationStepsUpToLoanManagerUpgrade(tempOrthogonalPD,        orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = migrationStepsUpToLoanManagerUpgrade(tempIcebreakerPD,        icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);
    }

    function returnAllLoansToDebtLockers() internal {
        returnLoansToDebtLocker(mavenWethPoolManager.loanManagerList(0),         mavenWethLoans);
        returnLoansToDebtLocker(mavenUsdcPoolManager.loanManagerList(0),         mavenUsdcLoans);
        returnLoansToDebtLocker(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        returnLoansToDebtLocker(orthogonalPoolManager.loanManagerList(0),        orthogonalLoans);
        returnLoansToDebtLocker(icebreakerPoolManager.loanManagerList(0),        icebreakerLoans);
    }

    function setAllLoanTransferAdmins() internal {
        setLoanTransferAdmin(mavenWethPoolManager);
        setLoanTransferAdmin(mavenUsdcPoolManager);
        setLoanTransferAdmin(mavenPermissionedPoolManager);
        setLoanTransferAdmin(orthogonalPoolManager);
        setLoanTransferAdmin(icebreakerPoolManager);
    }

    function downgradeAllLoans400To302() internal {
        downgradeLoans400To302(mavenWethLoans);
        downgradeLoans400To302(mavenUsdcLoans);
        downgradeLoans400To302(mavenPermissionedLoans);
        downgradeLoans400To302(orthogonalLoans);
        downgradeLoans400To302(icebreakerLoans);
    }

    function deployAndMigrateAllPoolsUpToLoanUpgrade() internal {
        mavenWethPoolManager         = migrationStepsIncludingLoanManagerUpgrade(tempMavenWethPD,         mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = migrationStepsIncludingLoanManagerUpgrade(tempMavenUsdcPD,         mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = migrationStepsIncludingLoanManagerUpgrade(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = migrationStepsIncludingLoanManagerUpgrade(tempOrthogonalPD,        orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = migrationStepsIncludingLoanManagerUpgrade(tempIcebreakerPD,        icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);
    }

    /******************************************************************************************************************************/
    /*** Utility Functions                                                                                                      ***/
    /******************************************************************************************************************************/

    function assertVersion(uint256 version_ , address instance_) internal {
        assertEq(
            IMapleProxiedLike(instance_).implementation(),
            IMapleProxyFactoryLike(IMapleProxiedLike(instance_).factory()).implementationOf(version_)
        );
    }

    function assertFinalState() internal {
        // TODO: Add additional assertions here.
    }

    function assertInitialState() internal {
        // TODO: Add additional assertions here.
        assertTrue(debtLockerFactory.upgradeEnabledForPath(200, 400));
    }

    function assertLoansBelongToPool(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IDebtLockerLike(loans[i].lender()).pool(), address(poolV1));
        }
    }

    function assertPoolAccounting(IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        uint256 loansAddedTimestamp  = loansAddedTimestamps[address(poolManager)];
        uint256 lastUpdatedTimestamp = lastUpdatedTimestamps[address(poolManager)];

        for (uint256 i; i < 1; ++i) {
            (
                uint256 expectedTotalAssets,
                uint256 returnedTotalAssets,
                uint256 expectedDomainEnd_,
                uint256 actualDomainEnd_
            ) = accountingChecker.checkPoolAccounting(address(poolManager), convertToAddresses(loans), loansAddedTimestamp, lastUpdatedTimestamp);

            assertWithinDiff(returnedTotalAssets, expectedTotalAssets, loans.length);

            assertEq(actualDomainEnd_, expectedDomainEnd_);

            vm.warp(block.timestamp + 1 minutes);
        }
    }

    // This could be refactored to be a more useful function, taking in an expected difference as parameter for each variable.
    function assertPoolMatchesSnapshot(IPoolLike poolV1) internal {
        PoolState storage poolState = poolStateSnapshot[address(poolV1)];

        IERC20Like poolAsset = IERC20Like(poolV1.liquidityAsset());

        assertEq(poolAsset.balanceOf(poolV1.liquidityLocker()), poolState.cash);
        assertEq(poolV1.interestSum(),                          poolState.interestSum);
        assertEq(poolV1.liquidityCap(),                         poolState.liquidityCap);
        assertEq(poolV1.poolLosses(),                           poolState.poolLosses);
        assertEq(poolV1.principalOut(),                         poolState.principalOut);
        assertEq(poolV1.totalSupply(),                          poolState.totalSupply);
    }

    function assertPrincipalOut(address transitionLoanManager, IMapleLoanLike[] storage loans) internal {
        uint256 totalPrincipal;
        for (uint i = 0; i < loans.length; i++) {
            totalPrincipal += loans[i].principal();
        }

        assertEq(ITransitionLoanManagerLike(transitionLoanManager).principalOut(), totalPrincipal);
    }

    function calculateAvailableLiquidity(IPoolLike poolV1) internal view returns (uint256 availableLiquidity) {
        availableLiquidity = IERC20Like(poolV1.liquidityAsset()).balanceOf(poolV1.liquidityLocker());
    }

    function checkUnaccountedAmount(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            // Since there's no public `getUnaccountedAmount()` function, we have to calculate it ourselves.
            IMapleLoanLike loan        = loans[i];
            IERC20Like fundsAsset      = IERC20Like(loan.fundsAsset());
            IERC20Like collateralAsset = IERC20Like(loan.collateralAsset());

            assertEq(fundsAsset.balanceOf(address(loan)),      loan.claimableFunds() + loan.drawableFunds());
            assertEq(collateralAsset.balanceOf(address(loan)), loan.collateral());
        }
    }

    function compareLpPositions(IPoolLike poolV1, address poolV2, address[] storage lps) internal {
        uint256 poolV1TotalValue  = getPoolV1TotalValue(poolV1);
        uint256 poolV2TotalSupply = IPoolLike(poolV2).totalSupply();
        uint256 sumPosition       = getSumPosition(poolV1, lps);

        for (uint256 i; i < lps.length; ++i) {
            uint256 v1Position = getV1Position(poolV1, lps[i]);
            uint256 v2Position = IPoolLike(poolV2).balanceOf(lps[i]);

            if (i == 0) {
                v1Position += poolV1TotalValue > sumPosition ? poolV1TotalValue - sumPosition : 0;
            }

            uint256 v1Equity = v1Position * 1e18 / poolV1TotalValue;
            uint256 v2Equity = v2Position * 1e18 / poolV2TotalSupply;

            assertEq(v1Position, v2Position);
            assertEq(v1Equity,   v2Equity);
        }
    }

    function claimAllLoans(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        address poolDelegate = poolV1.poolDelegate();

        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            if (loan.claimableFunds() == 0) continue;

            address debtLockerFactory = IMapleProxiedLike(loan.lender()).factory();

            vm.prank(poolDelegate);
            poolV1.claim(address(loan), debtLockerFactory);
        }
    }

    function closeMigrationLoan(IMapleLoanLike migrationLoan, IMapleLoanLike[] storage loans) internal {
        ( , , uint256 fees ) = IMapleLoanV4Like(address(migrationLoan)).getNextPaymentBreakdown();

        erc20_mint(migrationLoan.fundsAsset(), migrationLoan.borrower(), fees);

        vm.startPrank(migrationLoan.borrower());

        IERC20Like(migrationLoan.fundsAsset()).approve(address(migrationLoan), fees);
        migrationLoan.returnFunds(fees);
        migrationLoan.closeLoan(0);

        vm.stopPrank();

        uint256 i;
        while (loans[i] != migrationLoan) i++;

        // Move last element to index of removed loan manager and pop last element.
        loans[i] = loans[loans.length - 1];
        loans.pop();
    }

    function convertToAddresses(IMapleLoanLike[] storage inputArray) internal view returns (address[] memory outputArray) {
        outputArray = new address[](inputArray.length);
        for (uint256 i = 0; i < inputArray.length; i++) {
            outputArray[i] = address(inputArray[i]);
        }
    }

    function createMigrationLoan(address borrower, IPoolLike poolV1, IMapleLoanLike[] storage loans, uint256 liquidity) internal returns (IMapleLoanLike migrationLoan) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        address[2] memory assets      = [address(asset), address(asset)];
        uint256[3] memory termDetails = [uint256(0), uint256(30 days), uint256(1)];
        uint256[3] memory requests    = [uint256(0), liquidity, liquidity];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory args = abi.encode(borrower, assets, termDetails, requests, rates);
        bytes32 salt      = keccak256(abi.encode(address(poolV1)));
        migrationLoan     = IMapleLoanLike(loanFactory.createInstance(args, salt));

        vm.prank(poolV1.poolDelegate());
        poolV1.fundLoan(address(migrationLoan), address(debtLockerFactory), liquidity);

        assertEq(asset.balanceOf(poolV1.liquidityLocker()), 0);

        loans.push(migrationLoan);
        migrationLoans[address(poolV1)] = migrationLoan;
    }

    function deactivatePoolV1(IPoolLike poolV1) internal {
        address asset = poolV1.liquidityAsset();
        DeactivationOracle oracle = new DeactivationOracle();

        vm.startPrank(governor);
        mapleGlobalsV1.setPriceOracle(asset, address(oracle));
        mapleGlobalsV1.setStakerCooldownPeriod(0);
        mapleGlobalsV1.setStakerUnstakeWindow(type(uint256).max);
        vm.stopPrank();

        vm.startPrank(poolV1.poolDelegate());
        poolV1.deactivate();
        IStakeLockerLike(poolV1.stakeLocker()).setLockupPeriod(0);
        vm.stopPrank();
    }

    function deployPoolV2(address temporaryPD, IPoolLike poolV1) internal returns (IPoolManagerLike poolManager) {
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
            0,
            0.1e6,
            0,
            7 days,
            2 days,
            getPoolV1TotalValue(poolV1)
        ];

        address liquidityAsset = poolV1.liquidityAsset();
        string memory name     = poolV1.name();
        string memory symbol   = poolV1.symbol();

        vm.prank(temporaryPD);
        ( address poolManagerAddress, , ) = poolDeployer.deployPool(
            factories,
            initializers,
            liquidityAsset,
            name,
            symbol,
            configParams
        );

        poolManager = IPoolManagerLike(poolManagerAddress);
    }

    function downgradeDebtLockersTo300(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            vm.prank(mapleGlobalsV1.globalAdmin());
            debtLocker.upgrade(300, new bytes(0));

            assertVersion(300, address(debtLocker));
        }
    }

    function downgradeLoans400To302(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            vm.prank(securityAdminMultisig);
            loan.upgrade(302, new bytes(0));

            assertVersion(302, address(loan));
        }
    }

    function downgradeLoans302To301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            vm.prank(globalAdmin);
            loan.upgrade(301, new bytes(0));

            assertVersion(301, address(loan));
        }
    }

    function downgradeLoanManager(IPoolManagerLike poolManager, address loanManager_) internal {
        // Set Loan transfer admin on LoanManager
        vm.prank(poolManager.poolDelegate());
        ILoanManagerLike(loanManager_).setLoanTransferAdmin(address(migrationHelper));

        vm.prank(governor);
        IMapleProxiedLike(loanManager_).upgrade(100, new bytes(0));
    }

    function exitRewards(IMplRewardsLike rewards, IStakeLockerLike stakeLocker, address poolDelegate) internal {
        if (stakeLocker.custodyAllowance(poolDelegate, address(rewards)) == 0) return;

        vm.prank(poolDelegate);
        rewards.exit();
    }

    function isEarlierThan(uint256 timestamp, uint256 threshold) internal pure returns (bool isEarlier) {
        if (timestamp == 0) return false;

        if (threshold == 0) return true;

        return timestamp < threshold;
    }

    function getNextLoanAndPaymentDueDate(IMapleLoanLike[] storage loans) internal view returns (address loan, uint256 nextPaymentDueDate) {
        for (uint256 i; i < loans.length; ++i) {
            uint256 dueDate = loans[i].nextPaymentDueDate();

            if (!isEarlierThan(dueDate, nextPaymentDueDate)) continue;

            loan               = address(loans[i]);
            nextPaymentDueDate = dueDate;
        }
    }

    function getNextLoan(IMapleLoanLike[] storage loans) internal view returns (address loan) {
        ( loan, ) = getNextLoanAndPaymentDueDate(loans);
    }

    function getNextLoan() internal view returns (address loan) {
        uint256 nextPaymentDueDate;
        address tempLoan;
        uint256 tempNextPaymentDueDate;

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(icebreakerLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenPermissionedLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenUsdcLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenWethLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(orthogonalLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

    }

    function getV1Position(IPoolLike poolV1, address lp) internal view returns (uint256 positionValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        positionValue = poolV1.balanceOf(lp) * 10 ** asset.decimals() / 1e18 + poolV1.withdrawableFundsOf(lp) - poolV1.recognizableLossesOf(lp);
    }

    function getSumPosition(IPoolLike poolV1, address[] storage lps) internal view returns (uint256 positionValue) {
        for (uint256 i = 0; i < lps.length; i++) {
            positionValue += getV1Position(poolV1, lps[i]);
        }
    }

    function getPoolV1TotalValue(IPoolLike poolV1) internal view returns (uint256 totalValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        totalValue = poolV1.totalSupply() * 10 ** asset.decimals() / 1e18 + poolV1.interestSum() - poolV1.poolLosses();
    }

    function handleCoverProviderEdgeCase() internal {
        // Handle weird scenario in maven usdc and orthogonal pool, where users have increased the allowance, but haven't actually staked.
        vm.prank(0x8476D9239fe38Ca683c6017B250112121cdB8D9B);
        IMplRewardsLike(address(orthogonalRewards)).stake(701882135971108600);

        vm.prank(0xFe14c77979Ea159605b0fABDeB59B1166C3D95e3);
        IMplRewardsLike(address(mavenUsdcRewards)).stake(299953726765028070);
    }

    function lockPoolV1Deposits(IPoolLike poolV1) internal {
        setLiquidityCap(address(poolV1), 0);
    }

    function paybackMigrationLoanToPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        IMapleLoanLike migrationLoan = migrationLoans[address(poolV1)];

        if (address(migrationLoan) == address(0)) return;

        ( , , uint256 delegateFees, uint256 platformFees ) = migrationLoan.getNextPaymentBreakdown();

        uint256 fees = delegateFees + platformFees;

        erc20_mint(migrationLoan.fundsAsset(), migrationLoan.borrower(), fees);

        vm.startPrank(migrationLoan.borrower());

        IERC20Like(migrationLoan.fundsAsset()).approve(address(migrationLoan), fees);
        migrationLoan.returnFunds(fees);
        migrationLoan.closeLoan(0);

        vm.stopPrank();

        loans.pop();

        vm.prank(poolV1.poolDelegate());
        poolV1.claim(address(migrationLoan), address(debtLockerFactory));
    }

    function setGlobalsOfFactory(address factory, address globals) internal {
        IMapleProxyFactoryLike factory_ = IMapleProxyFactoryLike(factory);

        vm.prank(MapleGlobalsV2(factory_.mapleGlobals()).governor());
        factory_.setGlobals(globals);
    }

    function setV1ProtocolPause(bool paused) internal {
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(paused);
    }

    function requestUnstake(IStakeLockerLike stakeLocker, address poolDelegate) internal {
        vm.prank(poolDelegate);
        stakeLocker.intendToUnstake();
    }

    function returnLoansToDebtLocker(address transitionLoanManager_, IMapleLoanLike[] storage loans) internal {
        uint256 loansLength_ = loans.length;

        address[] memory debtLockerAddresses = new address[](loansLength_);
        address[] memory loans_              = new address[](loansLength_);

        for (uint256 i = 0; i < loansLength_; i++) {
            address loan_          = address(loans[i]);
            debtLockerAddresses[i] = loansOriginalLender[loan_];
            loans_[i]              = loan_;
        }

        // Give ownership of loans back to the debtLocker
        vm.prank(migrationMultisig);
        migrationHelper.rollback_takeOwnershipOfLoans(transitionLoanManager_, loans_);

        for (uint256 i = 0; i < loansLength_; i++) {
            assertEq(loans[i].lender(), debtLockerAddresses[i]);
        }
    }

    function transferPoolDelegate(IPoolManagerLike poolManager, address newDelegate_) internal {
        setPendingPoolDelegate(address(poolManager), newDelegate_);
        acceptPoolDelegate(address(poolManager));
    }

    function setLiquidityCap(IPoolLike poolV1, uint256 liquidityCap) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setLiquidityCap(liquidityCap);  // NOTE: Need to pass in old liquidity cap
        assertEq(poolV1.liquidityCap(), liquidityCap);
    }

    function snapshotPoolState(IPoolLike poolV1) internal {
        IERC20Like poolAsset = IERC20Like(poolV1.liquidityAsset());

        poolStateSnapshot[address(poolV1)] = PoolState({
            cash:         poolAsset.balanceOf(poolV1.liquidityLocker()),
            interestSum:  poolV1.interestSum(),
            liquidityCap: poolV1.liquidityCap(),
            poolLosses:   poolV1.poolLosses(),
            principalOut: poolV1.principalOut(),
            totalSupply:  poolV1.totalSupply()
        });
    }

    function storeOriginalLoanLender(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];
            loansOriginalLender[address(loan)] = loan.lender();
        }
    }

    function unstakeDelegateCover(IStakeLockerLike stakeLocker, address poolDelegate, uint256 delegateBalance_) internal {
        IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

        uint256 initialStakeLockerBPTBalance   = bpt.balanceOf(address(stakeLocker));
        uint256 initialPoolDelegateBPTBalance  = bpt.balanceOf(address(poolDelegate));
        uint256 losses                         = stakeLocker.recognizableLossesOf(poolDelegate);

        uint256 balance = stakeLocker.balanceOf(poolDelegate);

        vm.prank(poolDelegate);
        stakeLocker.unstake(balance);

        uint256 endStakeLockerBPTBalance  = bpt.balanceOf(address(stakeLocker));
        uint256 endPoolDelegateBPTBalance = bpt.balanceOf(address(poolDelegate));

        assertEq(delegateBalance_ - losses, endPoolDelegateBPTBalance - initialPoolDelegateBPTBalance);
        assertEq(delegateBalance_ - losses, initialStakeLockerBPTBalance - endStakeLockerBPTBalance);
        assertEq(stakeLocker.balanceOf(poolDelegate), 0);                                      // All the delegate stake was withdrawn

    }

    function upgradeDebtLockersToV400(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            vm.prank(debtLocker.poolDelegate());
            debtLocker.upgrade(400, abi.encode(migrationHelper));

            assertVersion(400, address(debtLocker));
        }
    }

    function upgradeDebtLockerToV400(IMapleLoanLike loan) internal {
        IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

        vm.prank(debtLocker.poolDelegate());
        debtLocker.upgrade(400, abi.encode(migrationHelper));

        assertVersion(400, address(debtLocker));
    }

    function upgradeLoanToV302(IMapleLoanLike loan) internal {
        vm.prank(globalAdmin);
        loan.upgrade(302, new bytes(0));

        assertVersion(302, address(loan));
    }

    function upgradeLoansToV301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            uint256 currentVersion = loanFactory.versionOf(loan.implementation());

            if (currentVersion == 301) continue;

            if (currentVersion == 200) {
                vm.prank(loan.borrower());
                loan.upgrade(300, new bytes(0));
            }

            vm.prank(loan.borrower());
            loan.upgrade(301, new bytes(0));

            assertVersion(301, address(loan));
        }
    }

    function upgradeLoansToV302(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            vm.prank(globalAdmin);
            loan.upgrade(302, new bytes(0));

            assertVersion(302, address(loan));
        }
    }

    function upgradeLoansToV400(IMapleLoanLike[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            vm.prank(globalAdmin);
            loan.upgrade(400, abi.encode(address(feeManager)));

            assertVersion(400, address(loan));
        }
    }

    function upgradeLoansToV401(IMapleLoanLike[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            vm.prank(securityAdminMultisig);
            loan.upgrade(401, "");

            assertVersion(401, address(loan));
        }
    }

    function withdrawCover(IStakeLockerLike stakeLocker, IMplRewardsLike rewards, address[] storage coverProviders) internal {
        IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

        // Due to the default on the Orthogonal Pool, some amount of dust will be left in the StakeLocker.
        uint256 acceptedDust = stakeLocker == orthogonalStakeLocker ? 0.003053321892584837e18 : 0;

        for (uint256 i = 0; i < coverProviders.length; i++) {
            // If User has allowance in the rewards contract, exit it.
            if (stakeLocker.custodyAllowance(coverProviders[i], address(rewards)) > 0) {
                vm.prank(coverProviders[i]);
                rewards.exit();
            }

            if (stakeLocker.balanceOf(coverProviders[i]) > 0) {
                vm.prank(coverProviders[i]);
                stakeLocker.intendToUnstake();

                // Perform the unstake
                uint256 initialStakeLockerBPTBalance = bpt.balanceOf(address(stakeLocker));
                uint256 initialProviderBPTBalance    = bpt.balanceOf(address(coverProviders[i]));

                // Due to losses on orthogonal pool, the last unstaker takes a slight loss
                if (coverProviders[i] == 0xF9107317B0fF77eD5b7ADea15e50514A3564002B) {
                    vm.prank(coverProviders[i]);
                    stakeLocker.unstake(6029602120323463);

                    assertEq(stakeLocker.balanceOf(coverProviders[i]), acceptedDust);
                    continue;
                } else {
                    uint256 balance = stakeLocker.balanceOf(coverProviders[i]);

                    vm.prank(coverProviders[i]);
                    stakeLocker.unstake(balance);
                }

                uint256 endStakeLockerBPTBalance = bpt.balanceOf(address(stakeLocker));
                uint256 endProviderBPTBalance    = bpt.balanceOf(address(coverProviders[i]));

                assertEq(endProviderBPTBalance - initialProviderBPTBalance, initialStakeLockerBPTBalance - endStakeLockerBPTBalance); // BPTs moved from stake locker to provider
                assertEq(stakeLocker.balanceOf(coverProviders[i]), 0);
            }
        }

        // Not 0 for orthogonal, but 0 for the other pools.
        assertEq(stakeLocker.totalSupply(),                   acceptedDust);
        assertWithinDiff(bpt.balanceOf(address(stakeLocker)), acceptedDust, 19); // This difference of 19 is what is makes the last provider not able to withdraw the entirety of his
    }

}




// ["0x1bF87903C1d46955BD12588a066431649aD9E3Df","0xdb6F1fddDA145cAb6287947668EbD937478c483d","0x5d89e99cc7449208F5e65De8c0d377D7c6994169"]
// ["0xd1Ed9aafC943c29070983b46aCfe066090073bF0","0x040C6201dc87c42aE4E39251d7b8F67Bc4A7E744","0x66442EFF1B4203C74Fe6abde0Bad5Bb564B2f6F9"]
