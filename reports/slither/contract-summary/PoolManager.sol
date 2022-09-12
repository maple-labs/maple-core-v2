Compilation warnings/errors on modules/pool-v2/contracts/PoolManager.sol:
Warning: Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> modules/pool-v2/contracts/PoolManager.sol:371:43:
    |
371 |  ... ction canCall(bytes32 functionId_, address caller_, bytes memory data_) external view ...
    |                                         ^^^^^^^^^^^^^^^

Warning: Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> modules/pool-v2/contracts/PoolManager.sol:448:30:
    |
448 |     function getEscrowParams(address owner_, uint256 shares_) external view override returns (uint256 escrowShares_, address destination_) {
    |                              ^^^^^^^^^^^^^^

Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/pool-v2/contracts/PoolManager.sol:23:1:
   |
23 | contract PoolManager is IPoolManager, MapleProxiedInternals, PoolManagerStorage {
   | ^ (Relevant source part starts here and spans across multiple lines).



+ Contract PoolManager (Most derived contract)
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
  - From ProxiedInternals
    - _factory() (internal)
    - _implementation() (internal)
    - _migrate(address,bytes) (internal)
    - _setFactory(address) (internal)
    - _setImplementation(address) (internal)
  - From SlotManipulatable
    - _getReferenceTypeSlot(bytes32,bytes32) (internal)
    - _getSlotValue(bytes32) (internal)
    - _setSlotValue(bytes32,bytes32) (internal)
  - From PoolManager
    - _canDeposit(uint256,address,string) (internal)
    - _canTransfer(address,string) (internal)
    - _formatErrorMessage(string,string) (internal)
    - _getMaxAssets(address,uint256) (internal)
    - _handleCover(uint256,uint256) (internal)
    - _hasSufficientCover(address,address) (internal)
    - _min(uint256,uint256) (internal)
    - acceptNewTerms(address,address,uint256,bytes[],uint256) (external)
    - acceptPendingPoolDelegate() (external)
    - addLoanManager(address) (external)
    - canCall(bytes32,address,bytes) (external)
    - configure(address,address,uint256,uint256) (external)
    - convertToExitShares(uint256) (public)
    - depositCover(uint256) (external)
    - factory() (external)
    - finishCollateralLiquidation(address) (external)
    - fund(uint256,address,address) (external)
    - getEscrowParams(address,uint256) (external)
    - globals() (public)
    - governor() (public)
    - hasSufficientCover() (public)
    - implementation() (external)
    - maxDeposit(address) (external)
    - maxMint(address) (external)
    - maxRedeem(address) (external)
    - maxWithdraw(address) (external)
    - migrate(address,bytes) (external)
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
    - setImplementation(address) (external)
    - setLiquidityCap(uint256) (external)
    - setOpenToPublic() (external)
    - setPendingPoolDelegate(address) (external)
    - setWithdrawalManager(address) (external)
    - totalAssets() (public)
    - triggerDefault(address) (external)
    - triggerDefaultWarning(address) (external)
    - unrealizedLosses() (public)
    - upgrade(uint256,bytes) (external)
    - withdrawCover(uint256,address) (external)

+ Contract IPoolManager
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

+ Contract PoolManagerStorage
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

+ Contract MapleProxiedInternals
  - From ProxiedInternals
    - _factory() (internal)
    - _implementation() (internal)
    - _migrate(address,bytes) (internal)
    - _setFactory(address) (internal)
    - _setImplementation(address) (internal)
  - From SlotManipulatable
    - _getReferenceTypeSlot(bytes32,bytes32) (internal)
    - _getSlotValue(bytes32) (internal)
    - _setSlotValue(bytes32,bytes32) (internal)

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

+ Contract ProxiedInternals
  - From SlotManipulatable
    - _getReferenceTypeSlot(bytes32,bytes32) (internal)
    - _getSlotValue(bytes32) (internal)
    - _setSlotValue(bytes32,bytes32) (internal)
  - From ProxiedInternals
    - _factory() (internal)
    - _implementation() (internal)
    - _migrate(address,bytes) (internal)
    - _setFactory(address) (internal)
    - _setImplementation(address) (internal)

+ Contract SlotManipulatable
  - From SlotManipulatable
    - _getReferenceTypeSlot(bytes32,bytes32) (internal)
    - _getSlotValue(bytes32) (internal)
    - _setSlotValue(bytes32,bytes32) (internal)

+ Contract IDefaultImplementationBeacon
  - From IDefaultImplementationBeacon
    - defaultImplementation() (external)

+ Contract IProxied
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)

modules/pool-v2/contracts/PoolManager.sol analyzed (26 contracts)
