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
    address internal debtLockerV4Migrator;
    address internal debtLockerV4Implementation;
    address internal deactivationOracle;

    address internal mapleLoanV302Implementation;
    address internal mapleLoanV400Implementation;
    address internal mapleLoanV401Implementation;
    address internal mapleLoanV4Initializer;
    address internal mapleLoanV4Migrator;

    address internal liquidatorImplementation;
    address internal liquidatorInitializer;

    address internal loanManagerImplementation;
    address internal loanManagerInitializer;
    address internal transitionLoanManagerImplementation;

    address internal poolManagerImplementation;
    address internal poolManagerInitializer;

    address internal withdrawalManagerImplementation;
    address internal withdrawalManagerInitializer;

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
    /*** Forward Progression                                                                                                    ***/
    /******************************************************************************************************************************/

    // Entire Migration
    function performEntireMigration() internal {
        // Pre-Deployment Requirements
        setPoolAdminsToMigrationMultisig();  // LMP #1
        zeroInvestorFeeAndTreasuryFee();     // LMP #2
        payAndClaimAllUpcomingLoans();       // LMP #3
        upgradeAllLoansToV301();             // LMP #4

        deployProtocol();  // LMP #5

        tempGovernorAcceptsV2Governorship();                   // LMP #6
        migrationMultisigAcceptsMigrationAdministratorship();  // LMP #7
        storeCoverAmounts();                                   // TODO: where is the earliest this can/should go? Hardcode inline instead?
        setupExistingFactories();                              // LMP #8

        // Pre-Kickoff
        upgradeAllDebtLockersToV400();  // LMP #9
        claimAllLoans();                // LMP #10

        // Kickoff
        upgradeAllLoansToV302();    // LMP #11
        lockAllPoolV1Deposits();    // LMP #12
        createAllMigrationLoans();  // LMP #13

        // Migration Loan Funding
        // NOTE: Technically, each loan is funded and their DebtLockers are upgraded per pool before moving onto the next
        fundAllMigrationLoans();               // LMP #14
        upgradeAllMigrationLoanDebtLockers();  // LMP #15

        upgradeAllMigrationLoansToV302();  // LMP #16

        pauseV1Protocol();  // LMP #17

        deployAllPoolV2s();  // LMP #18

        addLoansToAllLoanManagers();  // LMP #19

        // Prepare for Airdrops
        activateAllPoolManagers();  // LMP #20
        openOrAllowOnAllPoolV2s();  // LMP #21

        airdropTokensForAllPools();  // LMP #22
        assertAllPoolAccounting();

        // Transfer Loans
        // TODO: Do we really need all these repetitive assertions? Especially that we have validation script now.
        setAllPendingLenders();         // LMP #23
        assertAllPoolAccounting();
        takeAllOwnershipsOfLoans();     // LMP #24
        assertAllPoolAccounting();
        upgradeAllLoanManagers();       // LMP #25
        assertAllPrincipalOuts();
        assertAllTotalSupplies();
        assertAllPoolAccounting();
        setAllCoverParameters();
        assertAllPoolAccounting();
        upgradeAllLoansToV400();        // LMP #26

        compareAllLpPositions();

        // Close Migration Loans
        setGlobalsOfLoanFactoryToV2();  // LMP #27
        closeAllMigrationLoans();       // LMP #28

        // Prepare PoolV1 Deactivation
        unlockV1Staking();    // LMP #29
        unpauseV1Protocol();  // LMP #30

        deactivateAndUnstakeAllPoolV1s();  // LMPs #31-#35

        enableFinalPoolDelegates();  // LMP #36

        transferAllPoolDelegates();  // LMPs #37-#38

        // Transfer Governorship of GlobalsV2
        tempGovernorTransfersV2Governorship();  // LMPs #39
        governorAcceptsV2Governorship();        // LMPs #40

        setLoanDefault400();  // LMPs #41

        finalizeProtocol();  // LMPs #42-#45

        // Dec 8
        handleCoverProviderEdgeCase();

        // Make cover providers withdraw
        withdrawAllCovers();

        // PoolV2 Lifecycle start
        depositAllCovers();
        increaseAllLiquidityCaps();
    }

    // Liquidity Migration Procedure #1
    function setPoolAdmin(IPoolLike poolV1, address poolAdmin) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setPoolAdmin(poolAdmin, true);
    }

    // Liquidity Migration Procedure #1
    function setPoolAdminsToMigrationMultisig() internal {
        setPoolAdmin(mavenPermissionedPoolV1, migrationMultisig);
        setPoolAdmin(mavenUsdcPoolV1,         migrationMultisig);
        setPoolAdmin(mavenWethPoolV1,         migrationMultisig);
        setPoolAdmin(orthogonalPoolV1,        migrationMultisig);
        setPoolAdmin(icebreakerPoolV1,        migrationMultisig);
    }

    // Liquidity Migration Procedure #2
    function zeroInvestorFeeAndTreasuryFee() internal {
        vm.startPrank(governor);
        mapleGlobalsV1.setInvestorFee(0);
        mapleGlobalsV1.setTreasuryFee(0);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #3
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

    // Liquidity Migration Procedure #3
    function payAndClaimAllUpcomingLoans() internal {
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);
    }

    // Liquidity Migration Procedure #4
    function upgradeLoansToV301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
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

    // Liquidity Migration Procedure #4
    function upgradeAllLoansToV301() internal {
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);
    }

    // Liquidity Migration Procedure #5
    function _deployProtocol() internal {
        // Deploy Globals (Set Governor to deployer)
        address mapleGlobalsV2Implementation = address(new MapleGlobalsV2());

        mapleGlobalsV2 = MapleGlobalsV2(address(new MapleGlobalsNTP(deployer, mapleGlobalsV2Implementation)));

        // Deploy FeeManager
        feeManager = new MapleLoanFeeManager(address(mapleGlobalsV2));

        // Deploy PoolDeployer
        poolDeployer = new PoolDeployer(address(mapleGlobalsV2));

        // Liquidator Factory Deployments and Configuration
        liquidatorFactory        = new LiquidatorFactory(address(mapleGlobalsV2));
        liquidatorImplementation = address(new Liquidator());
        liquidatorInitializer    = address(new LiquidatorInitializer());

        liquidatorFactory.registerImplementation(200, liquidatorImplementation, liquidatorInitializer);
        liquidatorFactory.setDefaultVersion(200);

        // Loan Manager Factory Deployments and Configuration
        loanManagerFactory                  = new LoanManagerFactory(address(mapleGlobalsV2));
        loanManagerImplementation           = address(new LoanManager());
        loanManagerInitializer              = address(new LoanManagerInitializer());
        transitionLoanManagerImplementation = address(new TransitionLoanManager());

        loanManagerFactory.registerImplementation(100, transitionLoanManagerImplementation, loanManagerInitializer);
        loanManagerFactory.registerImplementation(200, loanManagerImplementation,           loanManagerInitializer);
        loanManagerFactory.enableUpgradePath(100, 200, address(0));
        loanManagerFactory.setDefaultVersion(100);

        // Pool Manager Factory Deployments and Configuration
        poolManagerFactory        = new PoolManagerFactory(address(mapleGlobalsV2));
        poolManagerImplementation = address(new PoolManager());
        poolManagerInitializer    = address(new PoolManagerInitializer());

        poolManagerFactory.registerImplementation(100, poolManagerImplementation, poolManagerInitializer);
        poolManagerFactory.setDefaultVersion(100);

        // Withdrawal Manager Factory Deployments and Configuration
        withdrawalManagerFactory        = new WithdrawalManagerFactory(address(mapleGlobalsV2));
        withdrawalManagerImplementation = address(new WithdrawalManager());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        withdrawalManagerFactory.registerImplementation(100, withdrawalManagerImplementation, withdrawalManagerInitializer);
        withdrawalManagerFactory.setDefaultVersion(100);

        // Loan Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        mapleLoanV302Implementation = address(new MapleLoanV302());
        mapleLoanV4Initializer      = address(new MapleLoanV4Initializer());
        mapleLoanV400Implementation = address(new MapleLoanV400());
        mapleLoanV4Migrator         = address(new MapleLoanV4Migrator());

        // DebtLocker Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        debtLockerV4Migrator       = address(new DebtLockerV4Migrator());
        debtLockerV4Implementation = address(new DebtLockerV4());

        // Deploy MigrationHelper, AccountingChecker, and DeactivationOracle
        accountingChecker  = new AccountingChecker(address(mapleGlobalsV2));
        deactivationOracle = address(new DeactivationOracle());

        address migrationHelperImplementation = address(new MigrationHelper());

        migrationHelper = MigrationHelper(address(new MigrationHelperNTP(deployer, migrationHelperImplementation)));

        refinancer = new Refinancer();

        // Configure MigrationHelper
        migrationHelper.setPendingAdmin(migrationMultisig);
        migrationHelper.setGlobals(address(mapleGlobalsV2));

        // Configure Globals Addresses
        mapleGlobalsV2.setMapleTreasury(mapleTreasury);
        mapleGlobalsV2.setSecurityAdmin(securityAdminMultisig);
        mapleGlobalsV2.setMigrationAdmin(address(migrationHelper));

        // Set Globals Valid Addresses
        mapleGlobalsV2.setValidPoolDeployer(address(poolDeployer), true);

        for (uint256 i; i < mavenPermissionedLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(mavenPermissionedLoans[i].borrower(), true);
        }

        for (uint256 i; i < mavenUsdcLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(mavenUsdcLoans[i].borrower(), true);
        }

        for (uint256 i; i < mavenWethLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(mavenWethLoans[i].borrower(), true);
        }

        for (uint256 i; i < orthogonalLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(orthogonalLoans[i].borrower(), true);
        }

        for (uint256 i; i < icebreakerLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(icebreakerLoans[i].borrower(), true);
        }

        mapleGlobalsV2.setValidPoolDelegate(tempMavenPermissionedPD, true);
        mapleGlobalsV2.setValidPoolDelegate(tempMavenUsdcPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(tempMavenWethPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(tempOrthogonalPD,        true);
        mapleGlobalsV2.setValidPoolDelegate(tempIcebreakerPD,        true);

        // NOTE: Not setting wbtc as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidPoolAsset(address(usdc), true);
        mapleGlobalsV2.setValidPoolAsset(address(weth), true);

        // NOTE: Not setting usdc and weth as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidCollateralAsset(address(weth), true);
        mapleGlobalsV2.setValidCollateralAsset(address(wbtc), true);

        mapleGlobalsV2.setValidFactory("LIQUIDATOR",         address(liquidatorFactory),        true);
        mapleGlobalsV2.setValidFactory("LOAN",               address(loanFactory),              true);
        mapleGlobalsV2.setValidFactory("LOAN_MANAGER",       address(loanManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("POOL_MANAGER",       address(poolManagerFactory),       true);
        mapleGlobalsV2.setValidFactory("WITHDRAWAL_MANAGER", address(withdrawalManagerFactory), true);

        // Configure Globals Values
        mapleGlobalsV2.setBootstrapMint(address(usdc), 0.100000e6);
        mapleGlobalsV2.setBootstrapMint(address(weth), 0.0001e18);

        mapleGlobalsV2.setDefaultTimelockParameters(1 weeks, 2 days);

        mapleGlobalsV2.setPriceOracle(address(usdc), address(usdUsdOracle));
        mapleGlobalsV2.setPriceOracle(address(wbtc), address(btcUsdOracle));
        mapleGlobalsV2.setPriceOracle(address(weth), address(ethUsdOracle));

        // Transfer governor
        mapleGlobalsV2.setPendingGovernor(tempGovernor);
    }

    // Liquidity Migration Procedure #5
    function deployProtocol() internal {
        vm.startPrank(deployer);
        _deployProtocol();
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #6
    function tempGovernorAcceptsV2Governorship() internal {
        vm.prank(tempGovernor);
        mapleGlobalsV2.acceptGovernor();
    }

    // Liquidity Migration Procedure #7
    function migrationMultisigAcceptsMigrationAdministratorship() internal {
        vm.prank(migrationMultisig);
        migrationHelper.acceptOwner();
    }

    // Liquidity Migration Procedure #8
    function setupExistingFactories() internal {
        vm.startPrank(governor);

        debtLockerFactory.registerImplementation(400, address(new DebtLockerV4()), debtLockerV3Initializer);
        debtLockerFactory.enableUpgradePath(300, 400, debtLockerV4Migrator);

        loanFactory.registerImplementation(302, address(new MapleLoanV302()), loanV3Initializer);
        loanFactory.registerImplementation(400, address(new MapleLoanV400()), mapleLoanV4Initializer);
        loanFactory.enableUpgradePath(301, 302, address(0));
        loanFactory.enableUpgradePath(302, 400, address(new MapleLoanV4Migrator()));
        loanFactory.setDefaultVersion(301);

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #9
    function upgradeDebtLockersToV400(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            vm.prank(debtLocker.poolDelegate());
            debtLocker.upgrade(400, abi.encode(migrationHelper));

            assertVersion(400, address(debtLocker));
        }
    }

    // Liquidity Migration Procedure #9
    function upgradeAllDebtLockersToV400() internal {
        upgradeDebtLockersToV400(mavenPermissionedLoans);
        upgradeDebtLockersToV400(mavenUsdcLoans);
        upgradeDebtLockersToV400(mavenWethLoans);
        upgradeDebtLockersToV400(orthogonalLoans);
        upgradeDebtLockersToV400(icebreakerLoans);
    }

    // Liquidity Migration Procedure #10
    function claimLoans(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        address poolDelegate = poolV1.poolDelegate();

        vm.startPrank(poolDelegate);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            if (loan.claimableFunds() == 0) continue;

            address debtLockerFactory = IMapleProxiedLike(loan.lender()).factory();

            poolV1.claim(address(loan), debtLockerFactory);
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #10
    function claimAllLoans() internal {
        claimLoans(mavenPermissionedPoolV1, mavenPermissionedLoans);
        claimLoans(mavenUsdcPoolV1,         mavenUsdcLoans);
        claimLoans(mavenWethPoolV1,         mavenWethLoans);
        claimLoans(orthogonalPoolV1,        orthogonalLoans);
        claimLoans(icebreakerPoolV1,        icebreakerLoans);
    }

    // Liquidity Migration Procedure #11
    function upgradeLoansToV302(IMapleLoanLike[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = loans[i];

            loan.upgrade(302, new bytes(0));

            assertVersion(302, address(loan));
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #11
    function upgradeAllLoansToV302() internal {
        upgradeLoansToV302(mavenPermissionedLoans);
        upgradeLoansToV302(mavenUsdcLoans);
        upgradeLoansToV302(mavenWethLoans);
        upgradeLoansToV302(orthogonalLoans);
        upgradeLoansToV302(icebreakerLoans);
    }

    // Liquidity Migration Procedure #12
    function lockPoolV1Deposits(IPoolLike poolV1) internal {
        setLiquidityCap(address(poolV1), 0);
    }

    // Liquidity Migration Procedure #12
    function lockAllPoolV1Deposits() internal {
        lockPoolV1Deposits(mavenPermissionedPoolV1);
        lockPoolV1Deposits(mavenUsdcPoolV1);
        lockPoolV1Deposits(mavenWethPoolV1);
        lockPoolV1Deposits(orthogonalPoolV1);
        lockPoolV1Deposits(icebreakerPoolV1);
    }

    // Liquidity Migration Procedure #13
    function createMigrationLoan(address borrower, IPoolLike poolV1, IMapleLoanLike[] storage loans, uint256 liquidity) internal returns (IMapleLoanLike migrationLoan) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        address[2] memory assets      = [address(asset), address(asset)];
        uint256[3] memory termDetails = [uint256(0), uint256(30 days), uint256(1)];
        uint256[3] memory requests    = [uint256(0), liquidity, liquidity];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory args = abi.encode(borrower, assets, termDetails, requests, rates);
        bytes32 salt      = keccak256(abi.encode(address(poolV1)));
        migrationLoan     = IMapleLoanLike(loanFactory.createInstance(args, salt));

        loans.push(migrationLoan);
        migrationLoans[address(poolV1)] = migrationLoan;
    }

    // Liquidity Migration Procedure #13
    function createMigrationLoanIfRequired(address borrower, IPoolLike poolV1, IMapleLoanLike[] storage loans) internal returns (IMapleLoanLike migrationLoan) {
        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);

        if (availableLiquidity > 0) {
            migrationLoan = createMigrationLoan(migrationMultisig, poolV1, loans, availableLiquidity);
        }
    }

    // Liquidity Migration Procedure #13
    function createAllMigrationLoans() internal {
        createMigrationLoanIfRequired(migrationMultisig, mavenPermissionedPoolV1, mavenPermissionedLoans);
        createMigrationLoanIfRequired(migrationMultisig, mavenUsdcPoolV1,         mavenUsdcLoans);
        createMigrationLoanIfRequired(migrationMultisig, mavenWethPoolV1,         mavenWethLoans);
        createMigrationLoanIfRequired(migrationMultisig, orthogonalPoolV1,        orthogonalLoans);
        createMigrationLoanIfRequired(migrationMultisig, icebreakerPoolV1,        icebreakerLoans);
    }

    // Liquidity Migration Procedures #11-#13
    function kickoffOnPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal returns (IMapleLoanLike migrationLoan) {
        upgradeLoansToV302(loans);  // Liquidity Migration Procedure #11

        lockPoolV1Deposits(poolV1);  // Liquidity Migration Procedure #12

        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);

        if (availableLiquidity > 0) {
            migrationLoan = createMigrationLoan(migrationMultisig, poolV1, loans, availableLiquidity);  // Liquidity Migration Procedure #13
        }
    }

    // Liquidity Migration Procedures #11-#13
    function kickoffAll() internal {
        upgradeAllLoansToV302();    // Liquidity Migration Procedure #11
        lockAllPoolV1Deposits();    // Liquidity Migration Procedure #12
        createAllMigrationLoans();  // Liquidity Migration Procedure #13
    }

    // Liquidity Migration Procedure #14
    function fundMigrationLoan(IPoolLike poolV1, IMapleLoanLike migrationLoan) internal {
        uint256 principalRequested = migrationLoan.principalRequested();

        vm.prank(poolV1.poolDelegate());
        poolV1.fundLoan(address(migrationLoan), address(debtLockerFactory), principalRequested);

        assertEq(IERC20Like(poolV1.liquidityAsset()).balanceOf(poolV1.liquidityLocker()), 0);
    }

    // Liquidity Migration Procedure #14
    function fundMigrationLoanIfNeeded(IPoolLike poolV1, IMapleLoanLike migrationLoan) internal {
        if (address(migrationLoan) == address(0)) return;

        fundMigrationLoan(poolV1, migrationLoan);
    }

    // Liquidity Migration Procedure #14
    function fundAllMigrationLoans() internal {
        fundMigrationLoanIfNeeded(mavenPermissionedPoolV1, migrationLoans[address(mavenPermissionedPoolV1)]);
        fundMigrationLoanIfNeeded(mavenUsdcPoolV1,         migrationLoans[address(mavenUsdcPoolV1)]);
        fundMigrationLoanIfNeeded(mavenWethPoolV1,         migrationLoans[address(mavenWethPoolV1)]);
        fundMigrationLoanIfNeeded(orthogonalPoolV1,        migrationLoans[address(orthogonalPoolV1)]);
        fundMigrationLoanIfNeeded(icebreakerPoolV1,        migrationLoans[address(icebreakerPoolV1)]);
    }

    // Liquidity Migration Procedure #15
    function upgradeDebtLockerToV400(IMapleLoanLike loan) internal {
        IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

        vm.prank(debtLocker.poolDelegate());
        debtLocker.upgrade(400, abi.encode(migrationHelper));

        assertVersion(400, address(debtLocker));
    }

    // Liquidity Migration Procedure #15
    function upgradeDebtLockerToV400IfNeeded(IMapleLoanLike loan) internal {
        if (address(loan) == address(0)) return;

        upgradeDebtLockerToV400(loan);
    }

    // Liquidity Migration Procedure #15
    function upgradeAllMigrationLoanDebtLockers() internal {
        upgradeDebtLockerToV400IfNeeded(migrationLoans[address(mavenPermissionedPoolV1)]);
        upgradeDebtLockerToV400IfNeeded(migrationLoans[address(mavenUsdcPoolV1)]);
        upgradeDebtLockerToV400IfNeeded(migrationLoans[address(mavenWethPoolV1)]);
        upgradeDebtLockerToV400IfNeeded(migrationLoans[address(orthogonalPoolV1)]);
        upgradeDebtLockerToV400IfNeeded(migrationLoans[address(icebreakerPoolV1)]);
    }

    // Liquidity Migration Procedure #16
    function upgradeLoanToV302(IMapleLoanLike loan) internal {
        vm.prank(globalAdmin);
        loan.upgrade(302, new bytes(0));

        assertVersion(302, address(loan));
    }

    // Liquidity Migration Procedure #16
    function upgradeLoanToV302IfNeeded(IMapleLoanLike loan) internal {
        if (address(loan) == address(0)) return;

        upgradeLoanToV302(loan);
    }

    // Liquidity Migration Procedure #16
    function upgradeAllMigrationLoansToV302() internal {
        upgradeLoanToV302IfNeeded(migrationLoans[address(mavenPermissionedPoolV1)]);
        upgradeLoanToV302IfNeeded(migrationLoans[address(mavenUsdcPoolV1)]);
        upgradeLoanToV302IfNeeded(migrationLoans[address(mavenWethPoolV1)]);
        upgradeLoanToV302IfNeeded(migrationLoans[address(orthogonalPoolV1)]);
        upgradeLoanToV302IfNeeded(migrationLoans[address(icebreakerPoolV1)]);
    }

    // Liquidity Migration Procedure #17
    function pauseV1Protocol() internal {
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);
    }

    // Liquidity Migration Procedure #18
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

    // Liquidity Migration Procedure #18
    function deployAllPoolV2s() internal {
        mavenPermissionedPoolManager = deployPoolV2(tempMavenPermissionedPD, mavenPermissionedPoolV1);
        mavenUsdcPoolManager         = deployPoolV2(tempMavenUsdcPD,         mavenUsdcPoolV1);
        mavenWethPoolManager         = deployPoolV2(tempMavenWethPD,         mavenWethPoolV1);
        orthogonalPoolManager        = deployPoolV2(tempOrthogonalPD,        orthogonalPoolV1);
        icebreakerPoolManager        = deployPoolV2(tempIcebreakerPD,        icebreakerPoolV1);
    }

    // Liquidity Migration Procedure #19
    function addLoansToLoanManager(IPoolManagerLike poolManager, address poolV1, IMapleLoanLike[] storage loans) internal {
        ITransitionLoanManagerLike transitionLoanManager = ITransitionLoanManagerLike(poolManager.loanManagerList(0));

        vm.prank(migrationMultisig);
        migrationHelper.addLoansToLoanManager(poolV1, address(transitionLoanManager), convertToAddresses(loans), 2);

        loansAddedTimestamps[address(poolManager)] = lastUpdatedTimestamps[address(poolManager)] = block.timestamp;
    }

    // Liquidity Migration Procedure #19
    function addLoansToAllLoanManagers() internal {
        addLoansToLoanManager(mavenPermissionedPoolManager, address(mavenPermissionedPoolV1), mavenPermissionedLoans);
        addLoansToLoanManager(mavenUsdcPoolManager,         address(mavenUsdcPoolV1),         mavenUsdcLoans);
        addLoansToLoanManager(mavenWethPoolManager,         address(mavenWethPoolV1),         mavenWethLoans);
        addLoansToLoanManager(orthogonalPoolManager,        address(orthogonalPoolV1),        orthogonalLoans);
        addLoansToLoanManager(icebreakerPoolManager,        address(icebreakerPoolV1),        icebreakerLoans);
    }

    // Liquidity Migration Procedure #20
    function activatePoolManager(address poolManager) internal {
        vm.prank(tempGovernor);
        mapleGlobalsV2.activatePoolManager(poolManager);
    }

    // Liquidity Migration Procedure #20
    function activateAllPoolManagers() internal {
        activatePoolManager(address(mavenPermissionedPoolManager));
        activatePoolManager(address(mavenUsdcPoolManager));
        activatePoolManager(address(mavenWethPoolManager));
        activatePoolManager(address(orthogonalPoolManager));
        activatePoolManager(address(icebreakerPoolManager));
    }

    // Liquidity Migration Procedure #21
    function allowLendersAndWithdrawalManager(IPoolManagerLike poolManager, address[] storage lenders) internal {
        for (uint256 i; i < lenders.length; ++i) {
            allowLender(address(poolManager), lenders[i]);
        }

        allowLender(address(poolManager), poolManager.withdrawalManager());
    }

    // Liquidity Migration Procedure #21
    function openOrAllowOnAllPoolV2s() internal {
        allowLendersAndWithdrawalManager(mavenPermissionedPoolManager, mavenPermissionedLps);
        openPool(address(mavenUsdcPoolManager));
        openPool(address(mavenWethPoolManager));
        openPool(address(orthogonalPoolManager));
        allowLendersAndWithdrawalManager(icebreakerPoolManager, icebreakerLps);
    }

    // Liquidity Migration Procedure #22
    function airdropTokens(address poolV1, address poolManager, address[] storage lps) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.airdropTokens(poolV1, poolManager, lps, lps, lps.length * 2);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #22
    function airdropTokensForAllPools() internal {
        airdropTokens(address(mavenPermissionedPoolV1), address(mavenPermissionedPoolManager), mavenPermissionedLps);
        airdropTokens(address(mavenUsdcPoolV1),         address(mavenUsdcPoolManager),         mavenUsdcLps);
        airdropTokens(address(mavenWethPoolV1),         address(mavenWethPoolManager),         mavenWethLps);
        airdropTokens(address(orthogonalPoolV1),        address(orthogonalPoolManager),        orthogonalLps);
        airdropTokens(address(icebreakerPoolV1),        address(icebreakerPoolManager),        icebreakerLps);
    }

    // Liquidity Migration Procedure #23
    function setPendingLenders(address poolV1, address poolManager, IMapleLoanLike[] storage loans) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.setPendingLenders(address(poolV1), address(poolManager), address(loanFactory), convertToAddresses(loans), 2);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #23
    function setAllPendingLenders() internal {
        setPendingLenders(address(mavenPermissionedPoolV1), address(mavenPermissionedPoolManager), mavenPermissionedLoans);
        setPendingLenders(address(mavenUsdcPoolV1),         address(mavenUsdcPoolManager),         mavenUsdcLoans);
        setPendingLenders(address(mavenWethPoolV1),         address(mavenWethPoolManager),         mavenWethLoans);
        setPendingLenders(address(orthogonalPoolV1),        address(orthogonalPoolManager),        orthogonalLoans);
        setPendingLenders(address(icebreakerPoolV1),        address(icebreakerPoolManager),        icebreakerLoans);
    }

    // Liquidity Migration Procedure #24
    function takeOwnershipOfLoans(address poolV1, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.takeOwnershipOfLoans(poolV1, poolManager.loanManagerList(0), convertToAddresses(loans), 2);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #24
    function takeAllOwnershipsOfLoans() internal {
        takeOwnershipOfLoans(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        takeOwnershipOfLoans(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        takeOwnershipOfLoans(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        takeOwnershipOfLoans(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        takeOwnershipOfLoans(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);
    }

    // Liquidity Migration Procedure #25
    function upgradeLoanManager(address transitionLoanManager) internal {
        vm.startPrank(migrationMultisig);
        migrationHelper.upgradeLoanManager(transitionLoanManager, 200);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #25
    function upgradeAllLoanManagers() internal {
        upgradeLoanManager(mavenPermissionedPoolManager.loanManagerList(0));
        upgradeLoanManager(mavenUsdcPoolManager.loanManagerList(0));
        upgradeLoanManager(mavenWethPoolManager.loanManagerList(0));
        upgradeLoanManager(orthogonalPoolManager.loanManagerList(0));
        upgradeLoanManager(icebreakerPoolManager.loanManagerList(0));
    }

    // Liquidity Migration Procedure #26
    function upgradeLoansToV400(IMapleLoanLike[] memory loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];
            loan.upgrade(400, abi.encode(address(feeManager)));
            assertVersion(400, address(loan));
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #26
    function upgradeAllLoansToV400() internal {
        upgradeLoansToV400(mavenPermissionedLoans);
        upgradeLoansToV400(mavenUsdcLoans);
        upgradeLoansToV400(mavenWethLoans);
        upgradeLoansToV400(orthogonalLoans);
        upgradeLoansToV400(icebreakerLoans);
    }

    // Liquidity Migration Procedure #27
    function setGlobalsOfLoanFactoryToV2() internal {
        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV2));
    }

    // Liquidity Migration Procedure #28 [TODO: Maybe use generic action]
    function closeMigrationLoan(IMapleLoanLike migrationLoan, IMapleLoanLike[] storage loans) internal {
        vm.prank(migrationMultisig);
        migrationLoan.closeLoan(0);

        uint256 i;
        while (loans[i] != migrationLoan) i++;

        // Move last element to index of removed loan manager and pop last element.
        loans[i] = loans[loans.length - 1];
        loans.pop();
    }

    // Liquidity Migration Procedure #28
    function closeMigrationLoanIfNeeded(address poolV1, IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        IMapleLoanLike migrationLoan = migrationLoans[poolV1];

        assertPoolAccounting(poolManager, loans);

        if (address(migrationLoan) == address(0)) return;

        closeMigrationLoan(migrationLoan, loans);
        lastUpdatedTimestamps[address(poolManager)] = block.timestamp;

        assertPoolAccounting(poolManager, loans);
    }

    // Liquidity Migration Procedure #28
    function closeAllMigrationLoans() internal {
        closeMigrationLoanIfNeeded(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        closeMigrationLoanIfNeeded(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        closeMigrationLoanIfNeeded(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        closeMigrationLoanIfNeeded(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        closeMigrationLoanIfNeeded(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);
    }

    // Liquidity Migration Procedure #29
    function unlockV1Staking() internal {
        DeactivationOracle oracle = new DeactivationOracle();

        vm.startPrank(governor);
        mapleGlobalsV1.setPriceOracle(address(usdc), address(oracle));
        mapleGlobalsV1.setPriceOracle(address(weth), address(oracle));
        mapleGlobalsV1.setStakerCooldownPeriod(0);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #30
    function unpauseV1Protocol() internal {
        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(false);
    }

    // Liquidity Migration Procedure #31
    function deactivatePoolV1(IPoolLike poolV1) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.deactivate();
    }

    // Liquidity Migration Procedure #32
    function zeroLockupPeriod(IPoolLike poolV1) internal {
        IStakeLockerLike stakeLocker = IStakeLockerLike(poolV1.stakeLocker());

        vm.prank(poolV1.poolDelegate());
        stakeLocker.setLockupPeriod(0);
    }

    // Liquidity Migration Procedure #33
    function requestUnstake(IPoolLike poolV1) internal {
        IStakeLockerLike stakeLocker = IStakeLockerLike(poolV1.stakeLocker());

        vm.prank(poolV1.poolDelegate());
        stakeLocker.intendToUnstake();
    }

    // Liquidity Migration Procedure #34
    function exitRewards(IPoolLike poolV1, address rewards) internal {
        address poolDelegate = poolV1.poolDelegate();

        if (IStakeLockerLike(poolV1.stakeLocker()).custodyAllowance(poolDelegate, rewards) == 0) return;

        vm.prank(poolDelegate);
        IMplRewardsLike(rewards).exit();
    }

    // Liquidity Migration Procedure #35
    function unstakeDelegateCover(IPoolLike poolV1, uint256 delegateBalance) internal {
        address          poolDelegate = poolV1.poolDelegate();
        IStakeLockerLike stakeLocker  = IStakeLockerLike(poolV1.stakeLocker());

        IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

        uint256 initialStakeLockerBPTBalance   = bpt.balanceOf(address(stakeLocker));
        uint256 initialPoolDelegateBPTBalance  = bpt.balanceOf(address(poolDelegate));
        uint256 losses                         = stakeLocker.recognizableLossesOf(poolDelegate);
        uint256 balance                        = stakeLocker.balanceOf(poolDelegate);

        vm.prank(poolDelegate);
        stakeLocker.unstake(balance);

        uint256 endStakeLockerBPTBalance  = bpt.balanceOf(address(stakeLocker));
        uint256 endPoolDelegateBPTBalance = bpt.balanceOf(address(poolDelegate));

        assertEq(delegateBalance - losses, endPoolDelegateBPTBalance - initialPoolDelegateBPTBalance);
        assertEq(delegateBalance - losses, initialStakeLockerBPTBalance - endStakeLockerBPTBalance);
        assertEq(stakeLocker.balanceOf(poolDelegate), 0);  // All the delegate stake was withdrawn
    }

    // Liquidity Migration Procedures #31-#35
    function deactivateAndUnstake(IPoolLike poolV1, address rewards, uint256 delegateBalance) internal {
        deactivatePoolV1(poolV1);  // Liquidity Migration Procedure #31
        zeroLockupPeriod(poolV1);  // Liquidity Migration Procedure #32

        // Assert that the provided balance matches the stake locker balance.
        assertEq(IStakeLockerLike(poolV1.stakeLocker()).balanceOf(poolV1.poolDelegate()), delegateBalance);

        if (delegateBalance == 0) return;

        requestUnstake(poolV1);  // Liquidity Migration Procedure #33

        if (address(rewards) != address(0)) {
            exitRewards(poolV1, rewards);  // Liquidity Migration Procedure #34
        }

        unstakeDelegateCover(poolV1, delegateBalance);  // Liquidity Migration Procedure #35
    }

    // Liquidity Migration Procedures #31-#35
    function deactivateAndUnstakeAllPoolV1s() internal {
        deactivateAndUnstake(mavenWethPoolV1,         address(mavenWethRewards),         125_049.87499e18);
        deactivateAndUnstake(mavenUsdcPoolV1,         address(mavenUsdcRewards),         153.022e18);
        deactivateAndUnstake(mavenPermissionedPoolV1, address(mavenPermissionedRewards), 16.319926286804447168e18);
        deactivateAndUnstake(orthogonalPoolV1,        address(orthogonalRewards),        175.122243323160822654e18);
        deactivateAndUnstake(icebreakerPoolV1,        address(icebreakerRewards),        104.254119288711119987e18);
    }

    // Liquidity Migration Procedures #36
    function enableFinalPoolDelegates() internal {
        vm.startPrank(tempGovernor);

        mapleGlobalsV2.setValidPoolDelegate(finalMavenPermissionedPD, true);
        mapleGlobalsV2.setValidPoolDelegate(finalMavenUsdcPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(finalMavenWethPD,         true);
        mapleGlobalsV2.setValidPoolDelegate(finalOrthogonalPD,        true);
        mapleGlobalsV2.setValidPoolDelegate(finalIcebreakerPD,        true);

        vm.stopPrank();
    }

    // Liquidity Migration Procedures #37-#38
    function transferPoolDelegate(IPoolManagerLike poolManager, address newDelegate_) internal {
        setPendingPoolDelegate(address(poolManager), newDelegate_);  // Liquidity Migration Procedure #37
        acceptPoolDelegate(address(poolManager));                    // Liquidity Migration Procedure #38
    }

    // Liquidity Migration Procedures #37-#38
    function transferAllPoolDelegates() internal {
        transferPoolDelegate(mavenWethPoolManager,         finalMavenWethPD);
        transferPoolDelegate(mavenUsdcPoolManager,         finalMavenUsdcPD);
        transferPoolDelegate(mavenPermissionedPoolManager, finalMavenPermissionedPD);
        transferPoolDelegate(orthogonalPoolManager,        finalOrthogonalPD);
        transferPoolDelegate(icebreakerPoolManager,        finalIcebreakerPD);
    }

    // Liquidity Migration Procedures #39
    function tempGovernorTransfersV2Governorship() internal {
        vm.prank(tempGovernor);
        mapleGlobalsV2.setPendingGovernor(governor);
    }

    // Liquidity Migration Procedures #40
    function governorAcceptsV2Governorship() internal {
        vm.prank(governor);
        mapleGlobalsV2.acceptGovernor();
    }

    // Liquidity Migration Procedure #41
    function setLoanDefault400() internal {
        vm.prank(governor);
        loanFactory.setDefaultVersion(400);
    }

    // Liquidity Migration Procedure #42
    function deployLoan401() internal {
        vm.prank(deployer);
        mapleLoanV401Implementation = address(new MapleLoanV401());
    }

    // Liquidity Migration Procedure #43
    function setupLoanFactoryFor401() internal {
        vm.startPrank(governor);
        loanFactory.registerImplementation(401, address(mapleLoanV401Implementation), mapleLoanV4Initializer);
        loanFactory.enableUpgradePath(400, 401, address(0));
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #44
    function upgradeLoansToV401(IMapleLoanLike[] memory loans) internal {
        vm.startPrank(securityAdminMultisig);

        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];
            loan.upgrade(401, "");
            assertVersion(401, address(loan));
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #44
    function upgradeAllLoansToV401() internal {
        upgradeLoansToV401(mavenPermissionedLoans);
        upgradeLoansToV401(mavenUsdcLoans);
        upgradeLoansToV401(mavenWethLoans);
        upgradeLoansToV401(orthogonalLoans);
        upgradeLoansToV401(icebreakerLoans);
    }

    // Liquidity Migration Procedure #45
    function finalizeFactories() internal {
        vm.startPrank(governor);

        loanFactory.setDefaultVersion(401);
        loanManagerFactory.setDefaultVersion(200);

        vm.stopPrank();
    }

    // Liquidity Migration Procedures #42-#45
    function finalizeProtocol() internal {
        deployLoan401();           // Liquidity Migration Procedure #42
        setupLoanFactoryFor401();  // Liquidity Migration Procedure #43
        upgradeAllLoansToV401();   // Liquidity Migration Procedure #44
        finalizeFactories();       // Liquidity Migration Procedure #45
    }

    // TODO: remove temporary PDs via setValidPoolDelegate on globalsV2


    /******************************************************************************************************************************/
    /*** Unsorted Forward Progression                                                                                           ***/
    /******************************************************************************************************************************/

    function increaseAllLiquidityCaps() internal {
        setLiquidityCap(address(mavenPermissionedPoolManager), 100_000_000e6);
        setLiquidityCap(address(mavenUsdcPoolManager),         100_000_000e6);
        setLiquidityCap(address(mavenWethPoolManager),         100_000e18);
        setLiquidityCap(address(orthogonalPoolManager),        100_000_000e6);
        setLiquidityCap(address(icebreakerPoolManager),        100_000_000e6);
    }

    function performAdditionalGlobalsSettings() internal {
        vm.startPrank(governor);

        mapleGlobalsV2.setValidPoolAsset(address(wbtc), true);

        mapleGlobalsV2.setValidCollateralAsset(address(usdc), true);

        vm.stopPrank();
    }

    function setCoverParameters(address poolManager, address poolV1) internal {
        // Configure the min cover amount in globals
        vm.startPrank(tempGovernor);
        mapleGlobalsV2.setMinCoverAmount(poolManager, coverAmounts[poolV1]);
        mapleGlobalsV2.setMaxCoverLiquidationPercent(poolManager, 0.5e6);
        vm.stopPrank();
    }

    function setAllCoverParameters() internal {
        setCoverParameters(address(mavenPermissionedPoolManager), address(mavenPermissionedPoolV1));
        setCoverParameters(address(mavenUsdcPoolManager),         address(mavenUsdcPoolV1));
        setCoverParameters(address(mavenWethPoolManager),         address(mavenWethPoolV1));
        setCoverParameters(address(orthogonalPoolManager),        address(orthogonalPoolV1));
        setCoverParameters(address(icebreakerPoolManager),        address(icebreakerPoolV1));
    }


    /******************************************************************************************************************************/
    /*** V1 Helpers                                                                                                             ***/
    /******************************************************************************************************************************/

    function setLiquidityCap(IPoolLike poolV1, uint256 liquidityCap) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setLiquidityCap(liquidityCap);  // NOTE: Need to pass in old liquidity cap
        assertEq(poolV1.liquidityCap(), liquidityCap);
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

    function withdrawAllCovers() internal {
        withdrawCover(mavenWethStakeLocker,         mavenWethRewards,         mavenWethCoverProviders);
        withdrawCover(mavenPermissionedStakeLocker, mavenPermissionedRewards, mavenPermissionedCoverProviders);
        withdrawCover(icebreakerStakeLocker,        icebreakerRewards,        icebreakerCoverProviders);
        withdrawCover(mavenUsdcStakeLocker,         mavenUsdcRewards,         mavenUsdcCoverProviders);
        withdrawCover(orthogonalStakeLocker,        orthogonalRewards,        orthogonalCoverProviders);
    }


    /******************************************************************************************************************************/
    /*** V2 Helpers                                                                                                             ***/
    /******************************************************************************************************************************/

    function depositAllCovers() internal {
        depositCover(address(mavenWethPoolManager),         750e18);
        depositCover(address(mavenUsdcPoolManager),         1_000_000e6);
        depositCover(address(mavenPermissionedPoolManager), 1_750_000e6);
        depositCover(address(orthogonalPoolManager),        2_500_000e6);
        depositCover(address(icebreakerPoolManager),        500_000e6);
    }


    /******************************************************************************************************************************/
    /*** Utility Functions                                                                                                      ***/
    /******************************************************************************************************************************/

    function assertLoansBelongToPool(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IDebtLockerLike(loans[i].lender()).pool(), address(poolV1));
        }
    }

    // TODO: rename this ambiguous function
    function assertAllLoansBelongToRespectivePools() internal {
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
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

    function assertAllPoolsMatchSnapshot() internal {
        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertPoolMatchesSnapshot(icebreakerPoolV1);
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

    function assertAllPoolAccounting() internal {
        assertPoolAccounting(mavenPermissionedPoolManager, mavenPermissionedLoans);
        assertPoolAccounting(mavenUsdcPoolManager,         mavenUsdcLoans);
        assertPoolAccounting(mavenWethPoolManager,         mavenWethLoans);
        assertPoolAccounting(orthogonalPoolManager,        orthogonalLoans);
        assertPoolAccounting(icebreakerPoolManager,        icebreakerLoans);
    }

    function assertPrincipalOut(address transitionLoanManager, IMapleLoanLike[] storage loans) internal {
        uint256 totalPrincipal;
        for (uint256 i = 0; i < loans.length; i++) {
            totalPrincipal += loans[i].principal();
        }

        assertEq(ITransitionLoanManagerLike(transitionLoanManager).principalOut(), totalPrincipal);
    }

    function assertAllPrincipalOuts() internal {
        assertPrincipalOut(mavenPermissionedPoolManager.loanManagerList(0), mavenPermissionedLoans);
        assertPrincipalOut(mavenUsdcPoolManager.loanManagerList(0),         mavenUsdcLoans);
        assertPrincipalOut(mavenWethPoolManager.loanManagerList(0),         mavenWethLoans);
        assertPrincipalOut(orthogonalPoolManager.loanManagerList(0),        orthogonalLoans);
        assertPrincipalOut(icebreakerPoolManager.loanManagerList(0),        icebreakerLoans);
    }

    function assertTotalSupply(IPoolManagerLike poolManager, IPoolLike poolV1) internal {
        assertEq(IPoolLike(poolManager.pool()).totalSupply(), getPoolV1TotalValue(poolV1));
    }

    function assertAllTotalSupplies() internal {
        assertTotalSupply(mavenPermissionedPoolManager, mavenPermissionedPoolV1);
        assertTotalSupply(mavenUsdcPoolManager,         mavenUsdcPoolV1);
        assertTotalSupply(mavenWethPoolManager,         mavenWethPoolV1);
        assertTotalSupply(orthogonalPoolManager,        orthogonalPoolV1);
        assertTotalSupply(icebreakerPoolManager,        icebreakerPoolV1);
    }

    function assertVersion(uint256 version_ , address instance_) internal {
        assertEq(
            IMapleProxiedLike(instance_).implementation(),
            IMapleProxyFactoryLike(IMapleProxiedLike(instance_).factory()).implementationOf(version_)
        );
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

    function compareAllLpPositions() internal {
        compareLpPositions(mavenWethPoolV1,         mavenWethPoolManager.pool(),         mavenWethLps);
        compareLpPositions(mavenUsdcPoolV1,         mavenUsdcPoolManager.pool(),         mavenUsdcLps);
        compareLpPositions(mavenPermissionedPoolV1, mavenPermissionedPoolManager.pool(), mavenPermissionedLps);
        compareLpPositions(orthogonalPoolV1,        orthogonalPoolManager.pool(),        orthogonalLps);
        compareLpPositions(icebreakerPoolV1,        icebreakerPoolManager.pool(),        icebreakerLps);
    }

    function convertToAddresses(IMapleLoanLike[] storage inputArray) internal view returns (address[] memory outputArray) {
        outputArray = new address[](inputArray.length);
        for (uint256 i; i < inputArray.length; ++i) {
            outputArray[i] = address(inputArray[i]);
        }
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

    function getNextLoan(IMapleLoanLike[] storage loans) internal view returns (address loan) {
        ( loan, ) = getNextLoanAndPaymentDueDate(loans);
    }

    function getNextLoanAndPaymentDueDate(IMapleLoanLike[] storage loans) internal view returns (address loan, uint256 nextPaymentDueDate) {
        for (uint256 i; i < loans.length; ++i) {
            uint256 dueDate = loans[i].nextPaymentDueDate();

            if (!isEarlierThan(dueDate, nextPaymentDueDate)) continue;

            loan               = address(loans[i]);
            nextPaymentDueDate = dueDate;
        }
    }

    function getPoolV1TotalValue(IPoolLike poolV1) internal view returns (uint256 totalValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        totalValue = poolV1.totalSupply() * 10 ** asset.decimals() / 1e18 + poolV1.interestSum() - poolV1.poolLosses();
    }

    function getSumPosition(IPoolLike poolV1, address[] storage lps) internal view returns (uint256 positionValue) {
        for (uint256 i; i < lps.length; ++i) {
            positionValue += getV1Position(poolV1, lps[i]);
        }
    }

    function getV1Position(IPoolLike poolV1, address lp) internal view returns (uint256 positionValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        positionValue = poolV1.balanceOf(lp) * 10 ** asset.decimals() / 1e18 + poolV1.withdrawableFundsOf(lp) - poolV1.recognizableLossesOf(lp);
    }

    function handleCoverProviderEdgeCase() internal {
        // Handle weird scenario in maven usdc and orthogonal pool, where users have increased the allowance, but haven't actually staked.
        vm.prank(0x8476D9239fe38Ca683c6017B250112121cdB8D9B);
        IMplRewardsLike(address(orthogonalRewards)).stake(701882135971108600);

        vm.prank(0xFe14c77979Ea159605b0fABDeB59B1166C3D95e3);
        IMplRewardsLike(address(mavenUsdcRewards)).stake(299953726765028070);
    }

    function isEarlierThan(uint256 timestamp, uint256 threshold) internal pure returns (bool isEarlier) {
        if (timestamp == 0) return false;

        if (threshold == 0) return true;

        return timestamp < threshold;
    }

    function setGlobalsOfFactory(address factory, address globals) internal {
        IMapleProxyFactoryLike factory_ = IMapleProxyFactoryLike(factory);

        vm.prank(MapleGlobalsV2(factory_.mapleGlobals()).governor());
        factory_.setGlobals(globals);
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

    function snapshotAllPoolStates() internal {
        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);
    }

    function storeCoverAmounts() internal {
        // Save the necessary pool cover amount for each pool
        coverAmounts[address(mavenPermissionedPoolV1)] = 1_750_000e6;
        coverAmounts[address(mavenUsdcPoolV1)]         = 1_000_000e6;
        coverAmounts[address(mavenWethPoolV1)]         = 750e18;
        coverAmounts[address(orthogonalPoolV1)]        = 2_500_000e6;
        coverAmounts[address(icebreakerPoolV1)]        = 500_000e6;
    }


    /******************************************************************************************************************************/
    /*** Contingency Helpers                                                                                                    ***/
    /******************************************************************************************************************************/

    // Rollback Liquidity Migration Procedure #4
    function enableLoanDowngradeFromV301() internal {
        vm.prank(governor);
        loanFactory.enableUpgradePath(301, 300, address(0));
    }

    // Rollback Liquidity Migration Procedure #4
    function disableLoanUpgradeFromV300() internal {
        vm.startPrank(governor);

        loanFactory.disableUpgradePath(300, 301);
        loanFactory.disableUpgradePath(301, 302);
        loanFactory.disableUpgradePath(302, 400);
        loanFactory.setDefaultVersion(300);

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #4
    function downgradeLoansFromV301(IMapleLoanLike[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = loans[i];

            uint256 currentVersion = loanFactory.versionOf(loan.implementation());

            if (currentVersion == 200 || currentVersion == 300) continue;

            loan.upgrade(300, new bytes(0));

            assertVersion(300, address(loan));
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #4
    function downgradeAllLoansFromV301() internal {
        downgradeLoansFromV301(mavenPermissionedLoans);
        downgradeLoansFromV301(mavenUsdcLoans);
        downgradeLoansFromV301(mavenWethLoans);
        downgradeLoansFromV301(orthogonalLoans);
        downgradeLoansFromV301(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #9 and #15
    function enableDebtLockerDowngradeFromV400() internal {
        vm.prank(governor);
        debtLockerFactory.enableUpgradePath(400, 300, address(0));
    }

    // Rollback Liquidity Migration Procedure #9
    function disableDebtLockerUpgradeFromV300() internal {
        vm.prank(governor);
        debtLockerFactory.disableUpgradePath(300, 400);
    }

    // Rollback Liquidity Migration Procedure #9
    function downgradeDebtLockersFromV400(IMapleLoanLike[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());
            debtLocker.upgrade(300, new bytes(0));
            assertVersion(300, address(debtLocker));
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #9
    function downgradeAllDebtLockersFromV400() internal {
        downgradeDebtLockersFromV400(mavenPermissionedLoans);
        downgradeDebtLockersFromV400(mavenUsdcLoans);
        downgradeDebtLockersFromV400(mavenWethLoans);
        downgradeDebtLockersFromV400(orthogonalLoans);
        downgradeDebtLockersFromV400(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #11 and #16
    function enableLoanDowngradeFromV302() internal {
        vm.prank(governor);
        loanFactory.enableUpgradePath(302, 301, address(0));
    }

    // Rollback Liquidity Migration Procedure #11
    function disableLoanUpgradesFromV301() internal {
        vm.startPrank(governor);
        loanFactory.disableUpgradePath(301, 302);
        loanFactory.disableUpgradePath(302, 400);
        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #11
    function downgradeLoansFromV302(IMapleLoanLike[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = loans[i];

            uint256 currentVersion = loanFactory.versionOf(loan.implementation());

            if (currentVersion == 200 || currentVersion == 301) continue;

            loan.upgrade(301, new bytes(0));

            assertVersion(301, address(loan));
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #11
    function downgradeAllLoansFromV302() internal {
        downgradeLoansFromV302(mavenPermissionedLoans);
        downgradeLoansFromV302(mavenUsdcLoans);
        downgradeLoansFromV302(mavenWethLoans);
        downgradeLoansFromV302(orthogonalLoans);
        downgradeLoansFromV302(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #14
    // TODO: maybe use generic action?
    // TODO: paybackMigrationLoanToPoolV1 if needed
    function paybackMigrationLoanToPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        IMapleLoanLike migrationLoan = migrationLoans[address(poolV1)];

        if (address(migrationLoan) == address(0)) return;

        vm.prank(migrationMultisig);
        migrationLoan.closeLoan(0);

        // TODO: this assumes last loan is migration loan
        // TODO: make and use the generic migration loan popper used elsewhere above
        // TODO: remove from the migration loan mapping as well
        loans.pop();

        vm.prank(poolV1.poolDelegate());
        poolV1.claim(address(migrationLoan), address(debtLockerFactory));
    }

    // Rollback Liquidity Migration Procedure #14
    function paybackAllMigrationLoansToPoolV1s() internal {
        paybackMigrationLoanToPoolV1(mavenPermissionedPoolV1, mavenPermissionedLoans);
        paybackMigrationLoanToPoolV1(mavenUsdcPoolV1,         mavenUsdcLoans);
        paybackMigrationLoanToPoolV1(mavenWethPoolV1,         mavenWethLoans);
        paybackMigrationLoanToPoolV1(orthogonalPoolV1,        orthogonalLoans);
        paybackMigrationLoanToPoolV1(icebreakerPoolV1,        icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #15
    function downgradeDebtLockerFromV400(IMapleLoanLike loan) internal {
        if (address(loan) == address(0)) return;

        IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

        vm.prank(globalAdmin);
        debtLocker.upgrade(300, new bytes(0));

        assertVersion(300, address(debtLocker));
    }

    // Rollback Liquidity Migration Procedure #15
    function downgradeAllMigrationLoanDebtLockersFromV400() internal {
        downgradeDebtLockerFromV400(migrationLoans[address(mavenPermissionedPoolV1)]);
        downgradeDebtLockerFromV400(migrationLoans[address(mavenUsdcPoolV1)]);
        downgradeDebtLockerFromV400(migrationLoans[address(mavenWethPoolV1)]);
        downgradeDebtLockerFromV400(migrationLoans[address(orthogonalPoolV1)]);
        downgradeDebtLockerFromV400(migrationLoans[address(icebreakerPoolV1)]);
    }

    // Rollback Liquidity Migration Procedure #16
    function downgradeMigrationLoansFromV302(IMapleLoanLike loan) internal {
        if (address(loan) == address(0)) return;

        uint256 currentVersion = loanFactory.versionOf(loan.implementation());

        if (currentVersion == 200 || currentVersion == 301) return;

        vm.prank(globalAdmin);
        loan.upgrade(301, new bytes(0));

        assertVersion(301, address(loan));
    }

    // Rollback Liquidity Migration Procedure #16
    function downgradeAllMigrationLoansFromV302() internal {
        downgradeMigrationLoansFromV302(migrationLoans[address(mavenPermissionedPoolV1)]);
        downgradeMigrationLoansFromV302(migrationLoans[address(mavenUsdcPoolV1)]);
        downgradeMigrationLoansFromV302(migrationLoans[address(mavenWethPoolV1)]);
        downgradeMigrationLoansFromV302(migrationLoans[address(orthogonalPoolV1)]);
        downgradeMigrationLoansFromV302(migrationLoans[address(icebreakerPoolV1)]);
    }

    // Rollback Liquidity Migration Procedure #23
    function unsetPendingLenders(IMapleLoanLike[] storage loans) internal {
        vm.prank(migrationMultisig);
        migrationHelper.rollback_setPendingLenders(convertToAddresses(loans));
    }

    // Rollback Liquidity Migration Procedure #23
    function unsetPendingLendersForAllPools() internal {
        unsetPendingLenders(mavenPermissionedLoans);
        unsetPendingLenders(mavenUsdcLoans);
        unsetPendingLenders(mavenWethLoans);
        unsetPendingLenders(orthogonalLoans);
        unsetPendingLenders(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #24
    function revertOwnershipOfLoans(IPoolManagerLike poolManager, IMapleLoanLike[] storage loans_) internal {
        address loanManager = poolManager.loanManagerList(0);

        vm.prank(migrationMultisig);
        migrationHelper.rollback_takeOwnershipOfLoans(loanManager, convertToAddresses(loans_));
    }

    // Rollback Liquidity Migration Procedure #24
    function revertOwnershipOfLoansForAllPools() internal {
        revertOwnershipOfLoans(mavenPermissionedPoolManager, mavenPermissionedLoans);
        revertOwnershipOfLoans(mavenUsdcPoolManager,         mavenUsdcLoans);
        revertOwnershipOfLoans(mavenWethPoolManager,         mavenWethLoans);
        revertOwnershipOfLoans(orthogonalPoolManager,        orthogonalLoans);
        revertOwnershipOfLoans(icebreakerPoolManager,        icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #25
    function enableLoanManagerDowngradeFromV200() internal {
        vm.prank(tempGovernor);
        loanManagerFactory.enableUpgradePath(200, 100, address(0));
    }

    // Rollback Liquidity Migration Procedure #25
    function downgradeLoanManagerFromV200(IPoolManagerLike poolManager) internal {
        IMapleProxiedLike loanManager = IMapleProxiedLike(poolManager.loanManagerList(0));

        vm.prank(tempGovernor);
        loanManager.upgrade(100, new bytes(0));

        assertVersion(100, address(loanManager));
    }

    // Rollback Liquidity Migration Procedure #25
    function downgradeAllLoanManagersFromV200() internal {
        downgradeLoanManagerFromV200(mavenPermissionedPoolManager);
        downgradeLoanManagerFromV200(mavenUsdcPoolManager);
        downgradeLoanManagerFromV200(mavenWethPoolManager);
        downgradeLoanManagerFromV200(orthogonalPoolManager);
        downgradeLoanManagerFromV200(icebreakerPoolManager);
    }

    // Rollback Liquidity Migration Procedure #26
    function setGlobalsOfLoanFactoryToV1() internal {
        setGlobalsOfFactory(address(loanFactory), address(mapleGlobalsV1));
    }

    // Rollback Liquidity Migration Procedure #26
    function enableLoanDowngradeFromV400() internal {
        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));
    }

    // Rollback Liquidity Migration Procedure #26
    function disableLoanUpgradeFromV302() internal {
        vm.prank(governor);
        loanFactory.disableUpgradePath(302, 400);
    }

    // Rollback Liquidity Migration Procedure #26
    function downgradeLoansFromV400(IMapleLoanLike[] storage loans) internal {
        vm.startPrank(securityAdminMultisig);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = loans[i];

            uint256 currentVersion = loanFactory.versionOf(loan.implementation());

            if (currentVersion == 200 || currentVersion == 300 || currentVersion == 301 || currentVersion == 302) continue;

            loan.upgrade(302, new bytes(0));

            assertVersion(302, address(loan));
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #26
    function downgradeAllLoansFromV400() internal {
        downgradeLoansFromV400(mavenPermissionedLoans);
        downgradeLoansFromV400(mavenUsdcLoans);
        downgradeLoansFromV400(mavenWethLoans);
        downgradeLoansFromV400(orthogonalLoans);
        downgradeLoansFromV400(icebreakerLoans);
    }

}
