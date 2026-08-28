// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IERC4626Like,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IOpenTermLoanManagerStructs,
    IPool,
    IPSMLike,
    IPoolManager,
    IStrategyManager,
    ISkyStrategy
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

    struct AaveStrategyStorage {
        bool    previousIsLossRecognized;
        uint16  previousReferralCode;
        uint32  previousStrategyDelegateFeeRate;
        uint32  previousStrategyProtocolFeeRate;
        uint256 previousATokenBalance;
        uint256 previousAssetsUnderManagement;
        uint256 previousAvailableToWithdraw;
        uint256 previousImpairedAssets;
        uint256 previousLastRecordedTotalAssets;
        uint256 previousUnrealizedLosses;
    }

    struct SkyStrategyStorage {
        uint32  previousStrategyDelegateFeeRate;
        uint32  previousStrategyProtocolFeeRate;
        uint256 previousSavingsUsdsBalance;
        uint256 previousCurrentTotalAssets;
        uint256 previousAssetsUnderManagement;
        uint256 previousImpairedAssets;
        uint256 previousLastRecordedTotalAssets;
    }

    struct StrategyManagerStorage {
        uint256 previousAvailableToWithdraw;
        uint256 previousTotalAssets;
        uint256 previousTotalPendingShares;
        uint256 previousTotalShares;
        uint256 previousUnrealizedLosses;
    }

    struct StrategyManagerPositionStorage {
        uint256 previousAssets;
        uint256 previousPendingShares;
        uint256 previousShares;
        uint256 previousUnrealizedLosses;
    }

    struct FeeAccrualStorage {
        uint256 previousDelegateBalance;
        uint256 previousTreasuryBalance;
    }

    function _snapshotAaveStrategy(address strategy) internal view returns (AaveStrategyStorage memory strategyStorage) {
        strategyStorage.previousIsLossRecognized        = IAaveV3Strategy(strategy).isLossRecognized();
        strategyStorage.previousReferralCode            = IAaveV3Strategy(strategy).referralCode();
        strategyStorage.previousStrategyDelegateFeeRate = IAaveV3Strategy(strategy).strategyDelegateFeeRate();
        strategyStorage.previousStrategyProtocolFeeRate = IAaveV3Strategy(strategy).strategyProtocolFeeRate();
        strategyStorage.previousATokenBalance           = IERC20(IAaveV3Strategy(strategy).aaveToken()).balanceOf(strategy);
        strategyStorage.previousAssetsUnderManagement   = IAaveV3Strategy(strategy).assetsUnderManagement();
        strategyStorage.previousAvailableToWithdraw     = IAaveV3Strategy(strategy).availableToWithdraw();
        strategyStorage.previousImpairedAssets          = IAaveV3Strategy(strategy).impairedAssets();
        strategyStorage.previousLastRecordedTotalAssets = IAaveV3Strategy(strategy).lastRecordedTotalAssets();
        strategyStorage.previousUnrealizedLosses        = IAaveV3Strategy(strategy).unrealizedLosses();
    }

    function _snapshotSkyStrategy(address strategy) internal view returns (SkyStrategyStorage memory strategyStorage) {
        strategyStorage.previousStrategyDelegateFeeRate = ISkyStrategy(strategy).strategyDelegateFeeRate();
        strategyStorage.previousStrategyProtocolFeeRate = ISkyStrategy(strategy).strategyProtocolFeeRate();
        strategyStorage.previousSavingsUsdsBalance      = IERC20(ISkyStrategy(strategy).savingsUsds()).balanceOf(strategy);
        strategyStorage.previousCurrentTotalAssets      = _skyCurrentTotalAssets(strategy);
        strategyStorage.previousAssetsUnderManagement   = ISkyStrategy(strategy).assetsUnderManagement();
        strategyStorage.previousImpairedAssets          = ISkyStrategy(strategy).impairedAssets();
        strategyStorage.previousLastRecordedTotalAssets = ISkyStrategy(strategy).lastRecordedTotalAssets();
    }

    function _skyCurrentTotalAssets(address strategy) internal view returns (uint256 currentTotalAssets) {
        address psm         = ISkyStrategy(strategy).psm();
        address savingsUsds = ISkyStrategy(strategy).savingsUsds();

        uint256 usds = IERC4626Like(savingsUsds).previewRedeem(IERC20(savingsUsds).balanceOf(strategy));
        uint256 tout = IPSMLike(psm).tout();

        if (tout == type(uint256).max) tout = ISkyStrategy(strategy).fallbackTout();

        currentTotalAssets = usds * 1e18 / (IPSMLike(psm).to18ConversionFactor() * (1e18 + tout));
    }

    function _snapshotFeeAccrualSky(address strategy) internal view returns (FeeAccrualStorage memory feeAccrualStorage) {
        address fundsAsset = ISkyStrategy(strategy).fundsAsset();

        feeAccrualStorage.previousDelegateBalance = IERC20(fundsAsset).balanceOf(ISkyStrategy(strategy).strategyDelegate());
        feeAccrualStorage.previousTreasuryBalance = IERC20(fundsAsset).balanceOf(ISkyStrategy(strategy).mapleTreasury());
    }

    function _snapshotStrategyManager(address strategyManager)
        internal view returns (StrategyManagerStorage memory strategyManagerStorage)
    {
        strategyManagerStorage.previousAvailableToWithdraw = IStrategyManager(strategyManager).availableToWithdraw();
        strategyManagerStorage.previousTotalAssets         = IStrategyManager(strategyManager).assetsUnderManagement();
        strategyManagerStorage.previousTotalPendingShares  = IStrategyManager(strategyManager).totalPendingShares();
        strategyManagerStorage.previousTotalShares         = IStrategyManager(strategyManager).totalShares();
        strategyManagerStorage.previousUnrealizedLosses    = IStrategyManager(strategyManager).unrealizedLosses();
    }

    function _snapshotStrategyManagerPosition(address strategyManager, address poolManager)
        internal view returns (StrategyManagerPositionStorage memory positionStorage)
    {
        positionStorage.previousAssets           = IStrategyManager(strategyManager).assetsOf(poolManager);
        positionStorage.previousPendingShares    = IStrategyManager(strategyManager).pendingSharesOf(poolManager);
        positionStorage.previousShares           = IStrategyManager(strategyManager).sharesOf(poolManager);
        positionStorage.previousUnrealizedLosses = IStrategyManager(strategyManager).unrealizedLossesOf(poolManager);
    }

    function _snapshotFeeAccrual(address strategy) internal view returns (FeeAccrualStorage memory feeAccrualStorage) {
        address fundsAsset = IAaveV3Strategy(strategy).fundsAsset();

        feeAccrualStorage.previousDelegateBalance = IERC20(fundsAsset).balanceOf(IAaveV3Strategy(strategy).strategyDelegate());
        feeAccrualStorage.previousTreasuryBalance = IERC20(fundsAsset).balanceOf(IAaveV3Strategy(strategy).mapleTreasury());
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
