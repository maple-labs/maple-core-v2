// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IMapleProxiedLike {

    function factory() external view returns (address factory);

    function implementation() external view returns (address implementation);

    function upgrade(uint256 toVersion, bytes calldata arguments) external;

}

interface IAccountingCheckerLike {

    function checkPoolAccounting(
        address poolManager,
        address[] calldata loans,
        uint256 loansAddedTimestamp,
        uint256 lastUpdatedTimestamp
    ) external view
        returns (
            uint256 expectedTotalAssets,
            uint256 actualTotalAssets,
            uint256 expectedDomainEnd,
            uint256 actualDomainEnd
        );

    function globals() external view returns (address globals);

}

interface IDebtLockerLike is IMapleProxiedLike {

    function lender() external view returns (address lender);

    function pool() external view returns (address pool);

    function poolDelegate() external view returns (address poolDelegate);

}

interface IERC20Like {

    function approve(address account, uint256 amount) external returns (bool success);

    function balanceOf(address account) external view returns(uint256);

    function decimals() external view returns (uint8 decimals);

    function name() external view returns (string memory name);

    function transfer(address to, uint256 amount) external returns (bool success);

    function totalSupply() external view returns (uint256 totalSupply);

}

interface IFeeManagerLike {

    function globals() external view returns (address globals);

}

interface ILoanManagerLike {

    function paymentWithEarliestDueDate() external view returns (uint24 paymentWithEarliestDueDate);

    function principalOut() external view returns (uint256 principalOut);

    function sortedPayments(uint256 paymentId) external view returns (
        uint24 previous,
        uint24 next,
        uint48 paymentDueDate
    );

}

interface IMapleGlobalsV1Like {

    function getLatestPrice(address asset) external view returns (uint256 price);

    function governor() external view returns (address governor);

    function investorFee() external view returns (uint256);

    function protocolPaused() external view returns (bool protocolPaused);

    function setInvestorFee(uint256 investorFee) external;

    function setTreasuryFee(uint256 treasuryFee) external;

    function setMaxCoverLiquidationPercent(address poolManager, uint256 maxCoverLiquidationPercent) external;

    function setMinCoverAmount(address poolManager, uint256 minCoverAmount) external;

    function setPriceOracle(address asset, address oracle) external;

    function setProtocolPause(bool pause) external;

    function setStakerCooldownPeriod(uint256 cooldown) external;

    function stakerCooldownPeriod() external view returns (uint256 stakerCooldownPeriod);

    function treasuryFee() external view returns (uint256);

}

interface IMapleGlobalsV2Like {

    function acceptGovernor() external;

    function activatePoolManager(address poolManager) external;

    function admin() external view returns (address admin);

    function bootstrapMint(address asset) external view returns (uint256 bootstrapMint);

    function defaultTimelockParameters() external view returns (uint256 delay, uint256 duration);

    function governor() external view returns (address governor);

    function implementation() external view returns (address implementation);

    function isCollateralAsset(address asset) external view returns (bool isCollateralAsset);

    function isFactory(bytes32 key, address factory) external view returns (bool isFactory);

    function isPoolAsset(address asset) external view returns (bool isPoolAsset);

    function isPoolDelegate(address account) external view returns (bool isPoolDelegate);

    function isPoolDeployer(address poolDeployer) external view returns (bool isPoolDeployer);

    function mapleTreasury() external view returns (address mapleTreasury);

    function maxCoverLiquidationPercent(address poolManager) external view returns (uint256 maxCoverLiquidationPercent);

    function migrationAdmin() external view returns (address migrationAdmin);

    function minCoverAmount(address poolManager) external view returns (uint256 minCoverAmount);

    function pendingGovernor() external view returns (address pendingGovernor);

    function securityAdmin() external view returns (address securityAdmin);

    function setMapleTreasury(address mapleTreasury) external;

    function setMaxCoverLiquidationPercent(address poolManager, uint256 percentage) external;

    function setMigrationAdmin(address migrationAdmin) external;

    function setMinCoverAmount(address poolManager, uint256 amount) external;

    function setPendingGovernor(address governor) external;

