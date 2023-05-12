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

    function _snapshotOpenTermLoan(IOpenTermLoan loan) internal view returns (OpenTermLoanStorage memory loanStorage) {
        loanStorage.previousFundsAsset               = loan.fundsAsset();
        loanStorage.previousBorrower                 = loan.borrower();
        loanStorage.previousLender                   = loan.lender();
        loanStorage.previousRefinanceCommitment      = loan.refinanceCommitment();
        loanStorage.previousGracePeriod              = loan.gracePeriod();
        loanStorage.previousNoticePeriod             = loan.noticePeriod();
        loanStorage.previousPaymentInterval          = loan.paymentInterval();
        loanStorage.previousDateCalled               = loan.dateCalled();
        loanStorage.previousDateFunded               = loan.dateFunded();
        loanStorage.previousDateImpaired             = loan.dateImpaired();
        loanStorage.previousDatePaid                 = loan.datePaid();
        loanStorage.previousCalledPrincipal          = loan.calledPrincipal();
        loanStorage.previousPrincipal                = loan.principal();
        loanStorage.previousDelegateServiceFeeRate   = loan.delegateServiceFeeRate();
        loanStorage.previousInterestRate             = loan.interestRate();
        loanStorage.previousLateFeeRate              = loan.lateFeeRate();
        loanStorage.previousLateInterestPremiumRate  = loan.lateInterestPremiumRate();
        loanStorage.previousPlatformServiceFeeRate   = loan.platformServiceFeeRate();

        loanStorage.previousFundsAssetBalance = IERC20(loan.fundsAsset()).balanceOf(address(loan));
    }

    function _snapshotOpenTermImpairment(IOpenTermLoan loan) internal view returns (OpenTermLoanImpairmentStorage memory impairmentStorage) {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(loan.lender());

        ( uint40 dateImpaired, bool impairedByGovernor ) = loanManager.impairmentFor(address(loan));

        impairmentStorage.previousDateImpaired       = dateImpaired;
        impairmentStorage.previousImpairedByGovernor = impairedByGovernor;
    }

    function _snapshotOpenTermLoanManager(IOpenTermLoanManager loanManager)
        internal view returns(OpenTermLoanManagerStorage memory loanManagerStorage)
    {
        loanManagerStorage.previousDomainStart       = loanManager.domainStart();
        loanManagerStorage.previousAccountedInterest = loanManager.accountedInterest();
        loanManagerStorage.previousAccruedInterest   = loanManager.accruedInterest();
        loanManagerStorage.previousPrincipalOut      = loanManager.principalOut();
        loanManagerStorage.previousUnrealizedLosses  = loanManager.unrealizedLosses();
        loanManagerStorage.previousIssuanceRate      = loanManager.issuanceRate();
    }

    function _snapshotOpenTermPayment(IOpenTermLoan loan) internal view returns (OpenTermPaymentStorage memory paymentStorage) {
        IOpenTermLoanManagerStructs.Payment memory loanInfo = IOpenTermLoanManagerStructs(loan.lender()).paymentFor(address(loan));

        paymentStorage.previousPlatformManagementFeeRate = loanInfo.platformManagementFeeRate;
        paymentStorage.previousDelegateManagementFeeRate = loanInfo.delegateManagementFeeRate;
        paymentStorage.previousStartDate                 = loanInfo.startDate;
        paymentStorage.previousIssuanceRate              = loanInfo.issuanceRate;
    }

    function _snapshotPoolManager(IPoolManager poolManager) internal view returns (PoolManagerStorage memory poolManagerStorage) {
        IPool pool = IPool(poolManager.pool());

        poolManagerStorage.previousTotalSupply        = pool.totalSupply();
        poolManagerStorage.previousTotalAssets        = poolManager.totalAssets();
        poolManagerStorage.previousUnrealizedLosses   = poolManager.unrealizedLosses();
        poolManagerStorage.previousFundsAssetBalance  = IERC20(pool.asset()).balanceOf(address(pool));
    }

}
