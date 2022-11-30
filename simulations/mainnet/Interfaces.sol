// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IDebtLockerLike {

    function implementation() external view returns (address implementation_);

    function pool() external view returns (address pool_);

    function poolDelegate() external view returns (address poolDelegate_);

    function setPendingLender(address newLender_) external;

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IERC20Like {

    function approve(address account_, uint256 amount) external returns (bool success_);

    function balanceOf(address account_) external view returns(uint256);

    function decimals() external view returns (uint8 decimals_);

    function transfer(address to_, uint256 amount) external returns (bool success_);

}

interface ILoanManagerLike {

    function paymentIdOf(address loan_) external view returns (uint24 paymentId_);

    function paymentWithEarliestDueDate() external view returns (uint24 paymentWithEarliestDueDate_);

    function setLoanTransferAdmin(address newLoanTransferAdmin_) external;

    function setOwnershipTo(address[] calldata loans_, address[] calldata newLenders_) external;

    function sortedPayments(uint256 paymentId_) external view returns (
        uint24 previous,
        uint24 next,
        uint48 paymentDueDate
    );

    function takeOwnership(address[] calldata loans_) external;

}

interface IMapleProxiedLike {

    function factory() external view returns (address factory_);

    function implementation() external view returns (address implementation_);

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IMapleProxyFactoryLike {

    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    function defaultVersion() external view returns (uint256 defaultVersion_);

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    function implementationOf(uint256 version_) external view returns (address implementation_);

    function mapleGlobals() external view returns (address mapleGlobals_);

    function setDefaultVersion(uint256 version_) external;

    function setGlobals(address globals_) external;

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    function versionOf(address implementation_) external view returns (uint256 version_);

}

interface IMapleGlobalsLike {

    function globalAdmin() external view returns (address);

    function setMaxCoverLiquidationPercent(address poolManager_, uint256 maxCoverLiquidationPercent_) external;

    function setMinCoverAmount(address poolManager_, uint256 minCoverAmount_) external;

    function setPriceOracle(address asset, address oracle) external;

    function setProtocolPause(bool pause) external;

    function setStakerCooldownPeriod(uint256 cooldown_) external;

    function setStakerUnstakeWindow(uint256 window_) external;

}

interface IMapleLoanV3Like {

    function getEarlyPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 delegateFee_, uint256 treasuryFee_);

}

interface IMapleLoanV4Like {

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

}

interface IMapleLoanLike {

    function borrower() external view returns (address borrower_);

    function claimableFunds() external view returns (uint256 claimableFunds_);

    function closeLoan(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function collateral() external view returns (uint256 collateral_);

    function collateralAsset() external view returns (address collateralAsset_);

    function drawableFunds() external view returns (uint256 drawableFunds_);

    function fundsAsset() external view returns (address fundsAsset_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 delegateFee_, uint256 treasuryFee_);

    function implementation() external view returns (address implementation_);

    function isImpaired() external view returns (bool isImpaired_);

    function lender() external view returns (address lender_);

    function makePayment(uint256 amount_) external returns (uint256 principal_, uint256 interest_);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function paymentsRemaining() external view returns (uint256 paymentsRemaining_);

    function pendingLender() external view returns (address pendingLender_);

    function principal() external view returns (uint256 principal_);

    function returnFunds(uint256 amount_) external;

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IMplRewardsLike {

    function exit() external;

    function stake(uint256 amt) external;

}

interface IPoolLike {

    function balanceOf(address account_) external view returns (uint256 balance_);

    function claim(address loan, address dlFactory) external;

    function deactivate() external;

    function deposit(uint256 amt) external;

    function fundLoan(address loan, address dlFactory, uint256 amount) external;

    function intendToWithdraw() external;

    function interestSum() external view returns (uint256);

    function liquidityAsset() external view returns (address);

    function liquidityCap() external view returns (uint256);

    function liquidityLocker() external pure returns (address);

    function name() external view returns (string memory);

    function poolDelegate() external view returns (address);

    function poolLosses() external view returns (uint256);

    function poolState() external returns(uint8 state);

    function principalOut() external view returns (uint256);

    function recognizableLossesOf(address _owner) external view returns (uint256);

    function setLiquidityCap(uint256 newLiquidityCap) external;

    function symbol() external view returns (string memory);

    function stakeLocker() external view returns (address stakeLocker_);

    function withdraw(uint256 amt) external;

    function withdrawableFundsOf(address _owner) external view returns (uint256);

    function totalSupply() external view returns (uint256 totalSupply_);

}

interface IPoolV2Like is IERC20Like {

    function asset() external view returns (address asset_);

    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);

}

interface IPoolManagerLike {

    function acceptPendingPoolDelegate() external;

    function asset() external view returns (address asset_);

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);

    function depositCover(uint256 amount_) external;

    function liquidityCap() external view returns (uint256 liquidityCap_);

    function loanManagerList(uint256 index_) external view returns (address loanManager_);

    function openToPublic() external view returns (bool openToPublic_);

    function pool() external view returns (address pool_);

    function poolDelegate() external view returns (address poolDelegate_);

    function setAllowedLender(address lender_, bool isValid_) external;

    function poolDelegateCover() external view returns (address poolDelegateCover_);

    function setLiquidityCap(uint256 newLiquidityCap_) external;

    function setOpenToPublic() external;

    function setPendingPoolDelegate(address pendingPoolDelegate_) external;

    function totalAssets() external view returns (uint256 totalAssets_);

    function withdrawalManager() external view returns (address withdrawalManager_);

}

interface IStakeLockerLike {

    function balanceOf(address owner) external view returns(uint256);

    function custodyAllowance(address from, address custodian) external view returns(uint256);

    function intendToUnstake() external;

    function isUnstakeAllowed(address from) external view returns (bool);

    function pool() external view returns (address);

    function recognizableLossesOf(address) external view returns (uint256);

    function setLockupPeriod(uint256 newLockupPeriod) external;

    function stakeAsset() external view returns (address stakeAsset_);

    function totalCustodyAllowance(address owner) external view returns(uint256);

    function totalSupply() external view returns(uint256);

    function unstake(uint256 amt) external;

}

interface ITransitionLoanManagerLike {

    function add(address loan_) external;

    function domainEnd() external view returns (uint256 domainEnd_);

    function principalOut() external view returns (uint256 principalOut_);

    function takeOwnership(address[] calldata loans_) external;

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}
