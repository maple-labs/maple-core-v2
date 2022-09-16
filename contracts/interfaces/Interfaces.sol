// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

interface IERC20Like {

    function approve(address spender_, uint256 amount_) external returns (bool success_);
    function burn(address owner_, uint256 amount_) external;
    function mint(address recipient_, uint256 amount_) external;
    function transfer(address recipient_, uint256 amount_) external returns (bool success_);
    function transferFrom(address owner_, address recipient_, uint256 amount_) external returns (bool success_);

    function allowance(address owner_, address spender_) external view returns (uint256 allowance_);
    function balanceOf(address account_) external view returns (uint256 balance_);
    function decimals() external view returns (uint8 decimals_);
    function name() external view returns (string memory name_);
    function symbol() external view returns (string memory symbol_);
    function totalSupply() external view returns (uint256 totalSupply_);

}

interface IFeeManagerLike {

    // TODO

}

interface IGlobalsLike {

    function defaultTimelockParameters() external view returns (uint128 delay, uint128 duration);
    function isBorrower(address borrower_) external view returns (bool isValid_);
    function isFactory(bytes32 factoryId_, address factory_) external view returns (bool isValid_);
    function isPoolAsset(address poolAsset_) external view returns (bool isValid_);
    function isPoolDelegate(address account_) external view returns (bool isValid_);
    function isPoolDeployer(address account_) external view returns (bool isValid_);
    function getLatestPrice(address asset_) external view returns (uint256 latestPrice_);
    function governor() external view returns (address governor_);
    function manualOverridePrice(address asset_) external view returns (uint256 manualOverridePrice_);
    function mapleTreasury() external view returns (address mapleTreasury_);
    function maxCoverLiquidationPercent(address poolManager_) external view returns (uint256 maxCoverLiquidationPercent_);
    function migrationAdmin() external view returns (address migrationAdmin_);
    function minCoverAmount(address poolManager_) external view returns (uint256 minCoverAmount_);
    function oracleFor(address asset_) external view returns (address oracle_);
    function ownedPoolManager(address account_) external view returns (address poolManager_);
    function pendingGovernor() external view returns (address pendingGovernor_);
    function platformManagementFeeRate(address poolManager_) external view returns (uint256 platformManagementFeeRate_);
    function platformOriginationFeeRate(address poolManager_) external view returns (uint256 platformOriginationFeeRate_);
    function platformServiceFeeRate(address poolManager_) external view returns (uint256 platformServiceFeeRate_);
    function poolDelegates(address poolDelegate_) external view returns (address ownedPoolManager, bool isPoolDelegate);
    function protocolPaused() external view returns (bool protocolPaused_);
    function scheduledCalls(address caller_, address contract_, bytes32 functionId_) external view returns (uint256 timestamp, bytes32 dataHash);
    function securityAdmin() external view returns (address securityAdmin_);
    function timelockParametersOf(address contract_, bytes32 functionId_) external view returns (uint128 delay, uint128 duration);

    function activatePoolManager(address poolManager_) external;
    function setMapleTreasury(address mapleTreasury_) external;
    function setMigrationAdmin(address migrationAdmin_) external;
    function setPriceOracle(address asset_, address priceOracle_) external;
    function setSecurityAdmin(address securityAdmin_) external;
    function setDefaultTimelockParameters(uint128 defaultTimelockDelay_, uint128 defaultTimelockDuration_) external;

    function setProtocolPause(bool protocolPaused_) external;

    function setValidBorrower(address borrower_, bool isValid_) external;
    function setValidFactory(bytes32 factoryKey_, address factory_, bool isValid_) external;
    function setValidPoolAsset(address poolAsset_, bool isValid_) external;
    function setValidPoolDelegate(address poolDelegate_, bool isValid_) external;
    function setValidPoolDeployer(address poolDeployer_, bool isValid_) external;

    function setManualOverridePrice(address asset_, uint256 price_) external;

    function setMaxCoverLiquidationPercent(address poolManager_, uint256 maxCoverLiquidationPercent_) external;
    function setMinCoverAmount(address poolManager_, uint256 minCoverAmount_) external;

    function setPlatformManagementFeeRate(address poolManager_, uint256 platformManagementFeeRate_) external;
    function setPlatformOriginationFeeRate(address poolManager_, uint256 platformOriginationFeeRate_) external;
    function setPlatformServiceFeeRate(address poolManager_, uint256 platformServiceFeeRate_) external;

}

interface ILoanLike {

