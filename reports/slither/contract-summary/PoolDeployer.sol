
+ Contract PoolDeployer (Most derived contract)
  - From IPoolDeployer
    - globals() (external)
  - From PoolDeployer
    - constructor(address) (public)
    - deployPool(address[3],address[3],address,string,string,uint256[6]) (external)

+ Contract IPoolDeployer
  - From IPoolDeployer
    - deployPool(address[3],address[3],address,string,string,uint256[6]) (external)
    - globals() (external)

+ Contract IPoolManager (Most derived contract)
  - From IPoolManagerStorage
    - active() (external)
    - asset() (external)
    - configured() (external)
    - delegateManagementFeeRate() (external)
    - isLoanManager(address) (external)
    - isValidLender(address) (external)
    - liquidityCap() (external)
    - loanManagerList(uint256) (external)
    - loanManagers(address) (external)
    - openToPublic() (external)
    - pendingPoolDelegate() (external)
    - pool() (external)
    - poolDelegate() (external)
    - poolDelegateCover() (external)
    - withdrawalManager() (external)
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From IPoolManager
    - acceptNewTerms(address,address,uint256,bytes[],uint256) (external)
    - acceptPendingPoolDelegate() (external)
    - addLoanManager(address) (external)
    - canCall(bytes32,address,bytes) (external)
    - configure(address,address,uint256,uint256) (external)
    - convertToExitShares(uint256) (external)
    - depositCover(uint256) (external)
    - finishCollateralLiquidation(address) (external)
    - fund(uint256,address,address) (external)
    - getEscrowParams(address,uint256) (external)
    - globals() (external)
    - governor() (external)
    - hasSufficientCover() (external)
    - maxDeposit(address) (external)
    - maxMint(address) (external)
    - maxRedeem(address) (external)
    - maxWithdraw(address) (external)
    - previewRedeem(address,uint256) (external)
    - previewWithdraw(address,uint256) (external)
    - processRedeem(uint256,address) (external)
    - removeDefaultWarning(address) (external)
    - removeLoanManager(address) (external)
    - removeShares(uint256,address) (external)
    - requestRedeem(uint256,address) (external)
    - setActive(bool) (external)
    - setAllowedLender(address,bool) (external)
    - setDelegateManagementFeeRate(uint256) (external)
    - setLiquidityCap(uint256) (external)
    - setOpenToPublic() (external)
    - setPendingPoolDelegate(address) (external)
    - setWithdrawalManager(address) (external)
    - totalAssets() (external)
    - triggerDefault(address) (external)
    - triggerDefaultWarning(address) (external)
    - unrealizedLosses() (external)
    - withdrawCover(uint256,address) (external)

+ Contract IPoolManagerInitializer (Most derived contract)
  - From IPoolManagerInitializer
    - decodeArguments(bytes) (external)
    - encodeArguments(address,address,uint256,string,string) (external)

+ Contract IPoolManagerStorage
  - From IPoolManagerStorage
    - active() (external)
    - asset() (external)
    - configured() (external)
    - delegateManagementFeeRate() (external)
    - isLoanManager(address) (external)
    - isValidLender(address) (external)
    - liquidityCap() (external)
    - loanManagerList(uint256) (external)
    - loanManagers(address) (external)
    - openToPublic() (external)
    - pendingPoolDelegate() (external)
    - pool() (external)
    - poolDelegate() (external)
    - poolDelegateCover() (external)
    - withdrawalManager() (external)

+ Contract IERC20Like
  - From IERC20Like
    - balanceOf(address) (external)
    - decimals() (external)
    - totalSupply() (external)

+ Contract ILoanManagerLike (Most derived contract)
  - From ILoanManagerLike
    - acceptNewTerms(address,address,uint256,bytes[]) (external)
    - assetsUnderManagement() (external)
    - claim(address,bool) (external)
    - finishCollateralLiquidation(address) (external)
    - fund(address) (external)
    - removeDefaultWarning(address,bool) (external)
    - triggerDefault(address) (external)
    - triggerDefaultWarning(address,bool) (external)
    - unrealizedLosses() (external)

+ Contract ILoanManagerInitializerLike (Most derived contract)
  - From ILoanManagerInitializerLike
    - decodeArguments(bytes) (external)
    - encodeArguments(address) (external)

+ Contract ILiquidatorLike (Most derived contract)
  - From ILiquidatorLike
    - liquidatePortion(uint256,uint256,bytes) (external)
    - pullFunds(address,address,uint256) (external)

+ Contract ILoanV3Like (Most derived contract)
  - From ILoanV3Like
    - getNextPaymentBreakdown() (external)

