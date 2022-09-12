
+ Contract TransitionLoanManager (Most derived contract)
  - From ILoanManagerStorage
    - accountedInterest() (external)
    - allowedSlippageFor(address) (external)
    - domainEnd() (external)
    - domainStart() (external)
    - fundsAsset() (external)
    - issuanceRate() (external)
    - liquidationInfo(address) (external)
    - minRatioFor(address) (external)
    - paymentCounter() (external)
    - paymentIdOf(address) (external)
    - paymentWithEarliestDueDate() (external)
    - payments(uint256) (external)
    - pool() (external)
    - poolManager() (external)
    - principalOut() (external)
    - sortedPayments(uint256) (external)
    - unrealizedLosses() (external)
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
  - From ITransitionLoanManager
    - HUNDRED_PERCENT() (external)
    - PRECISION() (external)
  - From TransitionLoanManager
    - _addPaymentToList(uint48) (internal)
    - _getNetInterest(uint256,uint256) (internal)
    - _max(uint256,uint256) (internal)
    - _min(uint256,uint256) (internal)
    - _queueNextPayment(address,uint256,uint256) (internal)
    - _removePaymentFromList(uint256) (internal)
    - _uint112(uint256) (internal)
    - _uint128(uint256) (internal)
    - _uint24(uint256) (internal)
    - _uint48(uint256) (internal)
    - add(address) (external)
    - assetsUnderManagement() (public)
    - factory() (external)
    - getAccruedInterest() (public)
    - globals() (public)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - migrationAdmin() (public)
    - setImplementation(address) (external)
    - setOwnershipTo(address[],address) (external)
    - takeOwnership(address[]) (external)
    - upgrade(uint256,bytes) (external)

+ Contract ILoanManagerStorage
  - From ILoanManagerStorage
    - accountedInterest() (external)
    - allowedSlippageFor(address) (external)
    - domainEnd() (external)
    - domainStart() (external)
    - fundsAsset() (external)
    - issuanceRate() (external)
    - liquidationInfo(address) (external)
    - minRatioFor(address) (external)
    - paymentCounter() (external)
    - paymentIdOf(address) (external)
    - paymentWithEarliestDueDate() (external)
    - payments(uint256) (external)
    - pool() (external)
    - poolManager() (external)
    - principalOut() (external)
    - sortedPayments(uint256) (external)
    - unrealizedLosses() (external)

+ Contract ITransitionLoanManager
  - From ILoanManagerStorage
    - accountedInterest() (external)
    - allowedSlippageFor(address) (external)
    - domainEnd() (external)
    - domainStart() (external)
    - fundsAsset() (external)
    - issuanceRate() (external)
    - liquidationInfo(address) (external)
    - minRatioFor(address) (external)
    - paymentCounter() (external)
    - paymentIdOf(address) (external)
    - paymentWithEarliestDueDate() (external)
    - payments(uint256) (external)
    - pool() (external)
    - poolManager() (external)
    - principalOut() (external)
    - sortedPayments(uint256) (external)
    - unrealizedLosses() (external)
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From ITransitionLoanManager
    - HUNDRED_PERCENT() (external)
    - PRECISION() (external)
    - add(address) (external)
    - assetsUnderManagement() (external)
    - getAccruedInterest() (external)
    - globals() (external)
    - migrationAdmin() (external)
    - setOwnershipTo(address[],address) (external)
    - takeOwnership(address[]) (external)

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

+ Contract LoanManagerStorage
  - From ILoanManagerStorage
    - accountedInterest() (external)
    - allowedSlippageFor(address) (external)
    - domainEnd() (external)
    - domainStart() (external)
    - fundsAsset() (external)
    - issuanceRate() (external)
    - liquidationInfo(address) (external)
    - minRatioFor(address) (external)
    - paymentCounter() (external)
    - paymentIdOf(address) (external)
    - paymentWithEarliestDueDate() (external)
    - payments(uint256) (external)
    - pool() (external)
    - poolManager() (external)
    - principalOut() (external)
    - sortedPayments(uint256) (external)
    - unrealizedLosses() (external)

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

modules/pool-v2/contracts/TransitionLoanManager.sol analyzed (24 contracts)
