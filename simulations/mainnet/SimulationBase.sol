// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

import { DebtLocker as DebtLockerV4 } from "../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerV4Migrator }       from "../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { MapleGlobals as MapleGlobalsV2 }         from "../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy as MapleGlobalsNTP } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { Liquidator }            from "../../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory }     from "../../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleLoan as MapleLoanV302 }                       from "../../modules/loan-v302/contracts/MapleLoan.sol";
import { MapleLoan as MapleLoanV400 }                       from "../../modules/loan-v400/contracts/MapleLoan.sol";
import { MapleLoanFeeManager }                              from "../../modules/loan-v400/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MapleLoanV400Initializer } from "../../modules/loan-v400/contracts/MapleLoanInitializer.sol";
import { MapleLoanV4Migrator as MapleLoanV400Migrator }     from "../../modules/loan-v400/contracts/MapleLoanV4Migrator.sol";
import { Refinancer }                                       from "../../modules/loan-v400/contracts/Refinancer.sol";
import { MapleLoan as MapleLoanV401 }                       from "../../modules/loan-v401/contracts/MapleLoan.sol";

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
    IAccountingCheckerLike,
    IDebtLockerLike,
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsV1Like,
    IMapleGlobalsV2Like,
    IMapleLoanLike,
    IMapleProxiedLike,
    IMapleProxyFactoryLike,
    IMigrationHelperLike,
    IMplRewardsLike,
    IPoolDeployerLike,
    IPoolManagerLike,
    IPoolV1Like,
    IPoolV2Like,
    IStakeLockerLike
} from "./Interfaces.sol";

// TODO: either treat things as generics (i.e. IMapleProxy.upgrade), or as explicit (i.e. IMapleLoanV400.upgrade)

