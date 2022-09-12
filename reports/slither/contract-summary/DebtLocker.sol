Compilation warnings/errors on modules/debt-locker-v4/contracts/DebtLocker.sol:
Warning: Return value of low-level calls not used.
  --> modules/debt-locker-v4/modules/liquidations/contracts/Liquidator.sol:83:9:
   |
83 |         msg.sender.call(data_);
   |         ^^^^^^^^^^^^^^^^^^^^^^

Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/debt-locker-v4/contracts/DebtLocker.sol:15:1:
   |
15 | contract DebtLocker is IDebtLocker, DebtLockerStorage, MapleProxiedInternals {
   | ^ (Relevant source part starts here and spans across multiple lines).



+ Contract DebtLocker (Most derived contract)
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
  - From DebtLocker
    - _getGlobals() (internal)
    - _getPoolDelegate() (internal)
    - _handleClaim(address,address) (internal)
    - _handleClaimOfRepossessed(address,address) (internal)
    - _isLiquidationActive() (internal)
    - acceptNewTerms(address,uint256,bytes[],uint256) (external)
    - allowedSlippage() (external)
    - amountRecovered() (external)
    - claim() (external)
    - factory() (external)
    - fundsToCapture() (external)
    - getExpectedAmount(uint256) (external)
    - implementation() (external)
    - liquidator() (external)
    - loan() (external)
    - loanMigrator() (external)
    - migrate(address,bytes) (external)
    - minRatio() (external)
    - pool() (external)
    - poolDelegate() (external)
    - principalRemainingAtLastClaim() (external)
    - pullFundsFromLiquidator(address,address,address,uint256) (external)
    - rejectNewTerms(address,uint256,bytes[]) (external)
    - repossessed() (external)
    - setAllowedSlippage(uint256) (external)
    - setAuctioneer(address) (external)
    - setFundsToCapture(uint256) (external)
    - setImplementation(address) (external)
    - setMinRatio(uint256) (external)
    - setPendingLender(address) (external)
    - stopLiquidation() (external)
    - triggerDefault() (external)
    - upgrade(uint256,bytes) (external)

+ Contract DebtLockerStorage

+ Contract IDebtLocker
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From IDebtLocker
    - acceptNewTerms(address,uint256,bytes[],uint256) (external)
    - allowedSlippage() (external)
    - amountRecovered() (external)
    - claim() (external)
    - fundsToCapture() (external)
    - getExpectedAmount(uint256) (external)
    - liquidator() (external)
    - loan() (external)
    - loanMigrator() (external)
    - minRatio() (external)
    - pool() (external)
    - poolDelegate() (external)
    - principalRemainingAtLastClaim() (external)
    - pullFundsFromLiquidator(address,address,address,uint256) (external)
    - rejectNewTerms(address,uint256,bytes[]) (external)
    - repossessed() (external)
    - setAllowedSlippage(uint256) (external)
    - setAuctioneer(address) (external)
    - setFundsToCapture(uint256) (external)
    - setMinRatio(uint256) (external)
    - setPendingLender(address) (external)
    - stopLiquidation() (external)
    - triggerDefault() (external)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - balanceOf(address) (external)
    - decimals() (external)

+ Contract ILiquidatorLike (Most derived contract)
  - From ILiquidatorLike
    - auctioneer() (external)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - defaultUniswapPath(address,address) (external)
    - getLatestPrice(address) (external)
    - investorFee() (external)
    - isValidCollateralAsset(address) (external)
    - isValidLiquidityAsset(address) (external)
    - mapleTreasury() (external)
    - protocolPaused() (external)
    - treasuryFee() (external)

+ Contract IMapleLoanLike (Most derived contract)
  - From IMapleLoanLike
    - acceptNewTerms(address,uint256,bytes[],uint256) (external)
    - claimFunds(uint256,address) (external)
    - claimableFunds() (external)
    - collateralAsset() (external)
    - fundsAsset() (external)
    - lender() (external)
    - principal() (external)
    - principalRequested() (external)
    - refinanceCommitment() (external)
    - rejectNewTerms(address,uint256,bytes[]) (external)
    - repossess(address) (external)
    - setPendingLender(address) (external)

+ Contract IPoolLike (Most derived contract)
  - From IPoolLike
    - poolDelegate() (external)
    - superFactory() (external)

+ Contract IPoolFactoryLike (Most derived contract)
  - From IPoolFactoryLike
    - globals() (external)

+ Contract IUniswapRouterLike (Most derived contract)
  - From IUniswapRouterLike
    - swapExactTokensForTokens(uint256,uint256,address[],address,uint256) (external)

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

+ Contract Liquidator (Most derived contract)
  - From ILiquidator
    - auctioneer() (external)
    - collateralAsset() (external)
    - destination() (external)
    - fundsAsset() (external)
    - globals() (external)
    - owner() (external)
  - From Liquidator
    - constructor(address,address,address,address,address,address) (public)
    - getExpectedAmount(uint256) (public)
    - liquidatePortion(uint256,uint256,bytes) (external)
    - pullFunds(address,address,uint256) (external)
    - setAuctioneer(address) (external)

+ Contract ILiquidator
  - From ILiquidator
    - auctioneer() (external)
    - collateralAsset() (external)
    - destination() (external)
    - fundsAsset() (external)
    - getExpectedAmount(uint256) (external)
    - globals() (external)
    - liquidatePortion(uint256,uint256,bytes) (external)
    - owner() (external)
    - pullFunds(address,address,uint256) (external)
    - setAuctioneer(address) (external)

+ Contract IAuctioneerLike (Most derived contract)
  - From IAuctioneerLike
    - getExpectedAmount(uint256) (external)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - allowance(address,address) (external)
    - approve(address,uint256) (external)
    - balanceOf(address) (external)
    - decimals() (external)

+ Contract ILiquidatorLike (Most derived contract)
  - From ILiquidatorLike
    - getExpectedAmount(uint256) (external)
    - liquidatePortion(uint256,uint256,bytes) (external)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - getLatestPrice(address) (external)
    - protocolPaused() (external)

+ Contract IOracleLike (Most derived contract)
  - From IOracleLike
    - latestRoundData() (external)

+ Contract IUniswapRouterLike (Most derived contract)
  - From IUniswapRouterLike
    - swapExactTokensForTokens(uint256,uint256,address[],address,uint256) (external)
    - swapTokensForExactTokens(uint256,uint256,address[],address,uint256) (external)

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

modules/debt-locker-v4/contracts/DebtLocker.sol analyzed (29 contracts)