    function borrower() external view returns (address borrower_);
    function collateral() external view returns (uint256 collateral_);
    function collateralAsset() external view returns (address collateralAsset_);
    function collateralRequired() external view returns (uint256 collateralRequired_);
    function drawableFunds() external view returns (uint256 drawableFunds_);
    function endingPrincipal() external view returns (uint256 endingPrincipal_);
    function fundsAsset() external view returns (address fundsAsset_);
    function globals() external view returns (address globals_);
    function governor() external view returns (address governor_);
    function gracePeriod() external view returns (uint256 gracePeriod_);
    function interestRate() external view returns (uint256 interestRate_);
    function lateFeeRate() external view returns (uint256 lateFeeRate_);
    function lateInterestPremium() external view returns (uint256 lateInterestPremium_);
    function lender() external view returns (address lender_);
    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);
    function paymentInterval() external view returns (uint256 paymentInterval_);
    function paymentsRemaining() external view returns (uint256 paymentsRemaining_);
    function principal() external view returns (uint256 principal_);
    function principalRequested() external view returns (uint256 principalRequested_);
    function refinanceInterest() external view returns (uint256 refinanceInterest_);

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_);
    function closeLoan(uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 fees_);
    function drawdownFunds(uint256 amount_, address destination_) external returns (uint256 collateralPosted_);
    function fundLoan(address lender_) external returns (uint256 fundsLent_);
    function impairLoan() external;
    function makePayment(uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 fees_);
    function postCollateral(uint256 amount_) external returns (uint256 collateralPosted_);
    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_);
    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_);
    function removeCollateral(uint256 amount_, address destination_) external;
    function removeLoanImpairment() external;
    function returnFunds(uint256 amount_) external returns (uint256 fundsReturned_);
    function repossess(address destination_) external returns (uint256 collateralRepossessed_, uint256 fundsRepossessed_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);
    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);
    function getNextPaymentDetailedBreakdown() external view returns (uint256 principal_, uint256[3] memory interest_, uint256[2] memory fees_);

}

interface ILoanManagerLike {

    function accountedInterest() external view returns (uint112 accountedInterest_);
    function allowedSlippageFor(address collateralAsset_) external view returns (uint256 allowedSlippage_);
    function domainEnd() external view returns (uint48 domainEnd_);
    function domainStart() external view returns (uint48 domainStart_);
    function fundsAsset() external view returns (address fundsAsset_);
    function issuanceRate() external view returns (uint256 issuanceRate_);
    function liquidationInfo(address loan_) external view returns (bool triggeredByGovernor, uint128 principal, uint120 interest, uint256 lateInterest, uint96  platformFees, address liquidator);
    function minRatioFor(address collateralAsset_) external view returns (uint256 minRatio_);
    function paymentCounter() external view returns (uint24 paymentCounter_);
    function paymentIdOf(address loan_) external view returns (uint24 paymentId_);
    function payments(uint256 paymentId_) external view returns (uint24 platformManagementFeeRate, uint24 delegateManagementFeeRate, uint48 startDate, uint48 paymentDueDate, uint128 incomingNetInterest, uint128 refinanceInterest, uint256 issuanceRate);
    function paymentWithEarliestDueDate() external view returns (uint24 paymentWithEarliestDueDate_);
    function pool() external view returns (address pool_);
    function poolManager() external view returns (address poolManager_);
    function principalOut() external view returns (uint128 principalOut_);
    function sortedPayments(uint256 paymentId_) external view returns (uint24 previous, uint24 next, uint48 paymentDueDate);
    function unrealizedLosses() external view returns (uint128 unrealizedLosses_);

    function acceptNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_) external;
    function claim(uint256 principal_, uint256 interest_, uint256 previousPaymentDueDate_, uint256 nextPaymentDueDate_) external;
    function finishCollateralLiquidation(address loan_) external returns (uint256 remainingLosses_, uint256 platformFees_);
    function fund(address loanAddress_) external;
    function impairLoan(address loan_, bool isGovernor_) external;
    function removeLoanImpairment(address loan_, bool isCalledByGovernor_) external;
    function setAllowedSlippage(address collateralAsset_, uint256 allowedSlippage_) external;
    function setMinRatio(address collateralAsset_, uint256 minRatio_) external;
    function triggerDefault(address loan_, address liquidatorFactory_) external returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    function PRECISION() external returns (uint256 precision_);
    function HUNDRED_PERCENT() external returns (uint256 hundredPercent_);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);
    function getAccruedInterest() external view returns (uint256 accruedInterest_);
    function getExpectedAmount(address collateralAsset_, uint256 swapAmount_) external view returns (uint256 returnAmount_);
    function globals() external view returns (address globals_);
    function governor() external view returns (address governor_);
    function isLiquidationActive(address loan_) external view returns (bool isActive_);
    function poolDelegate() external view returns (address poolDelegate_);
    function mapleTreasury() external view returns (address treasury_);

}