contract SimulationBase is GenericActions, AddressRegistry {

    uint256 constant END_MIGRATION = 1670986667;  // Dec 13, 2022

    struct PoolState {
        uint256 cash;
        uint256 interestSum;
        uint256 liquidityCap;
        uint256 poolLosses;
        uint256 principalOut;
        uint256 totalSupply;
    }

    mapping(address => PoolState) internal poolStateSnapshot;

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

        // NOTE: Skipped as this was already performed on mainnet.
        // deployProtocol();  // LMP #5

        // NOTE: Skipped as these were already performed on mainnet.
        // tempGovernorAcceptsV2Governorship();                   // LMP #6
        // migrationMultisigAcceptsMigrationAdministratorship();  // LMP #7
        // setupExistingFactories();                              // LMP #8.1

        // Pre-Kickoff
        upgradeAllDebtLockersToV400();  // LMP #9.1

        // setUpDebtLockerFactoryFor401();  // LMP #8.2

        upgradeAllDebtLockersToV401();  // LMP #9.2

        claimAllLoans();                // LMP #10

        checkSumOfLoanPrincipalForAllPools();

        // Kickoff
        upgradeAllLoansToV302();    // LMP #11
        lockAllPoolV1Deposits();    // LMP #12
        createAllMigrationLoans();  // LMP #13

        checkSumOfLoanPrincipalForAllPools();

        // Migration Loan Funding
        // NOTE: Technically, each loan is funded and their DebtLockers are upgraded per pool before moving onto the next
        fundAllMigrationLoans();               // LMP #14
        upgradeAllMigrationLoanDebtLockers();  // LMP #15

        upgradeAllMigrationLoansToV302();  // LMP #16

        pauseV1Protocol();  // LMP #17

        deployAllPoolV2s();  // LMP #18

        setFees();  // LMP #19

        checkSumOfLoanPrincipalForAllPools();

        addLoansToAllLoanManagers();  // LMP #20

        // Prepare for Airdrops
        activateAllPoolManagers();  // LMP #21
        openOrAllowOnAllPoolV2s();  // LMP #22

        airdropTokensForAllPools();  // LMP #23
        assertAllPoolAccounting();

        // Transfer Loans
        // TODO: Do we really need all these repetitive assertions? Especially that we have validation script now.
        setAllPendingLenders();         // LMP #24
        assertAllPoolAccounting();
        takeAllOwnershipsOfLoans();     // LMP #25
        assertAllPoolAccounting();
        upgradeAllLoanManagers();       // LMP #26
        assertAllPrincipalOuts();
        assertAllTotalSupplies();
        assertAllPoolAccounting();
        setAllCoverParameters();
        assertAllPoolAccounting();
        upgradeAllLoansToV400();        // LMP #27

        compareAllLpPositions();

        // Close Migration Loans
        setGlobalsOfLoanFactoryToV2();  // LMP #28
        closeAllMigrationLoans();       // LMP #29

        // Prepare PoolV1 Deactivation
        unlockV1Staking();    // LMP #30
        unpauseV1Protocol();  // LMP #31

        deactivateAndUnstakeAllPoolV1s();  // LMPs #32-#36

        enableFinalPoolDelegates();  // LMP #37

        transferAllPoolDelegates();  // LMPs #38-#39

        // Transfer Governorship of GlobalsV2
        tempGovernorTransfersV2Governorship();  // LMPs #40
        governorAcceptsV2Governorship();        // LMPs #41

        setLoanDefault400();  // LMPs #42

        finalizeProtocol();  // LMPs #43-#46

        // Dec 8
        handleCoverProviderEdgeCase();

        // Make cover providers withdraw
        withdrawAllCovers();

        // PoolV2 Lifecycle start
        depositAllCovers();
        increaseAllLiquidityCaps();
    }

    // Liquidity Migration Procedure #1
    function setPoolV1Admin(address poolV1, address poolAdmin) internal {
        vm.prank(IPoolV1Like(poolV1).poolDelegate());
        IPoolV1Like(poolV1).setPoolAdmin(poolAdmin, true);
    }

    // Liquidity Migration Procedure #1
    function setPoolAdminsToMigrationMultisig() internal {
        setPoolV1Admin(mavenPermissionedPoolV1, migrationMultisig);
        setPoolV1Admin(mavenUsdcPoolV1,         migrationMultisig);
        setPoolV1Admin(mavenWethPoolV1,         migrationMultisig);
        setPoolV1Admin(orthogonalPoolV1,        migrationMultisig);
        setPoolV1Admin(icebreakerPoolV1,        migrationMultisig);
    }

    // Liquidity Migration Procedure #2
    function zeroInvestorFeeAndTreasuryFee() internal {
        vm.startPrank(governor);
        IMapleGlobalsV1Like(mapleGlobalsV1).setInvestorFee(0);
        IMapleGlobalsV1Like(mapleGlobalsV1).setTreasuryFee(0);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #3
    function payAndClaimUpcomingLoans(address[] storage loans) internal {
        for (uint256 i; i < loans.length;) {
            IMapleLoanLike loan       = IMapleLoanLike(loans[i]);
            IERC20Like     fundsAsset = IERC20Like(loan.fundsAsset());

            uint256 paymentDueDate = loan.nextPaymentDueDate();

            if (paymentDueDate > END_MIGRATION) {
                ++i;
                continue;
            }

            if (paymentDueDate > 0) {
                ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = loan.getNextPaymentBreakdown();

                uint256 paymentAmount = principal + interest + delegateFee + treasuryFee;

                erc20_mint(address(fundsAsset), loan.borrower(), paymentAmount);

                vm.startPrank(loan.borrower());

                fundsAsset.approve(address(loan), paymentAmount);
                loan.makePayment(paymentAmount);

                vm.stopPrank();
            }

            IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

            IPoolV1Like pool = IPoolV1Like(debtLocker.pool());

            vm.prank(debtLocker.poolDelegate());
            pool.claim(address(loan), debtLockerFactory);

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
    function upgradeLoansToV301(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            uint256 currentVersion = IMapleProxyFactoryLike(loanFactory).versionOf(loan.implementation());

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

        mapleGlobalsV2Proxy = address(new MapleGlobalsNTP(deployer, mapleGlobalsV2Implementation));

        // Deploy FeeManager
        feeManager = address(new MapleLoanFeeManager(mapleGlobalsV2Proxy));

        // Deploy PoolDeployer
        poolDeployer = address(new PoolDeployer(mapleGlobalsV2Proxy));

        // Liquidator Factory Deployments and Configuration
        liquidatorFactory        = address(new LiquidatorFactory(mapleGlobalsV2Proxy));
        liquidatorImplementation = address(new Liquidator());
        liquidatorInitializer    = address(new LiquidatorInitializer());

        IMapleProxyFactoryLike(liquidatorFactory).registerImplementation(200, liquidatorImplementation, liquidatorInitializer);
        IMapleProxyFactoryLike(liquidatorFactory).setDefaultVersion(200);

        // Loan Manager Factory Deployments and Configuration
        loanManagerFactory                  = address(new LoanManagerFactory(mapleGlobalsV2Proxy));
        loanManagerImplementation           = address(new LoanManager());
        loanManagerInitializer              = address(new LoanManagerInitializer());
        transitionLoanManagerImplementation = address(new TransitionLoanManager());

        IMapleProxyFactoryLike(loanManagerFactory).registerImplementation(100, transitionLoanManagerImplementation, loanManagerInitializer);
        IMapleProxyFactoryLike(loanManagerFactory).registerImplementation(200, loanManagerImplementation,           loanManagerInitializer);
        IMapleProxyFactoryLike(loanManagerFactory).enableUpgradePath(100, 200, address(0));
        IMapleProxyFactoryLike(loanManagerFactory).setDefaultVersion(100);

        // Pool Manager Factory Deployments and Configuration
        poolManagerFactory        = address(new PoolManagerFactory(mapleGlobalsV2Proxy));
        poolManagerImplementation = address(new PoolManager());
        poolManagerInitializer    = address(new PoolManagerInitializer());

        IMapleProxyFactoryLike(poolManagerFactory).registerImplementation(100, poolManagerImplementation, poolManagerInitializer);
        IMapleProxyFactoryLike(poolManagerFactory).setDefaultVersion(100);

        // Withdrawal Manager Factory Deployments and Configuration
        withdrawalManagerFactory        = address(new WithdrawalManagerFactory(mapleGlobalsV2Proxy));
        withdrawalManagerImplementation = address(new WithdrawalManager());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        IMapleProxyFactoryLike(withdrawalManagerFactory).registerImplementation(100, withdrawalManagerImplementation, withdrawalManagerInitializer);
        IMapleProxyFactoryLike(withdrawalManagerFactory).setDefaultVersion(100);

        // Loan Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        loanV302Implementation = address(new MapleLoanV302());
        loanV400Initializer    = address(new MapleLoanV400Initializer());
        loanV400Implementation = address(new MapleLoanV400());
        loanV400Migrator       = address(new MapleLoanV400Migrator());

        // DebtLocker Factory Deployments
        // NOTE: setup in `setupExistingFactories` by GovernorV1
        debtLockerV400Migrator       = address(new DebtLockerV4Migrator());
        debtLockerV400Implementation = address(new DebtLockerV4());

        // Deploy MigrationHelper, AccountingChecker, and DeactivationOracle
        accountingChecker  = address(new AccountingChecker(mapleGlobalsV2Proxy));
        deactivationOracle = address(new DeactivationOracle());

        address migrationHelperImplementation = address(new MigrationHelper());

        migrationHelperProxy = address(new MigrationHelperNTP(deployer, migrationHelperImplementation));

        refinancer = address(new Refinancer());

        // Configure MigrationHelper
        IMigrationHelperLike(migrationHelperProxy).setPendingAdmin(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).setGlobals(mapleGlobalsV2Proxy);

        // Configure Globals Addresses
        MapleGlobalsV2 mapleGlobalsV2 = MapleGlobalsV2(mapleGlobalsV2Proxy);

        mapleGlobalsV2.setMapleTreasury(mapleTreasury);
        mapleGlobalsV2.setSecurityAdmin(securityAdmin);
        mapleGlobalsV2.setMigrationAdmin(migrationHelperProxy);

        // Set Globals Valid Addresses
        mapleGlobalsV2.setValidPoolDeployer(poolDeployer, true);

        for (uint256 i; i < mavenPermissionedLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(IMapleLoanLike(mavenPermissionedLoans[i]).borrower(), true);
        }

        for (uint256 i; i < mavenUsdcLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(IMapleLoanLike(mavenUsdcLoans[i]).borrower(), true);
        }

        for (uint256 i; i < mavenWethLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(IMapleLoanLike(mavenWethLoans[i]).borrower(), true);
        }

        for (uint256 i; i < orthogonalLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(IMapleLoanLike(orthogonalLoans[i]).borrower(), true);
        }

        for (uint256 i; i < icebreakerLoans.length; ++i) {
            mapleGlobalsV2.setValidBorrower(IMapleLoanLike(icebreakerLoans[i]).borrower(), true);
        }

        mapleGlobalsV2.setValidPoolDelegate(mavenPermissionedTemporaryPd, true);
        mapleGlobalsV2.setValidPoolDelegate(mavenUsdcTemporaryPd,         true);
        mapleGlobalsV2.setValidPoolDelegate(mavenWethTemporaryPd,         true);
        mapleGlobalsV2.setValidPoolDelegate(orthogonalTemporaryPd,        true);
        mapleGlobalsV2.setValidPoolDelegate(icebreakerTemporaryPd,        true);

        // NOTE: Not setting wbtc as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidPoolAsset(usdc, true);
        mapleGlobalsV2.setValidPoolAsset(weth, true);

        // NOTE: Not setting usdc and weth as it is not needed immediately. See `performAdditionalGlobalsSettings`
        mapleGlobalsV2.setValidCollateralAsset(weth, true);
        mapleGlobalsV2.setValidCollateralAsset(wbtc, true);

        mapleGlobalsV2.setValidFactory("LIQUIDATOR",         liquidatorFactory,        true);
        mapleGlobalsV2.setValidFactory("LOAN",               loanFactory,              true);
        mapleGlobalsV2.setValidFactory("LOAN_MANAGER",       loanManagerFactory,       true);
        mapleGlobalsV2.setValidFactory("POOL_MANAGER",       poolManagerFactory,       true);
        mapleGlobalsV2.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, true);

        // Configure Globals Values
        mapleGlobalsV2.setBootstrapMint(usdc, 0.100000e6);
        mapleGlobalsV2.setBootstrapMint(weth, 0.0001e18);

        mapleGlobalsV2.setDefaultTimelockParameters(1 weeks, 2 days);

        mapleGlobalsV2.setPriceOracle(usdc, usdUsdOracle);
        mapleGlobalsV2.setPriceOracle(wbtc, btcUsdOracle);
        mapleGlobalsV2.setPriceOracle(weth, ethUsdOracle);

        // Transfer governor
        mapleGlobalsV2.setPendingGovernor(tempGovernor);
    }

    function _deploy401DebtLockerAndAccountingChecker() internal {
        debtLockerV401Implementation = address(new DebtLockerV4());

        accountingChecker = address(new AccountingChecker(mapleGlobalsV2Proxy));
    }

    // Liquidity Migration Procedure #5
    function deployProtocol() internal {
        vm.startPrank(deployer);
        _deployProtocol();
        _deploy401DebtLockerAndAccountingChecker();
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #6
    function tempGovernorAcceptsV2Governorship() internal {
        vm.prank(tempGovernor);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).acceptGovernor();
    }

    // Liquidity Migration Procedure #7
    function migrationMultisigAcceptsMigrationAdministratorship() internal {
        vm.prank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).acceptOwner();
    }

    // Liquidity Migration Procedure #8.1
    function setupExistingFactories() internal {
        vm.startPrank(governor);

        IMapleProxyFactoryLike debtLockerFactory_ = IMapleProxyFactoryLike(debtLockerFactory);

        debtLockerFactory_.registerImplementation(400, debtLockerV400Implementation, debtLockerV300Initializer);
        debtLockerFactory_.enableUpgradePath(300, 400, debtLockerV400Migrator);

        IMapleProxyFactoryLike loanFactory_ = IMapleProxyFactoryLike(loanFactory);

        loanFactory_.registerImplementation(302, loanV302Implementation, loanV300Initializer);
        loanFactory_.registerImplementation(400, loanV400Implementation, loanV400Initializer);
        loanFactory_.enableUpgradePath(301, 302, address(0));
        loanFactory_.enableUpgradePath(302, 400, loanV400Migrator);
        loanFactory_.setDefaultVersion(301);

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #8.2
    function setUpDebtLockerFactoryFor401() internal {
        // Configure Factory
        vm.startPrank(IMapleGlobalsV1Like(mapleGlobalsV1).governor());

        IMapleProxyFactoryLike(debtLockerFactory).registerImplementation(401, debtLockerV401Implementation, address(0));
        IMapleProxyFactoryLike(debtLockerFactory).enableUpgradePath(400, 401, debtLockerV400Migrator);

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #9.1
    function upgradeDebtLockersToV400(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IDebtLockerLike debtLocker = IDebtLockerLike(IDebtLockerLike(loans[i]).lender());

            if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 400) return;

            vm.prank(debtLocker.poolDelegate());
            debtLocker.upgrade(400, abi.encode(address(0)));

            assertVersion(400, address(debtLocker));
        }
    }

    // Liquidity Migration Procedure #9.1
    function upgradeAllDebtLockersToV400() internal {
        upgradeDebtLockersToV400(mavenPermissionedLoans);
        upgradeDebtLockersToV400(mavenUsdcLoans);
        upgradeDebtLockersToV400(mavenWethLoans);
        upgradeDebtLockersToV400(orthogonalLoans);
        upgradeDebtLockersToV400(icebreakerLoans);
    }

    // Liquidity Migration Procedure #9.2
    function upgradeDebtLockersToV401(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IDebtLockerLike debtLocker = IDebtLockerLike(IDebtLockerLike(loans[i]).lender());

            if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 401) return;

            vm.prank(IMapleGlobalsV1Like(mapleGlobalsV1).globalAdmin());
            debtLocker.upgrade(401, abi.encode(migrationHelperProxy));

            assertVersion(401, address(debtLocker));
        }
    }

    // Liquidity Migration Procedure #9.2
    function upgradeAllDebtLockersToV401() internal {
        upgradeDebtLockersToV401(mavenPermissionedLoans);
        upgradeDebtLockersToV401(mavenUsdcLoans);
        upgradeDebtLockersToV401(mavenWethLoans);
        upgradeDebtLockersToV401(orthogonalLoans);
        upgradeDebtLockersToV401(icebreakerLoans);
    }

    // Liquidity Migration Procedure #10
    function claimLoans(address poolV1, address[] storage loans) internal {
        address poolDelegate = IPoolV1Like(poolV1).poolDelegate();

        vm.startPrank(poolDelegate);

        for (uint256 i; i < loans.length;) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            if (loan.claimableFunds() == 0) {
                ++i;
                continue;
            }

            IPoolV1Like(poolV1).claim(address(loan), IMapleProxiedLike(loan.lender()).factory());

            if (loan.paymentsRemaining() > 0) {
                ++i;
                continue;
            }

            loans[i] = loans[loans.length - 1];
            loans.pop();
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
    function upgradeLoansToV302(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];

            IMapleLoanLike(loan).upgrade(302, new bytes(0));

            assertVersion(302, loan);
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
    function lockPoolV1Deposits(address poolV1) internal {
        setLiquidityCap(poolV1, 0);
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
    function createMigrationLoan(address poolV1, address[] storage loans, uint256 liquidity) internal returns (address migrationLoan) {
        address asset = IPoolV1Like(poolV1).liquidityAsset();

        address[2] memory assets      = [asset, asset];
        uint256[3] memory termDetails = [uint256(0), uint256(3 days), uint256(1)];
        uint256[3] memory requests    = [uint256(0), liquidity, liquidity];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory args = abi.encode(migrationMultisig, assets, termDetails, requests, rates);
        bytes32 salt      = keccak256(abi.encode(poolV1));
        migrationLoan     = IMapleProxyFactoryLike(loanFactory).createInstance(args, salt);

        loans.push(migrationLoan);
    }

    // Liquidity Migration Procedure #13
    function createMigrationLoanIfRequired(address poolV1, address[] storage loans) internal returns (address migrationLoan) {
        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);

        if (availableLiquidity > 0) {
            migrationLoan = createMigrationLoan(poolV1, loans, availableLiquidity);
        }
    }

    // Liquidity Migration Procedure #13
    function createAllMigrationLoans() internal {
        mavenPermissionedMigrationLoan = createMigrationLoanIfRequired(mavenPermissionedPoolV1, mavenPermissionedLoans);
        mavenUsdcMigrationLoan         = createMigrationLoanIfRequired(mavenUsdcPoolV1,         mavenUsdcLoans);
        mavenWethMigrationLoan         = createMigrationLoanIfRequired(mavenWethPoolV1,         mavenWethLoans);
        orthogonalMigrationLoan        = createMigrationLoanIfRequired(orthogonalPoolV1,        orthogonalLoans);
        icebreakerMigrationLoan        = createMigrationLoanIfRequired(icebreakerPoolV1,        icebreakerLoans);
    }

    // Liquidity Migration Procedures #11-#13
    function kickoffOnPoolV1(address poolV1, address[] storage loans) internal returns (address migrationLoan) {
        upgradeLoansToV302(loans);  // Liquidity Migration Procedure #11

        lockPoolV1Deposits(poolV1);  // Liquidity Migration Procedure #12

        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1);

        if (availableLiquidity > 0) {
            migrationLoan = createMigrationLoan(poolV1, loans, availableLiquidity);  // Liquidity Migration Procedure #13
        }
    }

    // Liquidity Migration Procedures #11-#13
    function kickoffAll() internal {
        upgradeAllLoansToV302();    // Liquidity Migration Procedure #11
        lockAllPoolV1Deposits();    // Liquidity Migration Procedure #12
        createAllMigrationLoans();  // Liquidity Migration Procedure #13
    }

    // Liquidity Migration Procedure #14
    function fundMigrationLoan(address poolV1, address migrationLoan) internal {
        IPoolV1Like poolV1_ = IPoolV1Like(poolV1);

        uint256 principalRequested = IMapleLoanLike(migrationLoan).principalRequested();

        vm.prank(poolV1_.poolDelegate());
        poolV1_.fundLoan(migrationLoan, debtLockerFactory, principalRequested);

        assertEq(
            IERC20Like(poolV1_.liquidityAsset()).balanceOf(poolV1_.liquidityLocker()),
            0
        );
    }

    // Liquidity Migration Procedure #14
    function fundMigrationLoanIfNeeded(address poolV1, address migrationLoan) internal {
        if (migrationLoan == address(0)) return;

        fundMigrationLoan(poolV1, migrationLoan);
    }

    // Liquidity Migration Procedure #14
    function fundAllMigrationLoans() internal {
        fundMigrationLoanIfNeeded(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan);
        fundMigrationLoanIfNeeded(mavenUsdcPoolV1,         mavenUsdcMigrationLoan);
        fundMigrationLoanIfNeeded(mavenWethPoolV1,         mavenWethMigrationLoan);
        fundMigrationLoanIfNeeded(orthogonalPoolV1,        orthogonalMigrationLoan);
        fundMigrationLoanIfNeeded(icebreakerPoolV1,        icebreakerMigrationLoan);
    }

    // Liquidity Migration Procedure #15
    function upgradeDebtLockerToV400(address loan) internal {
        IDebtLockerLike debtLocker = IDebtLockerLike(IMapleLoanLike(loan).lender());

        if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 400) return;

        vm.prank(debtLocker.poolDelegate());
        debtLocker.upgrade(400, abi.encode(migrationHelperProxy));

        assertVersion(400, address(debtLocker));
    }

    // Liquidity Migration Procedure #15
    function upgradeDebtLockerToV400IfNeeded(address loan) internal {
        if (loan == address(0)) return;

        upgradeDebtLockerToV400(loan);
    }

    // Liquidity Migration Procedure #15
    function upgradeAllMigrationLoanDebtLockers() internal {
        upgradeDebtLockerToV400IfNeeded(mavenPermissionedMigrationLoan);
        upgradeDebtLockerToV400IfNeeded(mavenUsdcMigrationLoan);
        upgradeDebtLockerToV400IfNeeded(mavenWethMigrationLoan);
        upgradeDebtLockerToV400IfNeeded(orthogonalMigrationLoan);
        upgradeDebtLockerToV400IfNeeded(icebreakerMigrationLoan);
    }

    // Liquidity Migration Procedure #16
    function upgradeLoanToV302(address loan) internal {
        vm.prank(globalAdmin);
        IMapleLoanLike(loan).upgrade(302, new bytes(0));

        assertVersion(302, loan);
    }

    // Liquidity Migration Procedure #16
    function upgradeLoanToV302IfNeeded(address loan) internal {
        if (loan == address(0)) return;

        upgradeLoanToV302(loan);
    }

    // Liquidity Migration Procedure #16
    function upgradeAllMigrationLoansToV302() internal {
        upgradeLoanToV302IfNeeded(mavenPermissionedMigrationLoan);
        upgradeLoanToV302IfNeeded(mavenUsdcMigrationLoan);
        upgradeLoanToV302IfNeeded(mavenWethMigrationLoan);
        upgradeLoanToV302IfNeeded(orthogonalMigrationLoan);
        upgradeLoanToV302IfNeeded(icebreakerMigrationLoan);
    }

    // Liquidity Migration Procedure #17
    function pauseV1Protocol() internal {
        vm.prank(globalAdmin);
        IMapleGlobalsV1Like(mapleGlobalsV1).setProtocolPause(true);
    }

    // Liquidity Migration Procedure #18
    function deployPoolV2(address temporaryPD, address poolV1) internal returns (address poolManager) {
        address[3] memory factories = [
            poolManagerFactory,
            loanManagerFactory,
            withdrawalManagerFactory
        ];

        address[3] memory initializers = [
            IMapleProxyFactoryLike(poolManagerFactory).migratorForPath(100, 100),
            IMapleProxyFactoryLike(loanManagerFactory).migratorForPath(100, 100),
            IMapleProxyFactoryLike(withdrawalManagerFactory).migratorForPath(100, 100)
        ];

        uint256[6] memory configParams = [
            0,
            0.1e6,
            0,
            7 days,
            2 days,
            getPoolV1TotalValue(poolV1)
        ];

        address liquidityAsset = IPoolV1Like(poolV1).liquidityAsset();
        string memory name     = IPoolV1Like(poolV1).name();
        string memory symbol   = IPoolV1Like(poolV1).symbol();

        vm.prank(temporaryPD);
        ( poolManager, , ) = IPoolDeployerLike(poolDeployer).deployPool(
            factories,
            initializers,
            liquidityAsset,
            name,
            symbol,
            configParams
        );
    }

    // Liquidity Migration Procedure #18
    function deployAllPoolV2s() internal {
        mavenPermissionedPoolManager = deployPoolV2(mavenPermissionedTemporaryPd, mavenPermissionedPoolV1);
        mavenUsdcPoolManager         = deployPoolV2(mavenUsdcTemporaryPd,         mavenUsdcPoolV1);
        mavenWethPoolManager         = deployPoolV2(mavenWethTemporaryPd,         mavenWethPoolV1);
        orthogonalPoolManager        = deployPoolV2(orthogonalTemporaryPd,        orthogonalPoolV1);
        icebreakerPoolManager        = deployPoolV2(icebreakerTemporaryPd,        icebreakerPoolV1);

        mavenPermissionedPoolV2 = IPoolManagerLike(mavenPermissionedPoolManager).pool();
        mavenUsdcPoolV2         = IPoolManagerLike(mavenUsdcPoolManager).pool();
        mavenWethPoolV2         = IPoolManagerLike(mavenWethPoolManager).pool();
        orthogonalPoolV2        = IPoolManagerLike(orthogonalPoolManager).pool();
        icebreakerPoolV2        = IPoolManagerLike(icebreakerPoolManager).pool();
    }

    // Liquidity Migration Procedure #19
    function setFees() internal {
        IMapleGlobalsV2Like globalsV2 = IMapleGlobalsV2Like(mapleGlobalsV2Proxy);

        vm.startPrank(tempGovernor);

        globalsV2.setPlatformManagementFeeRate(mavenPermissionedPoolManager, 2_5000);
        globalsV2.setPlatformManagementFeeRate(mavenUsdcPoolManager,         2_5000);
        globalsV2.setPlatformManagementFeeRate(mavenWethPoolManager,         2_5000);
        globalsV2.setPlatformManagementFeeRate(orthogonalPoolManager,        2_5000);
        globalsV2.setPlatformManagementFeeRate(icebreakerPoolManager,        0);

        globalsV2.setPlatformServiceFeeRate(mavenPermissionedPoolManager, 6600);
        globalsV2.setPlatformServiceFeeRate(mavenUsdcPoolManager,         6600);
        globalsV2.setPlatformServiceFeeRate(mavenWethPoolManager,         6600);
        globalsV2.setPlatformServiceFeeRate(orthogonalPoolManager,        6600);
        globalsV2.setPlatformServiceFeeRate(icebreakerPoolManager,        6600);

        globalsV2.setPlatformOriginationFeeRate(mavenPermissionedPoolManager, 0);
        globalsV2.setPlatformOriginationFeeRate(mavenUsdcPoolManager,         0);
        globalsV2.setPlatformOriginationFeeRate(mavenWethPoolManager,         0);
        globalsV2.setPlatformOriginationFeeRate(orthogonalPoolManager,        0);
        globalsV2.setPlatformOriginationFeeRate(icebreakerPoolManager,        5000);

        globalsV2.setMaxCoverLiquidationPercent(mavenPermissionedPoolManager, 50_0000);
        globalsV2.setMaxCoverLiquidationPercent(mavenUsdcPoolManager,         100_0000);
        globalsV2.setMaxCoverLiquidationPercent(mavenWethPoolManager,         100_0000);
        globalsV2.setMaxCoverLiquidationPercent(orthogonalPoolManager,        50_0000);
        globalsV2.setMaxCoverLiquidationPercent(icebreakerPoolManager,        50_0000);

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #20
    function addLoansToLoanManager(address poolManager, address poolV1, address[] storage loans, uint256 allowedDiff) internal {
        if (loans.length == 0) return;

        address transitionLoanManager = IPoolManagerLike(poolManager).loanManagerList(0);

        vm.prank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).addLoansToLoanManager(poolV1, transitionLoanManager, loans, allowedDiff);

        loansAddedTimestamps[poolManager] = lastUpdatedTimestamps[poolManager] = block.timestamp;
    }

    // Liquidity Migration Procedure #20
    function addLoansToAllLoanManagers() internal {
        addLoansToLoanManager(mavenPermissionedPoolManager, mavenPermissionedPoolV1, mavenPermissionedLoans, 0);
        addLoansToLoanManager(mavenUsdcPoolManager,         mavenUsdcPoolV1,         mavenUsdcLoans,         2);
        addLoansToLoanManager(mavenWethPoolManager,         mavenWethPoolV1,         mavenWethLoans,         0);
        addLoansToLoanManager(orthogonalPoolManager,        orthogonalPoolV1,        orthogonalLoans,        0);
        addLoansToLoanManager(icebreakerPoolManager,        icebreakerPoolV1,        icebreakerLoans,        0);
    }

    // Liquidity Migration Procedure #21
    function activatePoolManager(address poolManager) internal {
        vm.prank(tempGovernor);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).activatePoolManager(poolManager);
    }

    // Liquidity Migration Procedure #21
    function activateAllPoolManagers() internal {
        activatePoolManager(mavenPermissionedPoolManager);
        activatePoolManager(mavenUsdcPoolManager);
        activatePoolManager(mavenWethPoolManager);
        activatePoolManager(orthogonalPoolManager);
        activatePoolManager(icebreakerPoolManager);
    }

    // Liquidity Migration Procedure #22
    function allowLendersAndWithdrawalManager(address poolManager, address[] storage lenders) internal {
        for (uint256 i; i < lenders.length; ++i) {
            allowLender(poolManager, lenders[i]);
        }

        allowLender(poolManager, IPoolManagerLike(poolManager).withdrawalManager());
    }

    // Liquidity Migration Procedure #22
    function openOrAllowOnAllPoolV2s() internal {
        allowLendersAndWithdrawalManager(mavenPermissionedPoolManager, mavenPermissionedLps);
        openPool(mavenUsdcPoolManager);
        openPool(mavenWethPoolManager);
        openPool(orthogonalPoolManager);
        allowLendersAndWithdrawalManager(icebreakerPoolManager, icebreakerLps);
    }

    // Liquidity Migration Procedure #23
    function airdropTokens(address poolV1, address poolManager, address[] storage lps) internal {
        vm.startPrank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).airdropTokens(poolV1, poolManager, lps, lps, lps.length * 2);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #23
    function airdropTokensForAllPools() internal {
        airdropTokens(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLps);
        airdropTokens(mavenUsdcPoolV1,         mavenUsdcPoolManager,         mavenUsdcLps);
        airdropTokens(mavenWethPoolV1,         mavenWethPoolManager,         mavenWethLps);
        airdropTokens(orthogonalPoolV1,        orthogonalPoolManager,        orthogonalLps);
        airdropTokens(icebreakerPoolV1,        icebreakerPoolManager,        icebreakerLps);
    }

    // Liquidity Migration Procedure #24
    function setPendingLenders(address poolV1, address poolManager, address[] storage loans, uint256 allowedDiff) internal {
        vm.startPrank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).setPendingLenders(poolV1, poolManager, loanFactory, loans, allowedDiff);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #24
    function setAllPendingLenders() internal {
        setPendingLenders(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 0);
        setPendingLenders(mavenUsdcPoolV1,         mavenUsdcPoolManager,         mavenUsdcLoans,         2);
        setPendingLenders(mavenWethPoolV1,         mavenWethPoolManager,         mavenWethLoans,         0);
        setPendingLenders(orthogonalPoolV1,        orthogonalPoolManager,        orthogonalLoans,        0);
        setPendingLenders(icebreakerPoolV1,        icebreakerPoolManager,        icebreakerLoans,        0);
    }

    // Liquidity Migration Procedure #25
    function takeOwnershipOfLoans(address poolV1, address poolManager, address[] storage loans, uint256 allowedDiff) internal {
        vm.startPrank(migrationMultisig);

        IMigrationHelperLike(migrationHelperProxy)
            .takeOwnershipOfLoans(
                poolV1,
                IPoolManagerLike(poolManager).loanManagerList(0),
                loans,
                allowedDiff
            );

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #25
    function takeAllOwnershipsOfLoans() internal {
        takeOwnershipOfLoans(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedLoans, 0);
        takeOwnershipOfLoans(mavenUsdcPoolV1,         mavenUsdcPoolManager,         mavenUsdcLoans,         2);
        takeOwnershipOfLoans(mavenWethPoolV1,         mavenWethPoolManager,         mavenWethLoans,         0);
        takeOwnershipOfLoans(orthogonalPoolV1,        orthogonalPoolManager,        orthogonalLoans,        0);
        takeOwnershipOfLoans(icebreakerPoolV1,        icebreakerPoolManager,        icebreakerLoans,        0);
    }

    // Liquidity Migration Procedure #26
    function upgradeLoanManager(address transitionLoanManager) internal {
        vm.startPrank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).upgradeLoanManager(transitionLoanManager, 200);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #26
    function upgradeAllLoanManagers() internal {
        upgradeLoanManager(IPoolManagerLike(mavenPermissionedPoolManager).loanManagerList(0));
        upgradeLoanManager(IPoolManagerLike(mavenUsdcPoolManager).loanManagerList(0));
        upgradeLoanManager(IPoolManagerLike(mavenWethPoolManager).loanManagerList(0));
        upgradeLoanManager(IPoolManagerLike(orthogonalPoolManager).loanManagerList(0));
        upgradeLoanManager(IPoolManagerLike(icebreakerPoolManager).loanManagerList(0));
    }

    // Liquidity Migration Procedure #27
    function upgradeLoansToV400(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];
            IMapleLoanLike(loan).upgrade(400, abi.encode(feeManager));
            assertVersion(400, loan);
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #27
    function upgradeAllLoansToV400() internal {
        upgradeLoansToV400(mavenPermissionedLoans);
        upgradeLoansToV400(mavenUsdcLoans);
        upgradeLoansToV400(mavenWethLoans);
        upgradeLoansToV400(orthogonalLoans);
        upgradeLoansToV400(icebreakerLoans);
    }

    // Liquidity Migration Procedure #28
    function setGlobalsOfLoanFactoryToV2() internal {
        setGlobalsOfFactory(loanFactory, mapleGlobalsV2Proxy);
    }

    // Liquidity Migration Procedure #29 [TODO: Maybe use generic action]
    function closeMigrationLoan(address migrationLoan, address[] storage loans) internal {
        closeLoan(migrationLoan);

        uint256 i;
        while (loans[i] != address(migrationLoan)) i++;

        // Move last element to index of removed loan manager and pop last element.
        loans[i] = loans[loans.length - 1];
        loans.pop();
    }

    // Liquidity Migration Procedure #29
    function closeMigrationLoanIfNeeded(address poolV1, address poolManager, address migrationLoan, address[] storage loans) internal {
        assertPoolAccounting(poolManager, loans);

        if (migrationLoan == address(0)) return;

        closeMigrationLoan(migrationLoan, loans);
        lastUpdatedTimestamps[poolManager] = block.timestamp;

        assertPoolAccounting(poolManager, loans);
    }

    // Liquidity Migration Procedure #29
    function closeAllMigrationLoans() internal {
        closeMigrationLoanIfNeeded(mavenPermissionedPoolV1, mavenPermissionedPoolManager, mavenPermissionedMigrationLoan, mavenPermissionedLoans);
        closeMigrationLoanIfNeeded(mavenUsdcPoolV1,         mavenUsdcPoolManager,         mavenUsdcMigrationLoan,         mavenUsdcLoans);
        closeMigrationLoanIfNeeded(mavenWethPoolV1,         mavenWethPoolManager,         mavenWethMigrationLoan,         mavenWethLoans);
        closeMigrationLoanIfNeeded(orthogonalPoolV1,        orthogonalPoolManager,        orthogonalMigrationLoan,        orthogonalLoans);
        closeMigrationLoanIfNeeded(icebreakerPoolV1,        icebreakerPoolManager,        icebreakerMigrationLoan,        icebreakerLoans);
    }

    // Liquidity Migration Procedure #30
    function unlockV1Staking() internal {
        vm.startPrank(governor);
        IMapleGlobalsV1Like(mapleGlobalsV1).setPriceOracle(usdc, deactivationOracle);
        IMapleGlobalsV1Like(mapleGlobalsV1).setPriceOracle(weth, deactivationOracle);
        IMapleGlobalsV1Like(mapleGlobalsV1).setStakerCooldownPeriod(0);
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #31
    function unpauseV1Protocol() internal {
        vm.prank(globalAdmin);
        IMapleGlobalsV1Like(mapleGlobalsV1).setProtocolPause(false);
    }

    // Liquidity Migration Procedure #32
    function deactivatePoolV1(address poolV1) internal {
        vm.prank(IPoolV1Like(poolV1).poolDelegate());
        IPoolV1Like(poolV1).deactivate();
    }

    // Liquidity Migration Procedure #33
    function zeroLockupPeriod(address poolV1) internal {
        IStakeLockerLike stakeLocker = IStakeLockerLike(IPoolV1Like(poolV1).stakeLocker());

        vm.prank(IPoolV1Like(poolV1).poolDelegate());
        stakeLocker.setLockupPeriod(0);
    }

    // Liquidity Migration Procedure #34
    function requestUnstake(address poolV1) internal {
        IStakeLockerLike stakeLocker = IStakeLockerLike(IPoolV1Like(poolV1).stakeLocker());

        vm.prank(IPoolV1Like(poolV1).poolDelegate());
        stakeLocker.intendToUnstake();
    }

    // Liquidity Migration Procedure #35
    function exitRewards(address poolV1, address rewards) internal {
        address poolDelegate = IPoolV1Like(poolV1).poolDelegate();

        uint256 custodyAllowance =
            IStakeLockerLike(
                IPoolV1Like(poolV1).stakeLocker()
            ).custodyAllowance(poolDelegate, rewards);

        if (custodyAllowance == 0) return;

        vm.prank(poolDelegate);
        IMplRewardsLike(rewards).exit();
    }

    // Liquidity Migration Procedure #36
    function unstakeDelegateCover(address poolV1, uint256 delegateBalance) internal {
        address          poolDelegate = IPoolV1Like(poolV1).poolDelegate();
        IStakeLockerLike stakeLocker  = IStakeLockerLike(IPoolV1Like(poolV1).stakeLocker());

        IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

        uint256 initialStakeLockerBPTBalance   = bpt.balanceOf(address(stakeLocker));
        uint256 initialPoolDelegateBPTBalance  = bpt.balanceOf(poolDelegate);
        uint256 losses                         = stakeLocker.recognizableLossesOf(poolDelegate);
        uint256 balance                        = stakeLocker.balanceOf(poolDelegate);

        vm.prank(poolDelegate);
        stakeLocker.unstake(balance);

        uint256 endStakeLockerBPTBalance  = bpt.balanceOf(address(stakeLocker));
        uint256 endPoolDelegateBPTBalance = bpt.balanceOf(poolDelegate);

        assertEq(delegateBalance - losses, endPoolDelegateBPTBalance - initialPoolDelegateBPTBalance);
        assertEq(delegateBalance - losses, initialStakeLockerBPTBalance - endStakeLockerBPTBalance);
        assertEq(stakeLocker.balanceOf(poolDelegate), 0);  // All the delegate stake was withdrawn
    }

    // Liquidity Migration Procedures #32-#36
    function deactivateAndUnstake(address poolV1, address rewards, uint256 delegateBalance) internal {
        deactivatePoolV1(poolV1);  // Liquidity Migration Procedure #32
        zeroLockupPeriod(poolV1);  // Liquidity Migration Procedure #33

        uint256 balance =
            IStakeLockerLike(
                IPoolV1Like(poolV1).stakeLocker()
            ).balanceOf(
                IPoolV1Like(poolV1).poolDelegate()
            );

        // Assert that the provided balance matches the stake locker balance.
        assertEq(balance, delegateBalance);

        if (delegateBalance == 0) return;

        requestUnstake(poolV1);  // Liquidity Migration Procedure #34

        if (address(rewards) != address(0)) {
            exitRewards(poolV1, rewards);  // Liquidity Migration Procedure #35
        }

        unstakeDelegateCover(poolV1, delegateBalance);  // Liquidity Migration Procedure #36
    }

    // Liquidity Migration Procedures #32-#36
    function deactivateAndUnstakeAllPoolV1s() internal {
        deactivateAndUnstake(mavenWethPoolV1,         mavenWethRewards,         125_049.87499e18);
        deactivateAndUnstake(mavenUsdcPoolV1,         mavenUsdcRewards,         153.022e18);
        deactivateAndUnstake(mavenPermissionedPoolV1, mavenPermissionedRewards, 16.319926286804447168e18);
        deactivateAndUnstake(orthogonalPoolV1,        orthogonalRewards,        175.122243323160822654e18);
        deactivateAndUnstake(icebreakerPoolV1,        icebreakerRewards,        104.254119288711119987e18);
    }

    // Liquidity Migration Procedures #37
    function enableFinalPoolDelegates() internal {
        IMapleGlobalsV2Like mapleGlobalsV2 = IMapleGlobalsV2Like(mapleGlobalsV2Proxy);

        vm.startPrank(tempGovernor);

        mapleGlobalsV2.setValidPoolDelegate(mavenPermissionedFinalPd, true);
        mapleGlobalsV2.setValidPoolDelegate(mavenUsdcFinalPd,         true);
        mapleGlobalsV2.setValidPoolDelegate(mavenWethFinalPd,         true);
        mapleGlobalsV2.setValidPoolDelegate(orthogonalFinalPd,        true);
        mapleGlobalsV2.setValidPoolDelegate(icebreakerFinalPd,        true);

        vm.stopPrank();
    }

    // Liquidity Migration Procedures #38-#39
    function transferPoolDelegate(address poolManager, address newDelegate_) internal {
        setPendingPoolDelegate(poolManager, newDelegate_);  // Liquidity Migration Procedure #38
        acceptPoolDelegate(poolManager);                    // Liquidity Migration Procedure #39
    }

    // Liquidity Migration Procedures #38-#39
    function transferAllPoolDelegates() internal {
        transferPoolDelegate(mavenPermissionedPoolManager, mavenPermissionedFinalPd);
        transferPoolDelegate(mavenUsdcPoolManager,         mavenUsdcFinalPd);
        transferPoolDelegate(mavenWethPoolManager,         mavenWethFinalPd);
        transferPoolDelegate(orthogonalPoolManager,        orthogonalFinalPd);
        transferPoolDelegate(icebreakerPoolManager,        icebreakerFinalPd);
    }

    // Liquidity Migration Procedures #40
    function tempGovernorTransfersV2Governorship() internal {
        vm.prank(tempGovernor);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).setPendingGovernor(governor);
    }

    // Liquidity Migration Procedures #41
    function governorAcceptsV2Governorship() internal {
        vm.prank(governor);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).acceptGovernor();
    }

    // Liquidity Migration Procedure #42
    function setLoanDefault400() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(loanFactory).setDefaultVersion(400);
    }

    // Liquidity Migration Procedure #43
    function deployLoan401() internal {
        vm.prank(deployer);
        loanV401Implementation = address(new MapleLoanV401());
    }

    // Liquidity Migration Procedure #44
    function setupLoanFactoryFor401() internal {
        vm.startPrank(governor);
        IMapleProxyFactoryLike(loanFactory).registerImplementation(401, loanV401Implementation, loanV400Initializer);
        IMapleProxyFactoryLike(loanFactory).enableUpgradePath(400, 401, address(0));
        vm.stopPrank();
    }

    // Liquidity Migration Procedure #45
    function upgradeLoansToV401(address[] storage loans) internal {
        vm.startPrank(securityAdmin);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];
            IMapleLoanLike(loan).upgrade(401, "");
            assertVersion(401, loan);
        }

        vm.stopPrank();
    }

    // Liquidity Migration Procedure #45
    function upgradeAllLoansToV401() internal {
        upgradeLoansToV401(mavenPermissionedLoans);
        upgradeLoansToV401(mavenUsdcLoans);
        upgradeLoansToV401(mavenWethLoans);
        upgradeLoansToV401(orthogonalLoans);
        upgradeLoansToV401(icebreakerLoans);
    }

    // Liquidity Migration Procedure #46
    function finalizeFactories() internal {
        vm.startPrank(governor);

        IMapleProxyFactoryLike(loanFactory).setDefaultVersion(401);
        IMapleProxyFactoryLike(loanManagerFactory).setDefaultVersion(200);

        vm.stopPrank();
    }

    // Liquidity Migration Procedures #43-#46
    function finalizeProtocol() internal {
        deployLoan401();           // Liquidity Migration Procedure #43
        setupLoanFactoryFor401();  // Liquidity Migration Procedure #44
        upgradeAllLoansToV401();   // Liquidity Migration Procedure #45
        finalizeFactories();       // Liquidity Migration Procedure #46
    }

    // TODO: remove temporary PDs via setValidPoolDelegate on globalsV2


    /******************************************************************************************************************************/
    /*** Unsorted Forward Progression                                                                                           ***/
    /******************************************************************************************************************************/

    // NOTE: Temporary step until new accounting checker is deployed
    function deployNewAccountingChecker() internal {
        accountingChecker = address(new AccountingChecker(mapleGlobalsV2Proxy));
    }

    function increaseAllLiquidityCaps() internal {
        setLiquidityCap(mavenPermissionedPoolManager, 100_000_000e6);
        setLiquidityCap(mavenUsdcPoolManager,         100_000_000e6);
        setLiquidityCap(mavenWethPoolManager,         100_000e18);
        setLiquidityCap(orthogonalPoolManager,        100_000_000e6);
        setLiquidityCap(icebreakerPoolManager,        100_000_000e6);
    }

    function performAdditionalGlobalsSettings() internal {
        vm.startPrank(governor);

        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).setValidPoolAsset(wbtc, true);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).setValidCollateralAsset(usdc, true);

        vm.stopPrank();
    }

    function setCoverParameters(address poolManager, address poolV1, uint256 coverAmount) internal {
        // Configure the min cover amount in globals
        vm.startPrank(tempGovernor);

        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).setMinCoverAmount(poolManager, coverAmount);
        IMapleGlobalsV2Like(mapleGlobalsV2Proxy).setMaxCoverLiquidationPercent(poolManager, 0.5e6);

        vm.stopPrank();
    }

    function setAllCoverParameters() internal {
        setCoverParameters(mavenPermissionedPoolManager, mavenPermissionedPoolV1, 1_750_000e6);
        setCoverParameters(mavenUsdcPoolManager,         mavenUsdcPoolV1,         1_000_000e6);
        setCoverParameters(mavenWethPoolManager,         mavenWethPoolV1,         750e18);
        setCoverParameters(orthogonalPoolManager,        orthogonalPoolV1,        2_500_000e6);
        setCoverParameters(icebreakerPoolManager,        icebreakerPoolV1,        500_000e6);
    }


    /******************************************************************************************************************************/
    /*** V1 Helpers                                                                                                             ***/
    /******************************************************************************************************************************/

    function withdrawCover(address stakeLocker, address rewards, address[] storage coverProviders) internal {
        IStakeLockerLike stakeLocker_ = IStakeLockerLike(stakeLocker);
        IERC20Like bpt = IERC20Like(stakeLocker_.stakeAsset());

        // Due to the default on the Orthogonal Pool, some amount of dust will be left in the StakeLocker.
        uint256 acceptedDust = stakeLocker == orthogonalStakeLocker ? 0.003053321892584837e18 : 0;

        for (uint256 i; i < coverProviders.length; ++i) {
            // If User has allowance in the rewards contract, exit it.
            if (stakeLocker_.custodyAllowance(coverProviders[i], rewards) > 0) {
                vm.prank(coverProviders[i]);
                IMplRewardsLike(rewards).exit();
            }

            if (stakeLocker_.balanceOf(coverProviders[i]) > 0) {
                vm.prank(coverProviders[i]);
                stakeLocker_.intendToUnstake();

                // Perform the unstake
                uint256 initialStakeLockerBPTBalance = bpt.balanceOf(stakeLocker);
                uint256 initialProviderBPTBalance    = bpt.balanceOf(coverProviders[i]);

                // Due to losses on orthogonal pool, the last unstaker takes a slight loss
                if (coverProviders[i] == 0xF9107317B0fF77eD5b7ADea15e50514A3564002B) {
                    vm.prank(coverProviders[i]);
                    stakeLocker_.unstake(6029602120323463);

                    assertEq(stakeLocker_.balanceOf(coverProviders[i]), acceptedDust);
                    continue;
                } else {
                    uint256 balance = stakeLocker_.balanceOf(coverProviders[i]);

                    vm.prank(coverProviders[i]);
                    stakeLocker_.unstake(balance);
                }

                uint256 endStakeLockerBPTBalance = bpt.balanceOf(stakeLocker);
                uint256 endProviderBPTBalance    = bpt.balanceOf(coverProviders[i]);

                assertEq(endProviderBPTBalance - initialProviderBPTBalance, initialStakeLockerBPTBalance - endStakeLockerBPTBalance); // BPTs moved from stake locker to provider
                assertEq(stakeLocker_.balanceOf(coverProviders[i]), 0);
            }
        }

        // Not 0 for orthogonal, but 0 for the other pools.
        assertEq(stakeLocker_.totalSupply(), acceptedDust);
        assertWithinDiff(bpt.balanceOf(stakeLocker), acceptedDust, 19);  // This difference of 19 is what is makes the last provider not able to withdraw the entirety of his
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
        depositCover(mavenWethPoolManager,         750e18);
        depositCover(mavenUsdcPoolManager,         1_000_000e6);
        depositCover(mavenPermissionedPoolManager, 1_750_000e6);
        depositCover(orthogonalPoolManager,        2_500_000e6);
        depositCover(icebreakerPoolManager,        500_000e6);
    }

    function checkSumOfLoanPrincipal(address poolV1, address[] storage loans, uint256 allowedDiff) internal {
        uint256 totalPrincipal;
        for (uint256 i; i < loans.length; ++i) {
            totalPrincipal += IMapleLoanLike(loans[i]).principal();
        }

        assertWithinDiff(totalPrincipal, IPoolV1Like(poolV1).principalOut(), allowedDiff);
    }

    function checkSumOfLoanPrincipalForAllPools() internal {
        checkSumOfLoanPrincipal(mavenPermissionedPoolV1, mavenPermissionedLoans, 0);
        checkSumOfLoanPrincipal(mavenUsdcPoolV1,         mavenUsdcLoans,         2);
        checkSumOfLoanPrincipal(mavenWethPoolV1,         mavenWethLoans,         0);
        checkSumOfLoanPrincipal(orthogonalPoolV1,        orthogonalLoans,        0);
        checkSumOfLoanPrincipal(icebreakerPoolV1,        icebreakerLoans,        0);
    }


    /******************************************************************************************************************************/
    /*** Utility Functions                                                                                                      ***/
    /******************************************************************************************************************************/

    function assertLoansBelongToPool(address poolV1, address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(
                IDebtLockerLike(IMapleLoanLike(loans[i]).lender()).pool(),
                poolV1
            );
        }
    }

    function assertAllLoansBelongToRespectivePools() internal {
        assertLoansBelongToPool(mavenPermissionedPoolV1, mavenPermissionedLoans);
        assertLoansBelongToPool(mavenUsdcPoolV1,         mavenUsdcLoans);
        assertLoansBelongToPool(mavenWethPoolV1,         mavenWethLoans);
        assertLoansBelongToPool(orthogonalPoolV1,        orthogonalLoans);
        assertLoansBelongToPool(icebreakerPoolV1,        icebreakerLoans);
    }

    // TODO: This could be refactored to be a more useful function, taking in an expected difference as parameter for each variable.
    function assertPoolMatchesSnapshot(address poolV1) internal {
        PoolState storage poolState = poolStateSnapshot[poolV1];

        IPoolV1Like pool = IPoolV1Like(poolV1);

        IERC20Like poolAsset = IERC20Like(pool.liquidityAsset());

        assertEq(poolAsset.balanceOf(pool.liquidityLocker()), poolState.cash);
        assertEq(pool.interestSum(),                          poolState.interestSum);
        assertEq(pool.liquidityCap(),                         poolState.liquidityCap);
        assertEq(pool.poolLosses(),                           poolState.poolLosses);
        assertEq(pool.principalOut(),                         poolState.principalOut);
        assertEq(pool.totalSupply(),                          poolState.totalSupply);
    }

    function assertAllPoolsMatchSnapshot() internal {
        assertPoolMatchesSnapshot(mavenPermissionedPoolV1);
        assertPoolMatchesSnapshot(mavenUsdcPoolV1);
        assertPoolMatchesSnapshot(mavenWethPoolV1);
        assertPoolMatchesSnapshot(orthogonalPoolV1);
        assertPoolMatchesSnapshot(icebreakerPoolV1);
    }

    function assertPoolAccounting(address poolManager, address[] storage loans, uint256 hoursToWarp) internal {
        uint256 originalTime = block.timestamp;

        uint256 loansAddedTimestamp  = loansAddedTimestamps[poolManager];
        uint256 lastUpdatedTimestamp = lastUpdatedTimestamps[poolManager];

        for (uint256 i; i <= hoursToWarp; ++i) {
            (
                uint256 expectedTotalAssets,
                uint256 returnedTotalAssets,
                uint256 expectedDomainEnd_,
                uint256 actualDomainEnd_
            ) = AccountingChecker(accountingChecker).checkPoolAccounting(poolManager, loans, loansAddedTimestamp, lastUpdatedTimestamp);

            // console.log("hour", i);
            // console.log("block.timestamp", block.timestamp);
            // console.log("expectedTotalAssets", expectedTotalAssets);
            // console.log("returnedTotalAssets", returnedTotalAssets);
            // console.log("expectedDomainEnd_ ", expectedDomainEnd_);
            // console.log("actualDomainEnd_   ", actualDomainEnd_);

            assertWithinDiff(returnedTotalAssets, expectedTotalAssets, loans.length + 1);

            assertEq(actualDomainEnd_, expectedDomainEnd_);

            vm.warp(block.timestamp + 1 hours);
        }

        vm.warp(originalTime);
    }

    function assertPoolAccounting(address poolManager, address[] storage loans) internal {
        assertPoolAccounting(poolManager, loans, 2);
    }

    function assertAllPoolAccounting() internal {
        assertPoolAccounting(mavenPermissionedPoolManager, mavenPermissionedLoans);
        assertPoolAccounting(mavenUsdcPoolManager,         mavenUsdcLoans);
        assertPoolAccounting(mavenWethPoolManager,         mavenWethLoans);
        assertPoolAccounting(orthogonalPoolManager,        orthogonalLoans);
        assertPoolAccounting(icebreakerPoolManager,        icebreakerLoans);
    }

    function assertAllPoolAccounting(uint256 hoursToWarp) internal {
        accountingChecker = address(new AccountingChecker(mapleGlobalsV2Proxy));

        assertPoolAccounting(mavenPermissionedPoolManager, mavenPermissionedLoans, hoursToWarp);
        assertPoolAccounting(mavenUsdcPoolManager,         mavenUsdcLoans,         hoursToWarp);
        assertPoolAccounting(mavenWethPoolManager,         mavenWethLoans,         hoursToWarp);
        assertPoolAccounting(orthogonalPoolManager,        orthogonalLoans,        hoursToWarp);
        assertPoolAccounting(icebreakerPoolManager,        icebreakerLoans,        hoursToWarp);
    }

    function assertPrincipalOut(address loanManager, address[] storage loans) internal {
        uint256 totalPrincipal;
        for (uint256 i; i < loans.length; ++i) {
            totalPrincipal += IMapleLoanLike(loans[i]).principal();
        }

        assertEq(ILoanManagerLike(loanManager).principalOut(), totalPrincipal);
    }

    function assertAllPrincipalOuts() internal {
        assertPrincipalOut(IPoolManagerLike(mavenPermissionedPoolManager).loanManagerList(0), mavenPermissionedLoans);
        assertPrincipalOut(IPoolManagerLike(mavenUsdcPoolManager).loanManagerList(0),         mavenUsdcLoans);
        assertPrincipalOut(IPoolManagerLike(mavenWethPoolManager).loanManagerList(0),         mavenWethLoans);
        assertPrincipalOut(IPoolManagerLike(orthogonalPoolManager).loanManagerList(0),        orthogonalLoans);
        assertPrincipalOut(IPoolManagerLike(icebreakerPoolManager).loanManagerList(0),        icebreakerLoans);
    }

    function assertTotalSupply(address poolManager, address poolV1) internal {
        assertEq(
            IPoolV1Like(
                IPoolManagerLike(poolManager).pool()
            ).totalSupply(),
            getPoolV1TotalValue(poolV1)
        );
    }

    function assertAllTotalSupplies() internal {
        assertTotalSupply(mavenPermissionedPoolManager, mavenPermissionedPoolV1);
        assertTotalSupply(mavenUsdcPoolManager,         mavenUsdcPoolV1);
        assertTotalSupply(mavenWethPoolManager,         mavenWethPoolV1);
        assertTotalSupply(orthogonalPoolManager,        orthogonalPoolV1);
        assertTotalSupply(icebreakerPoolManager,        icebreakerPoolV1);
    }

    function assertVersion(uint256 version , address instance) internal {
        assertEq(
            IMapleProxiedLike(instance).implementation(),
            IMapleProxyFactoryLike(IMapleProxiedLike(instance).factory()).implementationOf(version),
            "Mismatched Versions"
        );
    }

    function calculateAvailableLiquidity(address poolV1) internal view returns (uint256 availableLiquidity) {
        availableLiquidity =
            IERC20Like(
                IPoolV1Like(poolV1).liquidityAsset()
            ).balanceOf(
                IPoolV1Like(poolV1).liquidityLocker()
            );
    }

    function checkUnaccountedAmount(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            // Since there's no public `getUnaccountedAmount()` function, we have to calculate it ourselves.
            IMapleLoanLike loan        = IMapleLoanLike(loans[i]);
            IERC20Like fundsAsset      = IERC20Like(loan.fundsAsset());
            IERC20Like collateralAsset = IERC20Like(loan.collateralAsset());

            assertEq(fundsAsset.balanceOf(address(loan)),      loan.claimableFunds() + loan.drawableFunds());
            assertEq(collateralAsset.balanceOf(address(loan)), loan.collateral());
        }
    }

    function compareLpPositions(address poolV1, address poolV2, address[] storage lps) internal {
        uint256 poolV1TotalValue  = getPoolV1TotalValue(poolV1);
        uint256 poolV2TotalSupply = IPoolV2Like(poolV2).totalSupply();
        uint256 sumPosition       = getSumPosition(poolV1, lps);

        for (uint256 i; i < lps.length; ++i) {
            uint256 v1Position = getV1Position(poolV1, lps[i]);
            uint256 v2Position = IPoolV2Like(poolV2).balanceOf(lps[i]);

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
        compareLpPositions(mavenWethPoolV1,         IPoolManagerLike(mavenWethPoolManager).pool(),         mavenWethLps);
        compareLpPositions(mavenUsdcPoolV1,         IPoolManagerLike(mavenUsdcPoolManager).pool(),         mavenUsdcLps);
        compareLpPositions(mavenPermissionedPoolV1, IPoolManagerLike(mavenPermissionedPoolManager).pool(), mavenPermissionedLps);
        compareLpPositions(orthogonalPoolV1,        IPoolManagerLike(orthogonalPoolManager).pool(),        orthogonalLps);
        compareLpPositions(icebreakerPoolV1,        IPoolManagerLike(icebreakerPoolManager).pool(),        icebreakerLps);
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

    function getNextLoan(address[] storage loans) internal view returns (address loan) {
        ( loan, ) = getNextLoanAndPaymentDueDate(loans);
    }

    function getNextLoanAndPaymentDueDate(address[] storage loans) internal view returns (address loan, uint256 nextPaymentDueDate) {
        for (uint256 i; i < loans.length; ++i) {
            uint256 dueDate = IMapleLoanLike(loans[i]).nextPaymentDueDate();

            if (!isEarlierThan(dueDate, nextPaymentDueDate)) continue;

            loan               = loans[i];
            nextPaymentDueDate = dueDate;
        }
    }

    function getPoolV1TotalValue(address poolV1) internal view returns (uint256 totalValue) {
        IPoolV1Like pool = IPoolV1Like(poolV1);

        IERC20Like asset = IERC20Like(pool.liquidityAsset());

        totalValue = pool.totalSupply() * 10 ** asset.decimals() / 1e18 + pool.interestSum() - pool.poolLosses();
    }

    function getSumPosition(address poolV1, address[] storage lps) internal view returns (uint256 positionValue) {
        for (uint256 i; i < lps.length; ++i) {
            positionValue += getV1Position(poolV1, lps[i]);
        }
    }

    function getV1Position(address poolV1, address lp) internal view returns (uint256 positionValue) {
        IPoolV1Like pool = IPoolV1Like(poolV1);

        IERC20Like asset = IERC20Like(pool.liquidityAsset());

        positionValue = pool.balanceOf(lp) * 10 ** asset.decimals() / 1e18 + pool.withdrawableFundsOf(lp) - pool.recognizableLossesOf(lp);
    }

    function handleCoverProviderEdgeCase() internal {
        // Handle weird scenario in maven usdc and orthogonal pool, where users have increased the allowance, but haven't actually staked.
        vm.prank(0x8476D9239fe38Ca683c6017B250112121cdB8D9B);
        IMplRewardsLike(orthogonalRewards).stake(701882135971108600);

        vm.prank(0xFe14c77979Ea159605b0fABDeB59B1166C3D95e3);
        IMplRewardsLike(mavenUsdcRewards).stake(299953726765028070);
    }

    function isEarlierThan(uint256 timestamp, uint256 threshold) internal pure returns (bool isEarlier) {
        if (timestamp == 0) return false;

        if (threshold == 0) return true;

        return timestamp < threshold;
    }

    function removeFromArray(address element, address[] storage array) internal {
        for (uint256 i; i < array.length;) {
            if (array[i] != element) {
                ++i;
                continue;
            }

            array[i] = array[array.length - 1];
            array.pop();
            return;
        }
    }

    function setGlobalsOfFactory(address factory, address globals) internal {
        IMapleProxyFactoryLike factory_ = IMapleProxyFactoryLike(factory);

        vm.prank(MapleGlobalsV2(factory_.mapleGlobals()).governor());
        factory_.setGlobals(globals);
    }

    function setPlatformFees(address poolManager_, uint256 managementFeeRate_, uint256 originationFeeRate_, uint256 serviceFeeRate_) internal {
        MapleGlobalsV2 globals = MapleGlobalsV2(mapleGlobalsV2Proxy);

        vm.startPrank(globals.governor());

        globals.setPlatformManagementFeeRate(poolManager_,  managementFeeRate_);
        globals.setPlatformOriginationFeeRate(poolManager_, originationFeeRate_);
        globals.setPlatformServiceFeeRate(poolManager_,     serviceFeeRate_);

        vm.stopPrank();
    }

    function snapshotPoolState(address poolV1) internal {
        IPoolV1Like pool     = IPoolV1Like(poolV1);
        IERC20Like poolAsset = IERC20Like(pool.liquidityAsset());

        poolStateSnapshot[poolV1] = PoolState({
            cash:         poolAsset.balanceOf(pool.liquidityLocker()),
            interestSum:  pool.interestSum(),
            liquidityCap: pool.liquidityCap(),
            poolLosses:   pool.poolLosses(),
            principalOut: pool.principalOut(),
            totalSupply:  pool.totalSupply()
        });
    }

    function snapshotAllPoolStates() internal {
        snapshotPoolState(mavenWethPoolV1);
        snapshotPoolState(mavenUsdcPoolV1);
        snapshotPoolState(mavenPermissionedPoolV1);
        snapshotPoolState(orthogonalPoolV1);
        snapshotPoolState(icebreakerPoolV1);
    }


    /******************************************************************************************************************************/
    /*** Contingency Helpers                                                                                                    ***/
    /******************************************************************************************************************************/

    // Rollback Liquidity Migration Procedure #4
    function enableLoanDowngradeFromV301() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(loanFactory).enableUpgradePath(301, 300, address(0));
    }

    // Rollback Liquidity Migration Procedure #4
    function disableLoanUpgradeFromV300() internal {
        IMapleProxyFactoryLike factory = IMapleProxyFactoryLike(loanFactory);

        vm.startPrank(governor);

        factory.disableUpgradePath(300, 301);
        factory.disableUpgradePath(301, 302);
        factory.disableUpgradePath(302, 400);
        factory.setDefaultVersion(300);

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #4
    function downgradeLoansFromV301(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            uint256 currentVersion = IMapleProxyFactoryLike(loanFactory).versionOf(loan.implementation());

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

    // Rollback Liquidity Migration Procedure #9.1 and #15
    function enableDebtLockerDowngradeFromV400() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(debtLockerFactory).enableUpgradePath(400, 300, address(0));
    }

    // Rollback Liquidity Migration Procedure #9.1
    function disableDebtLockerUpgradeFromV300() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(debtLockerFactory).disableUpgradePath(300, 400);
    }

    // Rollback Liquidity Migration Procedure #9.1
    function downgradeDebtLockersFromV400(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            address debtLocker = IMapleLoanLike(loans[i]).lender();
            IDebtLockerLike(debtLocker).upgrade(300, new bytes(0));
            assertVersion(300, debtLocker);
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #9.1
    function downgradeAllDebtLockersFromV400() internal {
        downgradeDebtLockersFromV400(mavenPermissionedLoans);
        downgradeDebtLockersFromV400(mavenUsdcLoans);
        downgradeDebtLockersFromV400(mavenWethLoans);
        downgradeDebtLockersFromV400(orthogonalLoans);
        downgradeDebtLockersFromV400(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #9.2
    function enableDebtLockerDowngradeFromV401() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(debtLockerFactory).enableUpgradePath(401, 400, address(0));
    }

    // Rollback Liquidity Migration Procedure #9.2
    function disableDebtLockerUpgradeFromV400() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(debtLockerFactory).disableUpgradePath(400, 401);
    }

    // Rollback Liquidity Migration Procedure #9.2
    function downgradeDebtLockersFromV401(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            address debtLocker = IMapleLoanLike(loans[i]).lender();
            IDebtLockerLike(debtLocker).upgrade(400, new bytes(0));
            assertVersion(400, debtLocker);
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #9.2
    function downgradeAllDebtLockersFromV401() internal {
        downgradeDebtLockersFromV401(mavenPermissionedLoans);
        downgradeDebtLockersFromV401(mavenUsdcLoans);
        downgradeDebtLockersFromV401(mavenWethLoans);
        downgradeDebtLockersFromV401(orthogonalLoans);
        downgradeDebtLockersFromV401(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #11 and #16
    function enableLoanDowngradeFromV302() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(loanFactory).enableUpgradePath(302, 301, address(0));
    }

    // Rollback Liquidity Migration Procedure #11
    function disableLoanUpgradesFromV301() internal {
        vm.startPrank(governor);
        IMapleProxyFactoryLike(loanFactory).disableUpgradePath(301, 302);
        IMapleProxyFactoryLike(loanFactory).disableUpgradePath(302, 400);
        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #11
    function downgradeLoansFromV302(address[] storage loans) internal {
        vm.startPrank(globalAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            uint256 currentVersion = IMapleProxyFactoryLike(loanFactory).versionOf(loan.implementation());

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
    function paybackMigrationLoanToPoolV1(address poolV1, address migrationLoan, address[] storage loans) internal {
        if (migrationLoan == address(0)) return;

        vm.prank(migrationMultisig);
        IMapleLoanLike(migrationLoan).closeLoan(0);

        removeFromArray(migrationLoan, loans);

        vm.prank(IPoolV1Like(poolV1).poolDelegate());
        IPoolV1Like(poolV1).claim(migrationLoan, debtLockerFactory);
    }

    // Rollback Liquidity Migration Procedure #14
    function paybackAllMigrationLoansToPoolV1s() internal {
        paybackMigrationLoanToPoolV1(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan, mavenPermissionedLoans);
        paybackMigrationLoanToPoolV1(mavenUsdcPoolV1,         mavenUsdcMigrationLoan,         mavenUsdcLoans);
        paybackMigrationLoanToPoolV1(mavenWethPoolV1,         mavenWethMigrationLoan,         mavenWethLoans);
        paybackMigrationLoanToPoolV1(orthogonalPoolV1,        orthogonalMigrationLoan,        orthogonalLoans);
        paybackMigrationLoanToPoolV1(icebreakerPoolV1,        icebreakerMigrationLoan,        icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #15
    function downgradeDebtLockerFromV400(address loan) internal {
        if (loan == address(0)) return;

        address debtLocker = IMapleLoanLike(loan).lender();

        vm.prank(globalAdmin);
        IDebtLockerLike(debtLocker).upgrade(300, new bytes(0));

        assertVersion(300, debtLocker);
    }

    // Rollback Liquidity Migration Procedure #15
    function downgradeAllMigrationLoanDebtLockersFromV400() internal {
        downgradeDebtLockerFromV400(mavenPermissionedMigrationLoan);
        downgradeDebtLockerFromV400(mavenUsdcMigrationLoan);
        downgradeDebtLockerFromV400(mavenWethMigrationLoan);
        downgradeDebtLockerFromV400(orthogonalMigrationLoan);
        downgradeDebtLockerFromV400(icebreakerMigrationLoan);
    }

    // Rollback Liquidity Migration Procedure #16
    function downgradeMigrationLoansFromV302(address loan) internal {
        if (loan == address(0)) return;

        uint256 currentVersion = IMapleProxyFactoryLike(loanFactory).versionOf(IMapleLoanLike(loan).implementation());

        if (currentVersion == 200 || currentVersion == 301) return;

        vm.prank(globalAdmin);
        IMapleLoanLike(loan).upgrade(301, new bytes(0));

        assertVersion(301, loan);
    }

    // Rollback Liquidity Migration Procedure #16
    function downgradeAllMigrationLoansFromV302() internal {
        downgradeMigrationLoansFromV302(mavenPermissionedMigrationLoan);
        downgradeMigrationLoansFromV302(mavenUsdcMigrationLoan);
        downgradeMigrationLoansFromV302(mavenWethMigrationLoan);
        downgradeMigrationLoansFromV302(orthogonalMigrationLoan);
        downgradeMigrationLoansFromV302(icebreakerMigrationLoan);
    }

    // Rollback Liquidity Migration Procedure #24
    function unsetPendingLenders(address[] storage loans) internal {
        vm.prank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).rollback_setPendingLenders(loans);
    }

    // Rollback Liquidity Migration Procedure #24
    function unsetPendingLendersForAllPools() internal {
        unsetPendingLenders(mavenPermissionedLoans);
        unsetPendingLenders(mavenUsdcLoans);
        unsetPendingLenders(mavenWethLoans);
        unsetPendingLenders(orthogonalLoans);
        unsetPendingLenders(icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #25
    function revertOwnershipOfLoans(address poolManager, address[] storage loans_) internal {
        address loanManager = IPoolManagerLike(poolManager).loanManagerList(0);

        vm.prank(migrationMultisig);
        IMigrationHelperLike(migrationHelperProxy).rollback_takeOwnershipOfLoans(loanManager, loans_);
    }

    // Rollback Liquidity Migration Procedure #25
    function revertOwnershipOfLoansForAllPools() internal {
        revertOwnershipOfLoans(mavenPermissionedPoolManager, mavenPermissionedLoans);
        revertOwnershipOfLoans(mavenUsdcPoolManager,         mavenUsdcLoans);
        revertOwnershipOfLoans(mavenWethPoolManager,         mavenWethLoans);
        revertOwnershipOfLoans(orthogonalPoolManager,        orthogonalLoans);
        revertOwnershipOfLoans(icebreakerPoolManager,        icebreakerLoans);
    }

    // Rollback Liquidity Migration Procedure #26
    function enableLoanManagerDowngradeFromV200() internal {
        vm.prank(tempGovernor);
        IMapleProxyFactoryLike(loanManagerFactory).enableUpgradePath(200, 100, address(0));
    }

    // Rollback Liquidity Migration Procedure #26
    function downgradeLoanManagerFromV200(address poolManager) internal {
        address loanManager = IPoolManagerLike(poolManager).loanManagerList(0);

        vm.prank(tempGovernor);
        IMapleProxiedLike(loanManager).upgrade(100, new bytes(0));

        assertVersion(100, loanManager);
    }

    // Rollback Liquidity Migration Procedure #26
    function downgradeAllLoanManagersFromV200() internal {
        downgradeLoanManagerFromV200(mavenPermissionedPoolManager);
        downgradeLoanManagerFromV200(mavenUsdcPoolManager);
        downgradeLoanManagerFromV200(mavenWethPoolManager);
        downgradeLoanManagerFromV200(orthogonalPoolManager);
        downgradeLoanManagerFromV200(icebreakerPoolManager);
    }

    // Rollback Liquidity Migration Procedure #27
    function setGlobalsOfLoanFactoryToV1() internal {
        setGlobalsOfFactory(loanFactory, mapleGlobalsV1);
    }

    // Rollback Liquidity Migration Procedure #27
    function enableLoanDowngradeFromV400() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(loanFactory).enableUpgradePath(400, 302, address(0));
    }

    // Rollback Liquidity Migration Procedure #27
    function disableLoanUpgradeFromV302() internal {
        vm.prank(governor);
        IMapleProxyFactoryLike(loanFactory).disableUpgradePath(302, 400);
    }

    // Rollback Liquidity Migration Procedure #27
    function downgradeLoansFromV400(address[] storage loans) internal {
        vm.startPrank(securityAdmin);

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            uint256 currentVersion = IMapleProxyFactoryLike(loanFactory).versionOf(loan.implementation());

            if (currentVersion == 200 || currentVersion == 300 || currentVersion == 301 || currentVersion == 302) continue;

            loan.upgrade(302, new bytes(0));

            assertVersion(302, address(loan));
        }

        vm.stopPrank();
    }

    // Rollback Liquidity Migration Procedure #27
    function downgradeAllLoansFromV400() internal {
        downgradeLoansFromV400(mavenPermissionedLoans);
        downgradeLoansFromV400(mavenUsdcLoans);
        downgradeLoansFromV400(mavenWethLoans);
        downgradeLoansFromV400(orthogonalLoans);
        downgradeLoansFromV400(icebreakerLoans);
    }

}