+ Contract ILoanLike (Most derived contract)
  - From ILoanLike
    - acceptLender() (external)
    - acceptNewTerms(address,uint256,bytes[]) (external)
    - batchClaimFunds(uint256[],address[]) (external)
    - borrower() (external)
    - claimFunds(uint256,address) (external)
    - collateral() (external)
    - collateralAsset() (external)
    - feeManager() (external)
    - fundLoan(address) (external)
    - fundsAsset() (external)
    - getClosingPaymentBreakdown() (external)
    - getNextPaymentBreakdown() (external)
    - getNextPaymentDetailedBreakdown() (external)
    - gracePeriod() (external)
    - interestRate() (external)
    - isInDefaultWarning() (external)
    - lateFeeRate() (external)
    - nextPaymentDueDate() (external)
    - paymentInterval() (external)
    - paymentsRemaining() (external)
    - prewarningPaymentDueDate() (external)
    - principal() (external)
    - principalRequested() (external)
    - refinanceInterest() (external)
    - removeDefaultWarning() (external)
    - repossess(address) (external)
    - setPendingLender(address) (external)
    - triggerDefaultWarning() (external)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - getLatestPrice(address) (external)
    - governor() (external)
    - isBorrower(address) (external)
    - isFactory(bytes32,address) (external)
    - isPoolAsset(address) (external)
    - isPoolDelegate(address) (external)
    - isPoolDeployer(address) (external)
    - isValidScheduledCall(address,address,bytes32,bytes) (external)
    - mapleTreasury() (external)
    - maxCoverLiquidationPercent(address) (external)
    - migrationAdmin() (external)
    - minCoverAmount(address) (external)
    - ownedPoolManager(address) (external)
    - platformManagementFeeRate(address) (external)
    - protocolPaused() (external)
    - transferOwnedPoolManager(address,address) (external)
    - unscheduleCall(address,bytes32,bytes) (external)

+ Contract IMapleLoanFeeManagerLike (Most derived contract)
  - From IMapleLoanFeeManagerLike
    - platformServiceFee(address) (external)

+ Contract IMapleProxyFactoryLike (Upgradeable Proxy) (Most derived contract)
  - From IMapleProxyFactoryLike
    - mapleGlobals() (external)

+ Contract IPoolDelegateCoverLike (Most derived contract)
  - From IPoolDelegateCoverLike
    - moveFunds(uint256,address) (external)

+ Contract IPoolLike (Most derived contract)
  - From IERC20Like
    - balanceOf(address) (external)
    - decimals() (external)
    - totalSupply() (external)
  - From IPoolLike
    - asset() (external)
    - convertToAssets(uint256) (external)
    - convertToExitShares(uint256) (external)
    - deposit(uint256,address) (external)
    - manager() (external)
    - previewMint(uint256) (external)
    - processExit(uint256,uint256,address,address) (external)
    - redeem(uint256,address,address) (external)

+ Contract IPoolManagerLike (Most derived contract)
  - From IPoolManagerLike
    - addLoanManager(address) (external)
    - canCall(bytes32,address,bytes) (external)
    - claim(address) (external)
    - convertToExitShares(uint256) (external)
    - delegateManagementFeeRate() (external)
    - fund(uint256,address,address) (external)
    - getEscrowParams(address,uint256) (external)
    - globals() (external)
    - hasSufficientCover() (external)
    - loanManager() (external)
    - maxDeposit(address) (external)
    - maxMint(address) (external)
    - maxRedeem(address) (external)
    - maxWithdraw(address) (external)
    - poolDelegate() (external)
    - poolDelegateCover() (external)
    - previewRedeem(address,uint256) (external)
    - previewWithdraw(address,uint256) (external)
    - processRedeem(uint256,address) (external)
    - processWithdraw(uint256,address) (external)
    - removeLoanManager(address) (external)
    - removeShares(uint256,address) (external)
    - requestRedeem(uint256,address) (external)
    - setWithdrawalManager(address) (external)
    - totalAssets() (external)
    - unrealizedLosses() (external)
    - withdrawalManager() (external)

+ Contract IWithdrawalManagerLike (Most derived contract)
  - From IWithdrawalManagerLike
    - addShares(uint256,address) (external)
    - isInExitWindow(address) (external)
    - lockedLiquidity() (external)
    - lockedShares(address) (external)
    - previewRedeem(address,uint256) (external)
    - processExit(address,uint256) (external)
    - removeShares(uint256,address) (external)

+ Contract ERC20Helper (Most derived contract)
  - From ERC20Helper
    - _call(address,bytes) (private)
    - approve(address,address,uint256) (internal)
    - transfer(address,address,uint256) (internal)
    - transferFrom(address,address,address,uint256) (internal)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - approve(address,uint256) (external)
    - transfer(address,uint256) (external)
    - transferFrom(address,address,uint256) (external)

+ Contract IMapleProxied
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)

+ Contract IMapleProxyFactory (Upgradeable Proxy) (Most derived contract)
  - From IDefaultImplementationBeacon
    - defaultImplementation() (external)
  - From IMapleProxyFactory
    - createInstance(bytes,bytes32) (external)
    - defaultVersion() (external)
    - disableUpgradePath(uint256,uint256) (external)
    - enableUpgradePath(uint256,uint256,address) (external)
    - getInstanceAddress(bytes,bytes32) (external)
    - implementationOf(uint256) (external)
    - isInstance(address) (external)
    - mapleGlobals() (external)
    - migratorForPath(uint256,uint256) (external)
    - registerImplementation(uint256,address,address) (external)
    - setDefaultVersion(uint256) (external)
    - setGlobals(address) (external)
    - upgradeEnabledForPath(uint256,uint256) (external)
    - upgradeInstance(uint256,bytes) (external)
    - versionOf(address) (external)

+ Contract IDefaultImplementationBeacon
  - From IDefaultImplementationBeacon
    - defaultImplementation() (external)

+ Contract IProxied
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)

modules/pool-v2/contracts/PoolDeployer.sol analyzed (24 contracts)
