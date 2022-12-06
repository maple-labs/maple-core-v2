// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IAccountingCheckerLike {

    function globals() external view returns (address globals);

}

interface IDebtLockerLike {

    function factory() external view returns (address factory);

    function implementation() external view returns (address implementation);

}

interface IERC20Like {

    function asset() external view returns (address asset);

    function balanceOf(address account) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimals);

}

interface IFeeManagerLike {

    function globals() external view returns (address globals);

}

interface ILoanLike {

    function claimableFunds() external view returns (uint256 claimableFunds);

    function drawableFunds() external view returns (uint256 principalRequested);

    function factory() external view returns (address factory);

    function fundsAsset() external view returns (address fundsAsset);

    function implementation() external view returns (address implementation);

    function lender() external view returns (address lender);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate);

    function paymentsRemaining() external view returns (uint256 paymentsRemaining);

    function pendingLender() external view returns (address pendingLender);

    function principalRequested() external view returns (uint256 principalRequested);

}

interface IMapleGlobalsV1Like {

    function globalAdmin() external view returns (address);

    function governor() external view returns (address governor);

    function ownedPoolManager(address) external view returns (address);

    function getLatestPrice(address asset) external view returns (uint256 price);

    function protocolPaused() external view returns (bool protocolPaused);

    function stakerCooldownPeriod() external view returns (uint256);

    function stakerUnstakeWindow() external view returns (uint256);

    function investorFee() external view returns (uint256);

    function treasuryFee() external view returns (uint256);

}

interface IMapleGlobalsV2Like {

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

}

interface IMapleProxyFactoryLike {

    function defaultVersion() external view returns (uint256 version);

    function migratorForPath(uint256 from, uint256 to) external view returns (address migrator);

    function implementationOf(uint256 version) external view returns (address implementation);

    function upgradeEnabledForPath(uint256 from, uint256 to) external view returns (bool enabled);

    function versionOf(address implementation) external view returns (uint256 version);

}

interface IMigrationHelperLike {

    function admin() external view returns (address owner);

    function globalsV2() external view returns (address globals);

    function implementation() external view returns (address implementation);

    function pendingAdmin() external view returns (address pendingOwner);

}

interface IMplRewardsLike {

    // TODO

}

interface IPoolManagerLike {

    function active() external view returns (bool active);

    function asset() external view returns (address asset);

    function configured() external view returns (bool configured);

    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate);

    function isLoanManager() external view returns (bool isLoanManager);

    function globals() external view returns (address globals);

    function isValidLender(address lender) external view returns (bool isValidLender);

    function liquidityCap() external view returns (uint256 liquidityCap);

    function loanManagerList(uint256 index) external view returns (address loanManager);

    function openToPublic() external view returns (bool openToPublic);

    function pendingPoolDelegate() external view returns (address pendingPoolDelegate);

    function pool() external view returns (address pool);

    function poolDelegate() external view returns (address poolDelegate);

    function poolDelegateCover() external view returns (address poolDelegateCover);

    function setOpenToPublic() external;

    function totalAssets() external view returns (uint256 totalAssets);

    function withdrawalManager() external view returns (address withdrawalManager);

}

interface IPoolV1Like {

    function balanceOf(address account) external view returns (uint256 balance);

    function interestSum() external view returns (uint256 interestSum);

    function liquidityAsset() external view returns (address liquidityAsset);

    function liquidityCap() external view returns (uint256 liquidityCap);

    function liquidityLocker() external view returns (address liquidityLocker);

    function poolAdmins(address poolAdmin) external view returns (bool isPoolAdmin);

    function poolDelegate() external view returns (address poolDelegate);

    function poolLosses() external view returns (uint256 poolLosses);

    function poolState() external returns (uint8 state);

    function recognizableLossesOf(address owner) external view returns (uint256 losses);

    function stakeLocker() external view returns (address stakeLocker);

    function totalSupply() external view returns (uint256 totalSupply);

    function withdrawableFundsOf(address owner) external view returns (uint256 funds);

}

interface IPoolV2Like {

    function asset() external view returns (address asset_);

    function balanceOf(address account) external view returns (uint256 balance);

    function manager() external view returns (address manager);

    function name() external view returns (string memory name);

    function totalSupply() external view returns (uint256 totalSupply);

}

interface IPoolDeployerLike {

    function globals() external view returns (address globals);

}

interface IStakeLockerLike {

    function lockupPeriod() external view returns (uint256 lockupPeriod);

    function unstakeCooldown(address poolDelegate) external view returns (uint256 time);

}

interface ITransitionLoanManagerLike {

    function factory() external view returns (address factory);

    function implementation() external view returns (address implementation);

}

interface IWithdrawalManagerLike {

    // TODO

}
