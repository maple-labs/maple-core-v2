// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { SimulationBase } from "./SimulationBase.sol";

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

contract LoanUpgradeTest is SimulationBase {

    struct Loan3Storage {
        address _borrower;         
        address _lender;           
        address _pendingBorrower;  
        address _pendingLender;    
        address _collateralAsset;  
        address _fundsAsset;      
        uint256 _gracePeriod;     
        uint256 _paymentInterval; 
        uint256 _interestRate;         
        uint256 _earlyFeeRate;         
        uint256 _lateFeeRate;         
        uint256 _lateInterestPremium; 
        uint256 _collateralRequired;  
        uint256 _principalRequested;  
        uint256 _endingPrincipal;    
        uint256 _drawableFunds;      
        uint256 _claimableFunds;      
        uint256 _collateral;         
        uint256 _nextPaymentDueDate;  
        uint256 _paymentsRemaining;  
        uint256 _principal;           
        bytes32 _refinanceCommitment;
        uint256 _refinanceInterest;
        uint256 _delegateFee;
        uint256 _treasuryFee;
    }

    mapping(address => Loan3Storage) internal loan3Storage;

    function test_loanUpgrade() external {
        payAndClaimUpcomingLoans(mavenWethLoans);
        payAndClaimUpcomingLoans(mavenUsdcLoans);
        payAndClaimUpcomingLoans(mavenPermissionedLoans);
        payAndClaimUpcomingLoans(orthogonalLoans);
        payAndClaimUpcomingLoans(icebreakerLoans);

        snapshotLoanState300(mavenWethLoans);
        snapshotLoanState300(mavenUsdcLoans);
        snapshotLoanState300(mavenPermissionedLoans);
        snapshotLoanState300(orthogonalLoans);
        snapshotLoanState300(icebreakerLoans);

        upgradeLoansToV301(mavenWethLoans);
        upgradeLoansToV301(mavenUsdcLoans);
        upgradeLoansToV301(mavenPermissionedLoans);
        upgradeLoansToV301(orthogonalLoans);
        upgradeLoansToV301(icebreakerLoans);

        assertAllLoans(mavenWethLoans,         301);
        assertAllLoans(mavenUsdcLoans,         301);
        assertAllLoans(mavenPermissionedLoans, 301);
        assertAllLoans(orthogonalLoans,        301);
        assertAllLoans(icebreakerLoans,        301);

        vm.startPrank(deployer);
        deployProtocol();
        vm.stopPrank();

        // Make the governor the tempGovernor
        vm.prank(tempGovernor);
        mapleGlobalsV2.acceptGovernor();
        vm.stopPrank();

        setupExistingFactories();
        performAdditionalGlobalsSettings();

        // Take the ownership of the migration helper
        vm.prank(migrationMultisig);
        migrationHelper.acceptOwner();

        freezeAllPoolV1s();      

        vm.prank(globalAdmin);
        mapleGlobalsV1.setProtocolPause(true);

        mavenWethPoolManager         = deployAndMigratePool(tempMavenWethPD,         mavenWethPoolV1,         mavenWethLoans,         mavenWethLps,         true);
        mavenUsdcPoolManager         = deployAndMigratePool(tempMavenUsdcPD,         mavenUsdcPoolV1,         mavenUsdcLoans,         mavenUsdcLps,         true);
        mavenPermissionedPoolManager = deployAndMigratePool(tempMavenPermissionedPD, mavenPermissionedPoolV1, mavenPermissionedLoans, mavenPermissionedLps, false);
        orthogonalPoolManager        = deployAndMigratePool(tempOrthogonalPD,        orthogonalPoolV1,        orthogonalLoans,        orthogonalLps,        true);
        icebreakerPoolManager        = deployAndMigratePool(tempIcebreakerPD,        icebreakerPoolV1,        icebreakerLoans,        icebreakerLps,        false);

        vm.prank(governor);
        loanFactory.setGlobals(address(mapleGlobalsV2)); 

        payBackCashLoan(address(mavenWethPoolV1),         mavenWethPoolManager,         mavenWethLoans);
        payBackCashLoan(address(mavenUsdcPoolV1),         mavenUsdcPoolManager,         mavenUsdcLoans);
        payBackCashLoan(address(mavenPermissionedPoolV1), mavenPermissionedPoolManager, mavenPermissionedLoans);
        payBackCashLoan(address(orthogonalPoolV1),        orthogonalPoolManager,        orthogonalLoans);
        payBackCashLoan(address(icebreakerPoolV1),        icebreakerPoolManager,        icebreakerLoans);

        assertAllLoans(mavenWethLoans,         400);
        assertAllLoans(mavenUsdcLoans,         400);
        assertAllLoans(mavenPermissionedLoans, 400);
        assertAllLoans(orthogonalLoans,        400);
        assertAllLoans(icebreakerLoans,        400);

        upgradeLoansToV401(mavenWethLoans);
        upgradeLoansToV401(mavenUsdcLoans);
        upgradeLoansToV401(mavenPermissionedLoans);
        upgradeLoansToV401(orthogonalLoans);
        upgradeLoansToV401(icebreakerLoans);

        assertAllLoans(mavenWethLoans,         401);
        assertAllLoans(mavenUsdcLoans,         401);
        assertAllLoans(mavenPermissionedLoans, 401);
        assertAllLoans(orthogonalLoans,        401);
        assertAllLoans(icebreakerLoans,        401);
    }

    function assertAllLoans(IMapleLoanLike[] memory loans, uint256 version) internal {
        for (uint256 i; i < loans.length; i++) {
            if (version == 301)                   assertLoanState301(loans[i]);
            if (version == 401 || version == 400) assertLoanState401(loans[i]);
        }
    }

    function assertLoanState301(IMapleLoanLike loan) internal {
        Loan3Storage storage snapshotedLoan = loan3Storage[address(loan)];

        assertEq(loan.borrower(),            snapshotedLoan._borrower);
        assertEq(loan.lender(),              snapshotedLoan._lender);
        assertEq(loan.pendingBorrower(),     snapshotedLoan._pendingBorrower);
        assertEq(loan.pendingLender(),       snapshotedLoan._pendingLender);
        assertEq(loan.collateralAsset(),     snapshotedLoan._collateralAsset);
        assertEq(loan.fundsAsset(),          snapshotedLoan._fundsAsset);
        assertEq(loan.gracePeriod(),         snapshotedLoan._gracePeriod);
        assertEq(loan.paymentInterval(),     snapshotedLoan._paymentInterval);
        assertEq(loan.interestRate(),        snapshotedLoan._interestRate);
        assertEq(loan.earlyFeeRate(),        snapshotedLoan._earlyFeeRate);
        assertEq(loan.lateFeeRate(),         snapshotedLoan._lateFeeRate);
        assertEq(loan.lateInterestPremium(), snapshotedLoan._lateInterestPremium);
        assertEq(loan.collateralRequired(),  snapshotedLoan._collateralRequired);
        assertEq(loan.principalRequested(),  snapshotedLoan._principalRequested);
        assertEq(loan.endingPrincipal(),     snapshotedLoan._endingPrincipal);
        assertEq(loan.drawableFunds(),       snapshotedLoan._drawableFunds);
        assertEq(loan.claimableFunds(),      snapshotedLoan._claimableFunds);
        assertEq(loan.collateral(),          snapshotedLoan._collateral);
        assertEq(loan.nextPaymentDueDate(),  snapshotedLoan._nextPaymentDueDate);
        assertEq(loan.paymentsRemaining(),   snapshotedLoan._paymentsRemaining);
        assertEq(loan.principal(),           snapshotedLoan._principal);
        assertEq(loan.refinanceCommitment(), snapshotedLoan._refinanceCommitment);
        assertEq(loan.delegateFee(),         snapshotedLoan._delegateFee);
        assertEq(loan.treasuryFee(),         snapshotedLoan._treasuryFee);
    }

    // The lender has changed in V4.01, and a few storage slots were deprecated.
    function assertLoanState401(IMapleLoanLike loan) internal {
        Loan3Storage storage snapshotedLoan = loan3Storage[address(loan)];

        assertEq(loan.borrower(),            snapshotedLoan._borrower);
        assertEq(loan.pendingBorrower(),     snapshotedLoan._pendingBorrower);
        assertEq(loan.pendingLender(),       snapshotedLoan._pendingLender);
        assertEq(loan.collateralAsset(),     snapshotedLoan._collateralAsset);
        assertEq(loan.fundsAsset(),          snapshotedLoan._fundsAsset);
        assertEq(loan.gracePeriod(),         snapshotedLoan._gracePeriod);
        assertEq(loan.paymentInterval(),     snapshotedLoan._paymentInterval);
        assertEq(loan.interestRate(),        snapshotedLoan._interestRate);
        assertEq(loan.lateFeeRate(),         snapshotedLoan._lateFeeRate);
        assertEq(loan.lateInterestPremium(), snapshotedLoan._lateInterestPremium);
        assertEq(loan.collateralRequired(),  snapshotedLoan._collateralRequired);
        assertEq(loan.principalRequested(),  snapshotedLoan._principalRequested);
        assertEq(loan.endingPrincipal(),     snapshotedLoan._endingPrincipal);
        assertEq(loan.drawableFunds(),       snapshotedLoan._drawableFunds);
        assertEq(loan.collateral(),          snapshotedLoan._collateral);
        assertEq(loan.nextPaymentDueDate(),  snapshotedLoan._nextPaymentDueDate);
        assertEq(loan.paymentsRemaining(),   snapshotedLoan._paymentsRemaining);
        assertEq(loan.principal(),           snapshotedLoan._principal);
        assertEq(loan.refinanceCommitment(), snapshotedLoan._refinanceCommitment);

        // V4 specific assertion
        assertEq(loan.feeManager(), address(feeManager));
    }

    function snapshotLoanState300(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IMapleLoanLike loan = loans[i];

            // Not possible to initialize at once due to stack limit.
            loan3Storage[address(loan)]._borrower            = loan.borrower();
            loan3Storage[address(loan)]._lender              = loan.lender();
            loan3Storage[address(loan)]._pendingBorrower     = loan.pendingBorrower();
            loan3Storage[address(loan)]._pendingLender       = loan.pendingLender();
            loan3Storage[address(loan)]._collateralAsset     = loan.collateralAsset();
            loan3Storage[address(loan)]._fundsAsset          = loan.fundsAsset();
            loan3Storage[address(loan)]._gracePeriod         = loan.gracePeriod();
            loan3Storage[address(loan)]._paymentInterval     = loan.paymentInterval();
            loan3Storage[address(loan)]._interestRate        = loan.interestRate();
            loan3Storage[address(loan)]._earlyFeeRate        = loan.earlyFeeRate();
            loan3Storage[address(loan)]._lateFeeRate         = loan.lateFeeRate();
            loan3Storage[address(loan)]._lateInterestPremium = loan.lateInterestPremium();
            loan3Storage[address(loan)]._collateralRequired  = loan.collateralRequired();
            loan3Storage[address(loan)]._principalRequested  = loan.principalRequested();
            loan3Storage[address(loan)]._endingPrincipal     = loan.endingPrincipal();
            loan3Storage[address(loan)]._drawableFunds       = loan.drawableFunds();
            loan3Storage[address(loan)]._claimableFunds      = loan.claimableFunds();
            loan3Storage[address(loan)]._collateral          = loan.collateral();
            loan3Storage[address(loan)]._nextPaymentDueDate  = loan.nextPaymentDueDate();
            loan3Storage[address(loan)]._paymentsRemaining   = loan.paymentsRemaining();
            loan3Storage[address(loan)]._principal           = loan.principal();
            loan3Storage[address(loan)]._refinanceCommitment = loan.refinanceCommitment();
            loan3Storage[address(loan)]._delegateFee         = loan.delegateFee();
            loan3Storage[address(loan)]._treasuryFee         = loan.treasuryFee();
        }
    } 

}