    function setSecurityAdmin(address securityAdmin) external;

    function setValidBorrower(address poolDelegate, bool isValid) external;

    function setValidCollateralAsset(address asset, bool isValid) external;

    function setValidPoolAsset(address asset, bool isValid) external;

    function setValidPoolDelegate(address poolDelegate, bool isValid) external;

}

interface IMapleLoanLike is IMapleProxiedLike {

    function borrower() external view returns (address borrower);

    function claimableFunds() external view returns (uint256 claimableFunds);

    function closeLoan(uint256 amount) external returns (uint256 principal, uint256 interest);

    function collateral() external view returns (uint256 collateral);

    function collateralAsset() external view returns (address collateralAsset);

    function collateralRequired() external view returns (uint256 collateralRequired);

    function delegateFee() external view returns (uint256 delegateFee);

    function drawableFunds() external view returns (uint256 drawableFunds);

    function earlyFeeRate() external view returns (uint256 earlyFeeRate);

    function endingPrincipal() external view returns (uint256 endingPrincipal);

    function feeManager() external view returns (address feeManager);

    function fundsAsset() external view returns (address fundsAsset);

    function getClosingPaymentBreakdown() external view returns (uint256 principal, uint256 interest, uint256 fees);

    function getNextPaymentBreakdown() external view returns (uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee);

    function gracePeriod() external view returns (uint256 gracePeriod);

    function interestRate() external view returns (uint256 interestRate);

    function lateFeeRate() external view returns (uint256 lateFeeRate);

    function lateInterestPremium() external view returns (uint256 lateInterestPremium);

    function isImpaired() external view returns (bool isImpaired);  // Not used yet, but wil be used in complex lifecycle

    function lender() external view returns (address lender);

    function makePayment(uint256 amount) external returns (uint256 principal, uint256 interest);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate);

    function paymentInterval() external view returns (uint256 paymentInterval);

    function paymentsRemaining() external view returns (uint256 paymentsRemaining);

    function pendingBorrower() external view returns (address pendingBorrower);

    function pendingLender() external view returns (address pendingLender);

    function principal() external view returns (uint256 principal);

    function principalRequested() external view returns (uint256 principalRequested);

    function refinanceCommitment() external view returns (bytes32 refinanceCommitment);

    function refinanceInterest() external view returns (uint256 refinanceInterest);  // Not used yet, but wil be used in complex lifecycle

    function treasuryFee() external view returns (uint256 treasuryFee);

    function returnFunds(uint256 amount) external;

}

interface IMapleProxyFactoryLike {

    function createInstance(bytes calldata arguments, bytes32 salt) external returns (address instance);

    function enableUpgradePath(uint256 fromVersion, uint256 toVersion, address migrator) external;

    function defaultVersion() external view returns (uint256 defaultVersion);

    function disableUpgradePath(uint256 fromVersion, uint256 toVersion) external;

    function implementationOf(uint256 version) external view returns (address implementation);

    function mapleGlobals() external view returns (address mapleGlobals);

    function migratorForPath(uint256 from, uint256 to) external view returns (address migrator);

    function setDefaultVersion(uint256 version) external;

    function setGlobals(address globals) external;

    function registerImplementation(uint256 version, address implementationAddress, address initializer) external;

    function upgradeEnabledForPath(uint256 toVersion, uint256 fromVersion) external view returns (bool allowed);

    function versionOf(address implementation) external view returns (uint256 version);

}

interface IMigrationHelperLike {

    function addLoansToLoanManager(address poolV1, address transitionLoanManager, address[] calldata loans, uint256 allowedDiff) external;

    function airdropTokens(address poolV1Address, address poolManager, address[] calldata lpsV1, address[] calldata lpsV2, uint256 allowedDiff) external;

    function acceptOwner() external;

    function admin() external view returns (address owner);

    function globalsV2() external view returns (address globals);

    function implementation() external view returns (address implementation);

    function pendingAdmin() external view returns (address pendingOwner);

    function rollback_setPendingLenders(address[] calldata loans) external;

    function rollback_takeOwnershipOfLoans(address transitionLoanManager, address[] calldata loans) external;