interface IPoolLike is IERC20Like {

    function asset() external view returns (address asset_);
    function manager() external view returns (address manager_);

    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);
    function mint(uint256 shares_, address receiver_) external returns (uint256 assets_);
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
    function withdraw(uint256 assets_, address receiver_, address owner_) external returns (uint256 shares_);

    function convertToAssets(uint256 shares_) external view returns (uint256 assets_);
    function convertToShares(uint256 assets_) external view returns (uint256 shares_);

    function maxDeposit(address receiver_) external view returns (uint256 assets_);
    function maxMint(address receiver_) external view returns (uint256 shares_);
    function maxRedeem(address owner_) external view returns (uint256 shares_);
    function maxWithdraw(address owner_) external view returns (uint256 assets_);

    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);
    function previewMint(uint256 shares_) external view returns (uint256 assets_);
    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);
    function previewWithdraw(uint256 assets_) external view returns (uint256 shares_);

    function removeShares(uint256 shares_) external returns (uint256 sharesReturned_);
    function requestWithdraw(uint256 assets_) external returns (uint256 escrowShares_);
    function requestRedeem(uint256 shares_) external returns (uint256 escrowShares_);

    function balanceOfAssets(address account_) external view returns (uint256 assets_);
    function convertToExitShares(uint256 amount_) external view returns (uint256 shares_);

}

interface IPoolDelegateCoverLike {

    function moveFunds(uint256 amount_, address recipient_) external;

}

interface IPoolManagerLike {

    function active() external view returns (bool active_);
    function asset() external view returns (address asset_);
    function configured() external view returns (bool configured_);
    function isLoanManager(address loan_) external view returns (bool isLoanManager_);
    function isValidLender(address lender_) external view returns (bool isValidLender_);
    function loanManagerList(uint256 index_) external view returns (address loanManager_);
    function loanManagers(address loan_) external view returns (address loanManager_);
    function liquidityCap() external view returns (uint256 liquidityCap_);
    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);
    function openToPublic() external view returns (bool openToPublic_);
    function pendingPoolDelegate() external view returns (address pendingPoolDelegate_);
    function pool() external view returns (address pool_);
    function poolDelegate() external view returns (address poolDelegate_);
    function poolDelegateCover() external view returns (address poolDelegateCover_);
    function withdrawalManager() external view returns (address withdrawalManager_);

    function configure(address loanManager_, address withdrawalManager_, uint256 liquidityCap_, uint256 managementFee_) external;
    function addLoanManager(address loanManager_) external;
    function removeLoanManager(address loanManager_) external;
    function setActive(bool active_) external;
    function setAllowedLender(address lender_, bool isValid_) external;
    function setLiquidityCap(uint256 liquidityCap_) external;
    function setOpenToPublic() external;
    function setWithdrawalManager(address withdrawalManager_) external;

    function acceptNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_, uint256 principalIncrease_) external;
    function fund(uint256 principal_, address loan_, address loanManager_) external;

    function finishCollateralLiquidation(address loan_) external;
    function impairLoan(address loan_) external;
    function removeLoanImpairment(address loan_) external;
    function triggerDefault(address loan_, address liquidatorFactory_) external;

    function processRedeem(uint256 shares_, address owner_) external returns (uint256 redeemableShares_, uint256 resultingAssets_);
    function removeShares(uint256 shares_, address owner_) external returns (uint256 sharesReturned_);
    function requestRedeem(uint256 shares_, address owner_) external;

    function depositCover(uint256 amount_) external;
    function withdrawCover(uint256 amount_, address recipient_) external;

    function getEscrowParams(address owner_, uint256 shares_) external view returns (uint256 escorwShares_, address destination_);
    function convertToExitShares(uint256 amount_) external view returns (uint256 shares_);
    function maxDeposit(address receiver_) external view returns (uint256 maxAssets_);
    function maxMint(address receiver_) external view returns (uint256 maxShares_);
    function maxRedeem(address owner_) external view returns (uint256 maxShares_);
    function maxWithdraw(address owner_) external view returns (uint256 maxAssets_);
    function previewRedeem(address owner_, uint256 shares_) external view returns (uint256 assets_);
    function previewWithdraw(address owner_, uint256 assets_) external view returns (uint256 shares_);

    function globals() external view returns (address globals_);
    function governor() external view returns (address governor_);
    function hasSufficientCover() external view returns (bool hasSufficientCover_);

    function totalAssets() external view returns (uint256 totalAssets_);
    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);
}

interface IRefinancerLike {

    // TODO

}

interface IWithdrawalManagerLike {

    // TODO

}
