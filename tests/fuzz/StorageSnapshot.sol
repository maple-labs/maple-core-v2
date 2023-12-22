// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IOpenTermLoanManagerStructs,
    IPool,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

contract StorageSnapshot {

    struct OpenTermLoanManagerStorage {
        uint40  previousDomainStart;
        uint112 previousAccountedInterest;
        uint256 previousAccruedInterest;
        uint128 previousPrincipalOut;
        uint128 previousUnrealizedLosses;
        uint256 previousIssuanceRate;
    }

    struct OpenTermLoanStorage {
        address previousFundsAsset;
        address previousBorrower;
        address previousLender;
        address previousPendingBorrower;
        address previousPendingLender;
        bytes32 previousRefinanceCommitment;
        uint32  previousGracePeriod;
        uint32  previousNoticePeriod;
        uint32  previousPaymentInterval;
        uint40  previousDateCalled;
        uint40  previousDateFunded;
        uint40  previousDateImpaired;
        uint40  previousDatePaid;
        uint256 previousCalledPrincipal;
        uint256 previousPrincipal;
        uint64  previousDelegateServiceFeeRate;
        uint64  previousInterestRate;
        uint64  previousLateFeeRate;
        uint64  previousLateInterestPremiumRate;
        uint64  previousPlatformServiceFeeRate;
        uint256 previousFundsAssetBalance;
    }

    struct OpenTermLoanImpairmentStorage {
        uint40 previousDateImpaired;
        bool   previousImpairedByGovernor;
    }

    struct OpenTermPaymentStorage {
        uint24  previousPlatformManagementFeeRate;
        uint24  previousDelegateManagementFeeRate;
        uint40  previousStartDate;
        uint168 previousIssuanceRate;
    }

    // Both Pool and PoolManager
    struct PoolManagerStorage {
        uint256 previousTotalAssets;
        uint256 previousTotalSupply;
        uint256 previousUnrealizedLosses;
        uint256 previousFundsAssetBalance;
    }

    function _snapshotOpenTermLoan(address loan) internal view returns (OpenTermLoanStorage memory loanStorage) {
        loanStorage.previousFundsAsset               = IOpenTermLoan(loan).fundsAsset();
        loanStorage.previousBorrower                 = IOpenTermLoan(loan).borrower();
        loanStorage.previousLender                   = IOpenTermLoan(loan).lender();
        loanStorage.previousRefinanceCommitment      = IOpenTermLoan(loan).refinanceCommitment();
        loanStorage.previousGracePeriod              = IOpenTermLoan(loan).gracePeriod();
        loanStorage.previousNoticePeriod             = IOpenTermLoan(loan).noticePeriod();
        loanStorage.previousPaymentInterval          = IOpenTermLoan(loan).paymentInterval();
        loanStorage.previousDateCalled               = IOpenTermLoan(loan).dateCalled();
        loanStorage.previousDateFunded               = IOpenTermLoan(loan).dateFunded();
        loanStorage.previousDateImpaired             = IOpenTermLoan(loan).dateImpaired();
        loanStorage.previousDatePaid                 = IOpenTermLoan(loan).datePaid();
        loanStorage.previousCalledPrincipal          = IOpenTermLoan(loan).calledPrincipal();
        loanStorage.previousPrincipal                = IOpenTermLoan(loan).principal();
        loanStorage.previousDelegateServiceFeeRate   = IOpenTermLoan(loan).delegateServiceFeeRate();
        loanStorage.previousInterestRate             = IOpenTermLoan(loan).interestRate();
        loanStorage.previousLateFeeRate              = IOpenTermLoan(loan).lateFeeRate();
        loanStorage.previousLateInterestPremiumRate  = IOpenTermLoan(loan).lateInterestPremiumRate();
        loanStorage.previousPlatformServiceFeeRate   = IOpenTermLoan(loan).platformServiceFeeRate();

        loanStorage.previousFundsAssetBalance = IERC20(IOpenTermLoan(loan).fundsAsset()).balanceOf(loan);
    }

    function _snapshotOpenTermImpairment(address loan) internal view returns (OpenTermLoanImpairmentStorage memory impairmentStorage) {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(IOpenTermLoan(loan).lender());

        ( uint40 dateImpaired, bool impairedByGovernor ) = loanManager.impairmentFor(loan);

        impairmentStorage.previousDateImpaired       = dateImpaired;
        impairmentStorage.previousImpairedByGovernor = impairedByGovernor;
    }

    function _snapshotOpenTermLoanManager(address loanManager)
        internal view returns(OpenTermLoanManagerStorage memory loanManagerStorage)
    {
        loanManagerStorage.previousDomainStart       = IOpenTermLoanManager(loanManager).domainStart();
        loanManagerStorage.previousAccountedInterest = IOpenTermLoanManager(loanManager).accountedInterest();
        loanManagerStorage.previousAccruedInterest   = IOpenTermLoanManager(loanManager).accruedInterest();
        loanManagerStorage.previousPrincipalOut      = IOpenTermLoanManager(loanManager).principalOut();
        loanManagerStorage.previousUnrealizedLosses  = IOpenTermLoanManager(loanManager).unrealizedLosses();
        loanManagerStorage.previousIssuanceRate      = IOpenTermLoanManager(loanManager).issuanceRate();
    }

    function _snapshotOpenTermPayment(address loan) internal view returns (OpenTermPaymentStorage memory paymentStorage) {
        IOpenTermLoanManagerStructs.Payment memory loanInfo = IOpenTermLoanManagerStructs(IOpenTermLoan(loan).lender()).paymentFor(loan);

        paymentStorage.previousPlatformManagementFeeRate = loanInfo.platformManagementFeeRate;
        paymentStorage.previousDelegateManagementFeeRate = loanInfo.delegateManagementFeeRate;
        paymentStorage.previousStartDate                 = loanInfo.startDate;
        paymentStorage.previousIssuanceRate              = loanInfo.issuanceRate;
    }

    function _snapshotPoolManager(address poolManager) internal view returns (PoolManagerStorage memory poolManagerStorage) {
        IPool pool = IPool(IPoolManager(poolManager).pool());

        poolManagerStorage.previousTotalSupply        = pool.totalSupply();
        poolManagerStorage.previousTotalAssets        = IPoolManager(poolManager).totalAssets();
        poolManagerStorage.previousUnrealizedLosses   = IPoolManager(poolManager).unrealizedLosses();
        poolManagerStorage.previousFundsAssetBalance  = IERC20(pool.asset()).balanceOf(address(pool));
    }

}
