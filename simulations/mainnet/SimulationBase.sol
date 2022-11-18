// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { DebtLocker as DebtLockerV4 } from "../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerV4Migrator }       from "../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { MapleGlobals }                           from "../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy as MapleGlobalsNTP } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MapleLoan as MapleLoanV400 }                     from "../../modules/loan-v400/contracts/MapleLoan.sol";
import { MapleLoanFeeManager }                            from "../../modules/loan-v400/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MapleLoanV4Initializer } from "../../modules/loan-v400/contracts/MapleLoanInitializer.sol";
import { MapleLoanV4Migrator }                            from "../../modules/loan-v400/contracts/MapleLoanV4Migrator.sol";

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

import {
    IDebtLockerLike,
    IERC20Like,
    ILoanManagerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleProxiedLike,
    IMplRewardsLike,
    IPoolLike,
    IPoolV2Like,
    IPoolManagerLike,
    IStakeLockerLike,
    ITransitionLoanManagerLike
} from "./Interfaces.sol";

contract SimulationBase is TestUtils, AddressRegistry {

    address migrationMultisig     = address(new Address());
    address securityAdminMultisig = address(new Address());

    AccountingChecker accountingChecker;
    MigrationHelper   migrationHelper;

    MapleGlobals        mapleGlobalsV2;
    MapleLoanFeeManager feeManager;
    PoolDeployer        poolDeployer;

    LoanManagerFactory       loanManagerFactory;
    PoolManagerFactory       poolManagerFactory;
    WithdrawalManagerFactory withdrawalManagerFactory;

    IPoolManagerLike mavenWethPoolManager;
    IPoolManagerLike mavenUsdcPoolManager;
    IPoolManagerLike mavenPermissionedPoolManager;
    IPoolManagerLike orthogonalPoolManager;
    IPoolManagerLike icebreakerPoolManager;

    mapping(address => IMapleLoanLike) public migrationLoans;
    mapping(address => address)        public temporaryPDs;
    mapping(address => address)        public finalPDs;
    mapping(address => uint256)        public loansAddedTimestamps;   // Timestamp when loans were added
    mapping(address => uint256)        public lastUpdatedTimestamps;  // Last timestamp that a LoanManager's accounting was updated
    mapping(address => address)        public loansOriginalLender;    // Store DebtLocker of loan for rollback

    mapping(address => PoolState) public snapshottedPoolState;

    struct PoolState {
        uint256 cash;
        uint256 interestSum;
        uint256 liquidityCap;
        uint256 poolLosses;
        uint256 principalOut;
        uint256 totalSupply;
    }

    /******************************************************************************************************************************/
    /*** Setup Functions                                                                                                        ***/
    /******************************************************************************************************************************/

    function deployProtocol() internal {
        createGlobals();

        feeManager = new MapleLoanFeeManager(address(mapleGlobalsV2));

        createFactories();
        setupFactories();
        createHelpers();
    }

    function setUpLoanV301() internal {
        vm.startPrank(governor);

        loanFactory.registerImplementation(301, address(new MapleLoanV301()), address(loanV3Initializer));
        loanFactory.enableUpgradePath(200, 301, address(0));
        loanFactory.enableUpgradePath(300, 301, address(0));

        vm.stopPrank();
    }

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
        poolDeployer   = new PoolDeployer(address(mapleGlobalsV2));

        vm.startPrank(governor);

        mapleGlobalsV2.setMapleTreasury(mapleTreasury);
        mapleGlobalsV2.setValidPoolDeployer(address(poolDeployer), true);

        mapleGlobalsV2.setValidPoolAsset(address(usdc), true);
        mapleGlobalsV2.setValidPoolAsset(address(wbtc), true);
        mapleGlobalsV2.setValidPoolAsset(address(weth), true);

        // Create the temporary and the final PDs

        mapleGlobalsV2.setValidPoolDelegate(
            temporaryPDs[address(mavenPermissionedPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            finalPDs[address(mavenPermissionedPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            temporaryPDs[address(mavenUsdcPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            finalPDs[address(mavenUsdcPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            temporaryPDs[address(mavenWethPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            finalPDs[address(mavenWethPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            temporaryPDs[address(orthogonalPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            finalPDs[address(orthogonalPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            temporaryPDs[address(icebreakerPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(
            finalPDs[address(icebreakerPoolV1)] = address(new Address()),
            true
        );

        mapleGlobalsV2.setValidPoolDelegate(mavenPermissionedPoolV1.poolDelegate(), true);
        mapleGlobalsV2.setValidPoolDelegate(mavenUsdcPoolV1.poolDelegate(),         true);
        mapleGlobalsV2.setValidPoolDelegate(mavenWethPoolV1.poolDelegate(),         true);
        mapleGlobalsV2.setValidPoolDelegate(orthogonalPoolV1.poolDelegate(),        true);
        mapleGlobalsV2.setValidPoolDelegate(icebreakerPoolV1.poolDelegate(),        true);

        // Set bootstrap mints for various assets
        mapleGlobalsV2.setBootstrapMint(address(usdc), 0.100000e6);
        mapleGlobalsV2.setBootstrapMint(address(wbtc), 0.00001000e8);
        mapleGlobalsV2.setBootstrapMint(address(weth), 0.000100000000000000e18);

        mapleGlobalsV2.setSecurityAdmin(securityAdminMultisig);

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

        address debtLockerV4Migrator = address(new DebtLockerV4Migrator());

        debtLockerFactory.registerImplementation(400, address(new DebtLockerV4()), debtLockerV3Initializer);
        debtLockerFactory.enableUpgradePath(200, 400, debtLockerV4Migrator);
        debtLockerFactory.enableUpgradePath(300, 400, debtLockerV4Migrator);

        address mapleLoanV4Initializer = address(new MapleLoanV4Initializer());

        loanFactory.registerImplementation(302, address(new MapleLoanV302()), loanV3Initializer);
        loanFactory.registerImplementation(400, address(new MapleLoanV400()), mapleLoanV4Initializer);
        loanFactory.registerImplementation(401, address(new MapleLoanV401()), mapleLoanV4Initializer);
        loanFactory.enableUpgradePath(301, 302, address(0));
        loanFactory.enableUpgradePath(302, 400, address(new MapleLoanV4Migrator()));
        loanFactory.enableUpgradePath(400, 401, address(0));
        loanFactory.setDefaultVersion(301);

        address loanManagerInitializer = address(new LoanManagerInitializer());

        loanManagerFactory.registerImplementation(100, address(new TransitionLoanManager()), loanManagerInitializer);
        loanManagerFactory.registerImplementation(200, address(new LoanManager()),           loanManagerInitializer);
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

    function payAndClaimUpcomingLoans(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan       = loans[i];
            IERC20Like     fundsAsset = IERC20Like(loan.fundsAsset());

            if (loan.nextPaymentDueDate() - block.timestamp < 5 days) {
                ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = loan.getNextPaymentBreakdown();

                uint256 paymentAmount = principal + interest + delegateFee + treasuryFee;

                uint256 mintSlot = address(fundsAsset) == address(usdc) ? 9 : 3;

                erc20_mint(address(fundsAsset), mintSlot, loan.borrower(), paymentAmount);

                vm.startPrank(loan.borrower());

                fundsAsset.approve(address(loan), paymentAmount);
                loan.makePayment(paymentAmount);

                vm.stopPrank();

                IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

                vm.startPrank(debtLocker.poolDelegate());

                IPoolLike(debtLocker.pool()).claim(address(loan), address(debtLockerFactory));

                vm.stopPrank();
            }
        }
    }

    function freezePoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        /*************************************************/
        /*** Step 1: Upgrade all DebtLockers to v4.0.0 ***/
        /*************************************************/

        upgradeDebtLockersToV4(poolV1, loans);  // 30min

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
            IMapleLoanLike migrationLoan = createMigrationLoan(poolV1, loans, availableLiquidity);  // 5min

            migrationLoans[address(poolV1)] = migrationLoan;

            // Upgrade the newly created debt locker of the migration loan.
            upgradeDebtLockerToV4(poolV1, migrationLoan);  // 5min

            // Upgrade migration loan to 302
            vm.prank(globalAdmin);
            migrationLoan.upgrade(302, new bytes(0));
        }
    }

    function deployAndMigratePoolUpToLoanManagerUpgrade(IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        /*******************************/
        /*** Step 4: Deploy new Pool ***/
        /*******************************/

        // Deploy the new version of the pool.
        poolManager = IPoolManagerLike(deployPoolV2(poolV1));  // 30min

        ITransitionLoanManagerLike transitionLoanManager = ITransitionLoanManagerLike(poolManager.loanManagerList(0));

        /***************************************************************/
        /*** Step 5: Add Loans to LM, setting up parallel accounting ***/
        /***************************************************************/

        address[] memory loanAddresses = convertToAddresses(loans);

        vm.prank(migrationMultisig);
        migrationHelper.addLoansToLoanManager(address(transitionLoanManager), loanAddresses);  // 2min (1hr of validation)

        uint256 loansAddedTimestamp = block.timestamp;

        lastUpdatedTimestamps[address(transitionLoanManager)] = loansAddedTimestamp;
        loansAddedTimestamps[address(transitionLoanManager)]  = loansAddedTimestamp;

        /**********************************************/
        /*** Step 6: Activate the Pool from Globals ***/
        /**********************************************/

        vm.prank(governor);
        mapleGlobalsV2.activatePoolManager(address(poolManager));  // 2min

        /*****************************************************************************/
        /*** Step 7: Open the Pool or allowlist the pool to allow airdrop to occur ***/
        /*****************************************************************************/

        open ? openPoolV2(poolManager) : allowLenders(poolManager, lps); // 5min

        /**********************************************************/
        /*** Step 8: Airdrop PoolV2 LP tokens to all PoolV1 LPs ***/
        /**********************************************************/

        // TODO: Add functionality to allowlist LPs in case of permissioned pool prior to airdrop.
        vm.startPrank(migrationMultisig);
        migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, lps.length * 2);  // 1 hour

        assertPoolAccounting(poolManager, loans);

        /*****************************************************************************/
        /*** Step 9: Set the pending lender in all outstanding Loans to be the TLM ***/
        /*****************************************************************************/

        migrationHelper.setPendingLenders(address(poolV1), address(poolManager), address(loanFactory), loanAddresses);

        assertPoolAccounting(poolManager, loans);

        /*********************************************************************************/
        /*** Step 10: Accept the pending lender in all outstanding Loans to be the TLM ***/
        /*********************************************************************************/

        migrationHelper.takeOwnershipOfLoans(address(transitionLoanManager), loanAddresses);

        assertPoolAccounting(poolManager, loans);

        vm.stopPrank();
    }

    function deployAndMigratePoolUpToLoanUpgrade(IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        poolManager = deployAndMigratePoolUpToLoanManagerUpgrade(poolV1, loans, lps, open);

        ITransitionLoanManagerLike transitionLoanManager = ITransitionLoanManagerLike(poolManager.loanManagerList(0));
        IPoolLike                  poolV2                = IPoolLike(poolManager.pool());

        /*****************************************************/
        /*** Step 11: Upgrade the LoanManager from the TLM ***/
        /*****************************************************/

        vm.prank(migrationMultisig);
        migrationHelper.upgradeLoanManager(address(transitionLoanManager), 200);

        assertEq(poolV2.totalSupply(), getPoolV1TotalValue(poolV1));

        // NOTE: transitionLoanManager is now a normal loanManager.
        assertPrincipalOut(transitionLoanManager, loans);  // TODO: Add assertions against PoolV1

        assertPoolAccounting(poolManager, loans);
    }

    function deployAndMigratePool(IPoolLike poolV1, IMapleLoanLike[] storage loans, address[] storage lps, bool open) internal returns (IPoolManagerLike poolManager) {
        poolManager = deployAndMigratePoolUpToLoanUpgrade(poolV1, loans, lps, open);

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
            lastUpdatedTimestamps[address(poolManager.loanManagerList(0))] = block.timestamp;
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

    function configureFactoriesForPoolUnfreeze() internal {
        vm.startPrank(governor);
        debtLockerFactory.enableUpgradePath(400, 300, address(0));
        loanFactory.enableUpgradePath(302, 301, address(0));
        vm.stopPrank();
    }

    function configureLoanFactoryFor400To302Downgrade() internal {
        vm.prank(governor);
        loanFactory.enableUpgradePath(400, 302, address(0));
    }

    function setLoanTransferAdmin(IPoolManagerLike poolManager) internal {
        vm.startPrank(poolManager.poolDelegate());

        LoanManager(poolManager.loanManagerList(0)).setLoanTransferAdmin(address(migrationHelper));

        vm.stopPrank();
    }

    function unfreezePoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans, uint256 liquidityCap) internal {
        configureFactoriesForPoolUnfreeze();

        downgradeLoans302To301(loans);

        downgradeDebtLockersTo300(poolV1, loans);

        paybackMigrationLoanToPoolV1(poolV1, loans);

        setLiquidityCap(poolV1, liquidityCap);
    }

    /******************************************************************************************************************************/
    /*** Utility Functions                                                                                                      ***/
    /******************************************************************************************************************************/

    function allowLenders(IPoolManagerLike poolManager, address[] memory lps) internal {
        vm.startPrank(poolManager.poolDelegate());
        for (uint256 i; i < lps.length; ++i) {
            poolManager.setAllowedLender(lps[i], true);
        }
        vm.stopPrank();
    }

    function assertDebtLockerVersion(uint256 version_ , IDebtLockerLike debtLocker_) internal {
        address implementation_ = debtLockerFactory.implementationOf(version_);

        assertEq(debtLocker_.implementation(),                              implementation_);
        assertEq(debtLockerFactory.versionOf(debtLocker_.implementation()), version_);
    }

    function assertFinalState() internal {
        // TODO: Add additional assertions here.
    }

    function assertInitialState() internal {
        // TODO: Add additional assertions here.
        assertTrue(debtLockerFactory.upgradeEnabledForPath(200, 400));
    }

    function assertLoanVersion(uint256 version_,  IMapleLoanLike loan_) internal {
        address implementation_ = loanFactory.implementationOf(version_);

        assertEq(loan_.implementation(),                        implementation_);
        assertEq(loanFactory.versionOf(loan_.implementation()), version_);
    }

    function assertLoansBelongToPool(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IDebtLockerLike(loans[i].lender()).pool(), address(poolV1));
        }
    }

    function assertPoolAccounting(IPoolManagerLike poolManager, IMapleLoanLike[] storage loans) internal {
        uint256 loansAddedTimestamp  = loansAddedTimestamps[poolManager.loanManagerList(0)];
        uint256 lastUpdatedTimestamp = lastUpdatedTimestamps[poolManager.loanManagerList(0)];

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
    function assertPoolMatchesSnapshotted(IPoolLike poolV1) internal {
        PoolState storage poolState = snapshottedPoolState[(address(poolV1))];

        IERC20Like poolAsset = IERC20Like(poolV1.liquidityAsset());

        assertEq(poolAsset.balanceOf(poolV1.liquidityLocker()), poolState.cash);
        assertEq(poolV1.interestSum(),                          poolState.interestSum);
        assertEq(poolV1.liquidityCap(),                         poolState.liquidityCap);
        assertEq(poolV1.poolLosses(),                           poolState.poolLosses);
        assertEq(poolV1.principalOut(),                         poolState.principalOut);
        assertEq(poolV1.totalSupply(),                          poolState.totalSupply);
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

    function compareLpPositions(IPoolLike poolV1, address poolV2, address[] storage lps) internal {
        uint256 poolV1TotalValue  = getPoolV1TotalValue(poolV1);
        uint256 poolV2TotalSupply = IPoolLike(poolV2).totalSupply();
        uint256 sumPosition       = getSumPosition(poolV1, lps);

        for (uint256 i; i < lps.length; ++i) {
            uint256 v1Position = getV1Position(poolV1, lps[i]);
            uint256 v2Position = IPoolLike(poolV2).balanceOf(lps[i]);

            if (i == 0) {
                v1Position += poolV1TotalValue - sumPosition;
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
            0,
            0.1e6,
            0,
            7 days,
            2 days,
            getPoolV1TotalValue(poolV1)
        ];

        vm.startPrank(temporaryPDs[address(poolV1)]);
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

    function depositCover(IPoolManagerLike poolManager, uint256 amount) internal {
        IERC20Like asset     = IERC20Like(poolManager.asset());
        address poolDelegate = poolManager.poolDelegate();

        erc20_mint(address(asset), poolDelegate, amount);

        vm.startPrank(poolDelegate);
        asset.approve(address(poolManager), amount);
        poolManager.depositCover(amount);
        vm.stopPrank();

        assertEq(IERC20Like(asset).balanceOf(poolManager.poolDelegateCover()), amount);
    }

    function downgradeDebtLockersTo300(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            vm.prank(mapleGlobalsV1.globalAdmin());
            debtLocker.upgrade(300, new bytes(0));
            assertDebtLockerVersion(300, debtLocker);
        }
    }

    function downgradeLoans400To302(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(securityAdminMultisig);
            loans[i].upgrade(302, new bytes(0));
            assertLoanVersion(302, loans[i]);
        }
    }

    function downgradeLoans302To301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(globalAdmin);
            loans[i].upgrade(301, new bytes(0));
            assertLoanVersion(301, loans[i]);
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
        vm.startPrank(poolDelegate);

        if (stakeLocker.custodyAllowance(poolDelegate, address(rewards)) > 0) {
            rewards.exit();
        }

        vm.stopPrank();
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

    function increaseLiquidityCap(IPoolManagerLike poolManager, uint256 newCap) internal {
        vm.prank(poolManager.poolDelegate());
        poolManager.setLiquidityCap(newCap);
    }

    function lockPoolV1Deposits(IPoolLike poolV1) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setLiquidityCap(0);

        assertEq(poolV1.liquidityCap(), 0);
    }

    function makeDeposit(IPoolManagerLike poolManager, uint256 amount) internal {
        // Create an LP
        address asset  = poolManager.asset();
        address lp     = address(new Address());
        address poolV2 = poolManager.pool();

        uint256 initialBalance = IERC20Like(asset).balanceOf(poolV2);

        // Get the asset
        erc20_mint(asset, lp, amount);

        if (!poolManager.openToPublic()) {
            vm.startPrank(poolManager.poolDelegate());
            poolManager.setAllowedLender(lp, true);
            vm.stopPrank();
        }

        vm.startPrank(lp);
        IERC20Like(asset).approve(address(poolV2), amount);
        uint256 shares = IPoolV2Like(poolV2).deposit(amount, lp);
        vm.stopPrank();

        assertEq(IERC20Like(asset).balanceOf(poolV2), initialBalance + amount);
        assertEq(IERC20Like(poolV2).balanceOf(lp),    shares);
    }

    function openPoolV2(IPoolManagerLike poolManager) internal {
        vm.prank(poolManager.poolDelegate());
        poolManager.setOpenToPublic();
    }

    function paybackMigrationLoanToPoolV1(IPoolLike poolV1, IMapleLoanLike[] storage loans) internal {
        IMapleLoanLike migrationLoan = migrationLoans[address(poolV1)];

        // Payback Migration loan
        if (address(migrationLoan) != address(0)) {
            vm.prank(migrationLoan.borrower());
            migrationLoan.closeLoan(0);
            loans.pop();

            vm.prank(poolV1.poolDelegate());
            poolV1.claim(address(migrationLoan), address(debtLockerFactory));
        }
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
            address loan_ = address(loans[i]);
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
        vm.prank(poolManager.poolDelegate());
        poolManager.setPendingPoolDelegate(newDelegate_);

        vm.prank(newDelegate_);
        poolManager.acceptPendingPoolDelegate();
    }

    function setLiquidityCap(IPoolLike poolV1, uint256 liquidityCap) internal {
        vm.prank(poolV1.poolDelegate());
        poolV1.setLiquidityCap(liquidityCap);  // NOTE: Need to pass in old liquidity cap
        assertEq(poolV1.liquidityCap(), liquidityCap);
    }

    function snapshotPoolState(IPoolLike poolV1) internal {
        IERC20Like poolAsset = IERC20Like(poolV1.liquidityAsset());

        snapshottedPoolState[address(poolV1)] = PoolState({
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
            address debtLocker = loans[i].lender();
            loansOriginalLender[address(loans[i])] = debtLocker;
        }
    }

    function unstakeDelegateCover(IStakeLockerLike stakeLocker, address poolDelegate, uint256 delegateBalance_) internal {
        IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

        uint256 initialStakeLockerBPTBalance   = bpt.balanceOf(address(stakeLocker));
        uint256 initialPoolDelegateBPTBalance  = bpt.balanceOf(address(poolDelegate));
        uint256 losses                         = stakeLocker.recognizableLossesOf(poolDelegate);

        vm.startPrank(poolDelegate);
        stakeLocker.unstake(stakeLocker.balanceOf(poolDelegate));
        vm.stopPrank();

        uint256 endStakeLockerBPTBalance  = bpt.balanceOf(address(stakeLocker));
        uint256 endPoolDelegateBPTBalance = bpt.balanceOf(address(poolDelegate));

        assertEq(delegateBalance_ - losses, endPoolDelegateBPTBalance - initialPoolDelegateBPTBalance);
        assertEq(delegateBalance_ - losses, initialStakeLockerBPTBalance - endStakeLockerBPTBalance);
        assertEq(stakeLocker.balanceOf(poolDelegate), 0);                                      // All the delegate stake was withdrawn

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

    function upgradeLoansToV400(IMapleLoanLike[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(globalAdmin);
            loans[i].upgrade(400, abi.encode(address(feeManager)));
        }

        // TODO: Assert all loans are upgraded.
    }

    function upgradeLoansToV401(IMapleLoanLike[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(securityAdminMultisig);
            loans[i].upgrade(401, "");
        }

        // TODO: Assert all loans are upgraded.
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
                    vm.startPrank(coverProviders[i]);
                    stakeLocker.unstake(stakeLocker.balanceOf(coverProviders[i]));
                    vm.stopPrank();
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

    /******************************************************************************************************************************/
    /*** Token Functions                                                                                                        ***/
    /******************************************************************************************************************************/

    function erc20_mint(address token, address account, uint256 amount) internal {
        uint256 mintSlot;

        require(token == address(usdc) || token == address(weth), "erc20_mint:INVALID_TOKEN");

        if (token == address(usdc)) mintSlot = 9;
        if (token == address(weth)) mintSlot = 3;

        erc20_mint(token, mintSlot, account, amount);
    }

}
