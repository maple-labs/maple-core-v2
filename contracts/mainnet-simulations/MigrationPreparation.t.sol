// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IDebtLockerLike,
    IERC20Like,
    ILoanManagerLike,
    IMapleLoanLike,
    IMapleProxiedLike,
    IPoolManagerLike,
    IPoolV1Like,
    IPoolV2Like
} from "./Interfaces.sol";

import { LifecycleBase } from "./LifecycleBase.sol";

contract MigrationPreparationTest is LifecycleBase {

    // Maven Permissioned loans to
    address constant mavenPermissionedLoan1 = 0x500055809685ecebA5eC55786f65440583954501;
    address constant mavenPermissionedLoan2 = 0xa83b134809183c634A692D5b5F457b78Cd6913e6;

    // Maven USDC loans
    address constant mavenUsdcLoan1 = 0x245De7E3B9B21B68c2C8D2e4759652F0dbCE65A6;
    address constant mavenUsdcLoan2 = 0x502EE6D0b16d834547Fc44344D4BE3E019Fc2573;
    address constant mavenUsdcLoan3 = 0x726893373DE92b8272298D76a7D60a5F51b90dA9;
    address constant mavenUsdcLoan4 = 0xF6950F28353cA676100C2a92DD360DEa16A213cE;
    address constant mavenUsdcLoan5 = 0xa58fD39138083783689d700758D00873538C6C2A;
    address constant mavenUsdcLoan6 = 0xd027CdD569b6cd1aD13dc82d42d0CD7cDeda3521;

    // Maven WETH loans
    address constant mavenWethLoan1  = 0x0104AE451AD2542aC9250Ebe4a37D0717FdfC60C;
    address constant mavenWethLoan2  = 0x91A4eEe4D33d9cd7840CAe21A4f408c0919F555D;
    address constant mavenWethLoan3  = 0xC8c17328796F472A97B7784cc5F52b802A89deC1;
    address constant mavenWethLoan4  = 0x4DbE67c683A731807EAAa99A1DF2D3E79ebECA00;
    address constant mavenWethLoan5  = 0xFcF8725d0D9A786448c5B9b9cc67226d7e4d5c3D;
    address constant mavenWethLoan6  = 0x64982f1aA56340C0051bDCeFb7a69911Fd9D141d;
    address constant mavenWethLoan7  = 0x2cB5c20309B2DbfDda758237f20c94b5F72d0331;
    address constant mavenWethLoan8  = 0x40d9fBe05d8F9f1215D5a6d01994ad1a6a097616;
    address constant mavenWethLoan9  = 0x2872C1140117a5DE85E0DD06Ed1B439D23707AD1;
    address constant mavenWethLoan10 = 0xdeF9146F12e22e5c69Fb7b7D181534240c04FdCE;

    // Orthogonal loans
    address constant orthogonalLoan1 = 0x249B5907564f0Cf3Fb771b013A6f9f33e1225657;

    // 1: Prepare loans (claim / refinance)
    // 2: Perform full migration
    // 3: Impair all loans / make a few payments
    // 4: Lifecycle simulation with payments and no exits
    // 5: Default loans
    // 6: Transfer cash into the pool as "compensation"

    function test_migrationPreparation() external {
        // Pre-Deployment Requirements
        if (block.number < 16140823) setPoolAdminsToMigrationMultisig();  // LMP #1 [16140823-16150331]
        if (block.number < 16144511) zeroInvestorFeeAndTreasuryFee();     // LMP #2 [16144511]

        // Must be done before `upgradeAllLoansToV302`
        if (block.number < 16158728) {
            payAndClaimAllUpcomingLoans();       // LMP #3 [Idempotent]
            upgradeAllLoansToV301();             // LMP #4 [Idempotent]
        }

        if (block.number < 16126985) deployProtocol();  // LMP #5 [16126985-16127073]

        if (block.number < 16136610) tempGovernorAcceptsV2Governorship();                   // LMP #6 [16136610]
        if (block.number < 16136630) migrationMultisigAcceptsMigrationAdministratorship();  // LMP #7 [16136630]

        // Pre-Kickoff
        if (block.number < 16144529) setupExistingFactories();                   // LMP #8.1 [16144529]
        if (block.number < 16151161) deploy401DebtLockerAndAccountingChecker();  // LMP #8.2 [16151161-16151166]
        if (block.number < 16155441) setUpDebtLockerFactoryFor401();             // LMP #8.3 [16155441]
        if (block.number < 16156502) upgradeAllDebtLockersToV400();              // LMP #9.1 [16156502]
        if (block.number < 16158685) upgradeAllDebtLockersToV401();              // LMP #9.2 [16158685]

        // Must be done before `upgradeAllLoansToV302`
        if (block.number < 16158728) {
            claimAllLoans();  // LMP #10  [Idempotent]
            checkSumOfLoanPrincipalForAllPools();
        }

        // Kickoff
        if (block.number < 16158728) upgradeAllLoansToV302();    // LMP #11 [16158728]
        if (block.number < 16158757) lockAllPoolV1Deposits();    // LMP #12 [16158757]
        if (block.number < 16161265) createAllMigrationLoans();  // LMP #13 [16161265]

        if (block.number < 16161360) {
            checkSumOfLoanPrincipalForAllPools();
            fundMigrationLoansAndUpgradeDebtLockers();  // LMP #15 [16161360-16161660]
        }

        if (block.number < 16161726) upgradeAllMigrationLoansToV302();  // LMP #16 [16161726]

        if (block.number < 16161749) pauseV1Protocol();  // LMP #17 [16161749]

        if (block.number < 16162315) deployAllPoolV2s();  // LMP #18 [16162315-16162589]
        if (block.number < 16162671) setFees();           // LMP #19 [16162671]

        if (block.number < 16163591) {
            checkSumOfLoanPrincipalForAllPools();
            addLoansToAllLoanManagers();  // LMP #20 [16163591]
        }

        // Prepare for Airdrops
        if (block.number < 16163643) activateAllPoolManagers();  // LMP #21 [16163643]
        if (block.number < 16163671) openOrAllowOnAllPoolV2s();  // LMP #22 [16163671-16163755]

        if (block.number < 16164408) {
            airdropTokensForAllPools();  // LMP #23 [16164408-16164504]
            assertAllPoolAccounting();
        }

        uint256[][5] memory poolV2Positions1 = getAllPoolV2Positions();

        // Transfer Loans
        if (block.number < 16164579) setAllPendingLenders();      // LMP #24 [16164579]

        if (block.number < 16164620) {
            assertAllPoolAccounting();
            takeAllOwnershipsOfLoans();  // LMP #25 [16164620]
        }

        if (block.number < 16164645) {
            assertAllPoolAccounting();
            upgradeAllLoanManagers();    // LMP #26 [16164645]
        }

        if (block.number < 16164765) {
            assertAllPrincipalOuts();
            assertAllTotalSupplies();
            assertAllPoolAccounting();
            upgradeAllLoansToV400();    // LMP #27 [16164765]
            compareAllLpPositions();
        }

        // Close Migration Loans
        if (block.number < 16164798) setGlobalsOfLoanFactoryToV2();  // LMP #28 [16164798]
        if (block.number < 16164991) closeAllMigrationLoans();       // LMP #29 [16164991]

        // Prepare PoolV1 Deactivation
        if (block.number < 16169377) unlockV1Staking();    // LMP #30 [16169377]
        if (block.number < 16170052) unpauseV1Protocol();  // LMP #31 [16170052]

        if (block.number < 16170102) finalizeFactories();  // LMP #32 [16170102]

        if (block.number < 16170144) deactivateAndUnstakeAllPoolV1s();  // LMPs #33-#37 [16170144-16172136]

        if (block.number < 16172812) enableFinalPoolDelegates();  // LMP #38 [16172812]

        if (block.number < 16172867) setAllPendingPoolDelegates();  // LMPs #39 [16172867-16172924]
        if (block.number < 16176259) acceptAllPoolDelegates();      // LMPs #40 [16176259-TBD]

        setAllMinCoverAmounts();  // Not done yet

        // Transfer Governorship of GlobalsV2
        tempGovernorTransfersV2Governorship();  // LMPs #41 [TBD]
        governorAcceptsV2Governorship();        // LMPs #42 [TBD]

        handleCoverProviderEdgeCase();
        withdrawAllCovers();

        // PoolV2 Lifecycle start
        depositAllCovers();
        increaseAllLiquidityCaps();

        uint256[][5] memory poolV2Positions2 = getAllPoolV2Positions();

        impairDefaultingLoans();

        uint256[][5] memory poolV2Positions3 = getAllPoolV2Positions();

        vm.warp(block.timestamp + 1 weeks);

        uint256[][5] memory poolV2Positions4 = getAllPoolV2Positions();

        vm.warp(block.timestamp + 1 weeks);

        uint256[][5] memory poolV2Positions5 = getAllPoolV2Positions();

        triggerDefaultOnAllImpairedLoans();

        uint256[][5] memory poolV2Positions6 = getAllPoolV2Positions();

        propUpAllPoolsWithCash();

        uint256[][5] memory poolV2Positions7 = getAllPoolV2Positions();

        payOffAllLoanWhenDue();

        uint256[][5] memory poolV2Positions8 = getAllPoolV2Positions();

        uint256[][5] memory redeemedAmounts = exitFromAllPoolsWhenPossible();

        withdrawAllPoolCoverFromAllPools();

        writeAllLPData(
            "./output/migration-preparation",
            redeemedAmounts,
            poolV2Positions1,
            poolV2Positions2,
            poolV2Positions3,
            poolV2Positions4,
            poolV2Positions5,
            poolV2Positions6,
            poolV2Positions7,
            poolV2Positions8
        );
    }

    /******************************************************************************************************************************/
    /*** Helper Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function payLoan(address loan) internal {
        address asset    = IMapleLoanLike(loan).fundsAsset();
        address borrower = IMapleLoanLike(loan).borrower();

        ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = IMapleLoanLike(loan).getNextPaymentBreakdown();

        uint256 payment  = principal + interest + delegateFee + treasuryFee;

        erc20_mint(asset, borrower, payment);

        vm.startPrank(borrower);
        IERC20Like(asset).approve(loan, payment);
        IMapleLoanLike(loan).makePayment(payment);
        vm.stopPrank();
    }

    function payAllHealthyLoans() internal {
        payLoan(mavenPermissionedLoan2);
    }

    function assertNotClaimable(address loan) internal {
        assertEq(IMapleLoanLike(loan).claimableFunds(), 0);
    }

    function assertNoClaimableLoans() internal {
        assertNotClaimable(mavenPermissionedLoan1);
        assertNotClaimable(mavenPermissionedLoan1);

        assertNotClaimable(mavenUsdcLoan1);
        assertNotClaimable(mavenUsdcLoan2);
        assertNotClaimable(mavenUsdcLoan3);
        assertNotClaimable(mavenUsdcLoan4);
        assertNotClaimable(mavenUsdcLoan5);
        assertNotClaimable(mavenUsdcLoan6);

        assertNotClaimable(mavenWethLoan1);
        assertNotClaimable(mavenWethLoan2);
        assertNotClaimable(mavenWethLoan3);
        assertNotClaimable(mavenWethLoan4);
        assertNotClaimable(mavenWethLoan5);
        assertNotClaimable(mavenWethLoan6);
        assertNotClaimable(mavenWethLoan7);
        assertNotClaimable(mavenWethLoan8);
        assertNotClaimable(mavenWethLoan9);
        assertNotClaimable(mavenWethLoan10);

        assertNotClaimable(orthogonalLoan1);
    }

    function refinanceLoan(address poolV1, address loan) internal {
        address borrower     = IMapleLoanLike(loan).borrower();
        address debtLocker   = IMapleLoanLike(loan).lender();
        address poolDelegate = IPoolV1Like(poolV1).poolDelegate();

        bytes[] memory calls = new bytes[](4);

        calls[0] = abi.encodeWithSignature("setGracePeriod(uint256)",         0 seconds);
        calls[3] = abi.encodeWithSignature("setLateInterestPremium(uint256)", 0.05e18);
        calls[1] = abi.encodeWithSignature("setPaymentInterval(uint256)",     30 days);
        calls[2] = abi.encodeWithSignature("setPaymentsRemaining(uint256)",   1);

        vm.prank(borrower);
        IMapleLoanLike(loan).proposeNewTerms(refinancer, type(uint256).max, calls);

        vm.prank(poolDelegate);
        IDebtLockerLike(debtLocker).acceptNewTerms(refinancer, type(uint256).max, calls, 0);

        assertEq(IMapleLoanLike(loan).gracePeriod(),         0 seconds);
        assertEq(IMapleLoanLike(loan).lateInterestPremium(), 0.05e18);
        assertEq(IMapleLoanLike(loan).paymentInterval(),     30 days);
        assertEq(IMapleLoanLike(loan).paymentsRemaining(),   1);
        assertEq(IMapleLoanLike(loan).nextPaymentDueDate(),  block.timestamp + 30 days);
    }

    function refinanceAllUnhealthyLateLoans() internal {
        refinanceLoan(mavenPermissionedPoolV1, mavenPermissionedLoan1);

        refinanceLoan(mavenUsdcPoolV1, mavenUsdcLoan1);
        refinanceLoan(mavenUsdcPoolV1, mavenUsdcLoan3);

        refinanceLoan(mavenWethPoolV1, mavenWethLoan1);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan2);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan5);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan6);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan7);
    }

    function prepareAllLoans() internal {
        claimAllLoans();
        assertNoClaimableLoans();
        refinanceAllUnhealthyLateLoans();
    }

    function impairDefaultingLoans() internal {
        impairLoan(mavenUsdcPoolManager, mavenUsdcLoan1);
        impairLoan(mavenUsdcPoolManager, mavenUsdcLoan2);
        impairLoan(mavenUsdcPoolManager, mavenUsdcLoan3);
        impairLoan(mavenUsdcPoolManager, mavenUsdcLoan4);

        impairLoan(mavenWethPoolManager, mavenWethLoan1);
        impairLoan(mavenWethPoolManager, mavenWethLoan2);
        impairLoan(mavenWethPoolManager, mavenWethLoan3);
        impairLoan(mavenWethPoolManager, mavenWethLoan4);
    }

    function triggerDefaultAndRemoveLoan(address poolManager, address loan, address liquidatorFactory, address[] storage loans) internal {
        triggerDefault(poolManager, loan, liquidatorFactory);
        removeFromArray(loan, loans);
    }

    function triggerDefaultOnAllImpairedLoans() internal {
        triggerDefaultAndRemoveLoan(mavenUsdcPoolManager, mavenUsdcLoan1, liquidatorFactory, mavenUsdcLoans);
        triggerDefaultAndRemoveLoan(mavenUsdcPoolManager, mavenUsdcLoan2, liquidatorFactory, mavenUsdcLoans);
        triggerDefaultAndRemoveLoan(mavenUsdcPoolManager, mavenUsdcLoan3, liquidatorFactory, mavenUsdcLoans);
        triggerDefaultAndRemoveLoan(mavenUsdcPoolManager, mavenUsdcLoan4, liquidatorFactory, mavenUsdcLoans);

        triggerDefaultAndRemoveLoan(mavenWethPoolManager, mavenWethLoan1, liquidatorFactory, mavenWethLoans);
        triggerDefaultAndRemoveLoan(mavenWethPoolManager, mavenWethLoan2, liquidatorFactory, mavenWethLoans);
        triggerDefaultAndRemoveLoan(mavenWethPoolManager, mavenWethLoan3, liquidatorFactory, mavenWethLoans);
        triggerDefaultAndRemoveLoan(mavenWethPoolManager, mavenWethLoan4, liquidatorFactory, mavenWethLoans);
    }

    function propUpWithCash(address poolV2, uint256 amount) internal {
        erc20_mint(IPoolV2Like(poolV2).asset(), poolV2, amount);
    }

    function propUpAllPoolsWithCash() internal {
        propUpWithCash(mavenPermissionedPoolV2, 0);
        propUpWithCash(mavenUsdcPoolV2,         1_000_000e6);
        propUpWithCash(mavenWethPoolV2,         1_000e18);
        propUpWithCash(orthogonalPoolV2,        0);
        propUpWithCash(icebreakerPoolV2,        0);
    }

}