    function setGlobals(address globals) external;

    function setPendingAdmin(address pendingAdmin) external;

    function setPendingLenders(address poolV1, address poolV2ManagerAddress, address loanFactoryAddress, address[] calldata loans, uint256 allowedDiff) external;

    function takeOwnershipOfLoans(address poolV1, address transitionLoanManager, address[] calldata loans, uint256 allowedDiff) external;

    function upgradeLoanManager(address transitionLoanManager, uint256 version) external;

}

interface IMplRewardsLike {

    function exit() external;

    function stake(uint256 amount) external;

}

interface IPoolDeployerLike {

    function deployPool(
        address[3] memory factories,
        address[3] memory initializers,
        address asset,
        string memory name,
        string memory symbol,
        uint256[6] memory configParams
    ) external returns (address poolManager, address loanManager, address withdrawalManager);

    function globals() external view returns (address globals);

}

interface IPoolManagerLike {

    function acceptPendingPoolDelegate() external;

    function active() external view returns (bool active);

    function asset() external view returns (address asset);

    function configured() external view returns (bool isConfigured);

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate);

    function depositCover(uint256 amount) external;

    function isLoanManager() external view returns (bool isLoanManager);

    function isValidLender(address lender) external view returns (bool isValidLender);

    function liquidityCap() external view returns (uint256 liquidityCap);

    function loanManagerList(uint256 index) external view returns (address loanManager);

    function openToPublic() external view returns (bool openToPublic);

    function pendingPoolDelegate() external view returns (address poolDelegate);

    function pool() external view returns (address pool);

    function poolDelegate() external view returns (address poolDelegate);

    function poolDelegateCover() external view returns (address poolDelegateCover);

    function setAllowedLender(address lender, bool isValid) external;

    function setLiquidityCap(uint256 newLiquidityCap) external;

    function setOpenToPublic() external;

    function setPendingPoolDelegate(address pendingPoolDelegate) external;

    function totalAssets() external view returns (uint256 totalAssets);

    function withdrawalManager() external view returns (address withdrawalManager);

}

interface IPoolV1Like is IERC20Like {

    function claim(address loan, address dlFactory) external;

    function deactivate() external;

    function deposit(uint256 amount) external;

    function fundLoan(address loan, address dlFactory, uint256 amount) external;

    function intendToWithdraw() external;

    function interestSum() external view returns (uint256 interestSum);

    function liquidityAsset() external view returns (address liquidityAsset);

    function liquidityCap() external view returns (uint256 liquidityCap);

    function liquidityLocker() external pure returns (address liquidityLocker);

    function poolAdmins(address poolAdmin) external view returns (bool isPoolAdmin);

    function poolDelegate() external view returns (address poolDelegate);

    function poolLosses() external view returns (uint256 poolLosses);

    function poolState() external returns(uint8 state);

    function principalOut() external view returns (uint256 principalOut);

    function recognizableLossesOf(address owner) external view returns (uint256 recognizableLosses);

    function setLiquidityCap(uint256 newLiquidityCap) external;

    function setPoolAdmin(address poolAdmin, bool allowed) external;

    function symbol() external view returns (string memory symbol);

    function stakeLocker() external view returns (address stakeLocker);

    function withdrawableFundsOf(address owner) external view returns (uint256 withdrawableFunds);

}

interface IPoolV2Like is IERC20Like {

    function asset() external view returns (address asset);

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function manager() external view returns (address manager);

    function totalAssets() external view returns (uint256 totalAssets);

}

interface IStakeLockerLike is IERC20Like {

    function custodyAllowance(address from, address custodian) external view returns (uint256 allowance);

    function intendToUnstake() external;

    function lockupPeriod() external view returns (uint256 lockupPeriod);

    function pool() external view returns (address pool);

    function recognizableLossesOf(address owner) external view returns (uint256 recognizableLossesOf);

    function setLockupPeriod(uint256 newLockupPeriod) external;

    function stakeAsset() external view returns (address stakeAsset);

    function unstake(uint256 amount) external;

    function unstakeCooldown(address owner) external view returns (uint256 unstakeCooldown);

}
