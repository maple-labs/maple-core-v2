// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

import { LifecycleBase } from "./LifecycleBase.sol";

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
        // setPoolAdminsToMigrationMultisig();  // LMP #1
        // zeroInvestorFeeAndTreasuryFee();     // LMP #2
        // prepareAllLoans();                   // LMP #3 (payAndClaimAllUpcomingLoans)
        // upgradeAllLoansToV301();             // LMP #4

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

        // int256[][5] memory balances = getStartingFundsAssetBalances();

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

        setFees();  // LMP #19

        setAllPoolsFees();

        addLoansToAllLoanManagers();  // LMP #20

        // Prepare for Airdrops
        activateAllPoolManagers();  // LMP #21
        openOrAllowOnAllPoolV2s();  // LMP #22

        airdropTokensForAllPools();  // LMP #23
        assertAllPoolAccounting();

        uint256[][5] memory poolV2Positions1 = getAllPoolV2Positions();

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

        enableFinalPoolDelegates();  // LMP #37

        transferAllPoolDelegates();  // LMPs #38-#39

        // Transfer Governorship of GlobalsV2
        tempGovernorTransfersV2Governorship();  // LMPs #40
        governorAcceptsV2Governorship();        // LMPs #41

        setLoanDefault400();  // LMPs #42

        finalizeProtocol();  // LMPs #43-#46

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

        console.log("balance of Treasury", IERC20Like(usdc).balanceOf(mapleTreasury));

        triggerDefaultOnAllImpairedLoans();

        console.log("balance of Treasury", IERC20Like(usdc).balanceOf(mapleTreasury));

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

    function setAllPoolsFees() internal {
        setPlatformFees(mavenPermissionedPoolManager, 0.01e6, 0.001e6, 0.001e6);
        setPlatformFees(mavenUsdcPoolManager,         0.01e6, 0.001e6, 0.001e6);
        setPlatformFees(mavenWethPoolManager,         0.01e6, 0.001e6, 0.001e6);
        setPlatformFees(orthogonalPoolManager,        0.01e6, 0.001e6, 0.001e6);
        setPlatformFees(icebreakerPoolManager,        0.01e6, 0.001e6, 0.001e6);
    }

}
