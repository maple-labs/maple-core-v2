
+ Contract MapleLoanInternals (Most derived contract)
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
  - From MapleLoanInternals
    - _acceptNewTerms(address,uint256,bytes[]) (internal)
    - _claimFunds(uint256,address) (internal)
    - _clearLoanAccounting() (internal)
    - _closeLoan() (internal)
    - _drawdownFunds(uint256,address) (internal)
    - _fundLoan(address) (internal)
    - _getCollateralRequiredFor(uint256,uint256,uint256,uint256) (internal)
    - _getEarlyPaymentBreakdown() (internal)
    - _getInstallment(uint256,uint256,uint256,uint256,uint256) (internal)
    - _getInterest(uint256,uint256,uint256) (internal)
    - _getLateInterest(uint256,uint256,uint256,uint256,uint256,uint256) (internal)
    - _getNextPaymentBreakdown() (internal)
    - _getPaymentBreakdown(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) (internal)
    - _getPeriodicInterestRate(uint256,uint256) (internal)
    - _getRefinanceCommitment(address,uint256,bytes[]) (internal)
    - _getRefinanceInterestParams(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) (internal)
    - _getUnaccountedAmount(address) (internal)
    - _initialize(address,address[2],uint256[3],uint256[3],uint256[4]) (internal)
    - _isCollateralMaintained() (internal)
    - _makePayment() (internal)
    - _mapleGlobals() (internal)
    - _postCollateral() (internal)
    - _processEstablishmentFees(uint256,uint256) (internal)
    - _proposeNewTerms(address,uint256,bytes[]) (internal)
    - _rejectNewTerms(address,uint256,bytes[]) (internal)
    - _removeCollateral(uint256,address) (internal)
    - _repossess(address) (internal)
    - _returnFunds() (internal)
    - _scaledExponent(uint256,uint256,uint256) (internal)
    - _sendFee(address,bytes4,uint256) (internal)
    - _setEstablishmentFees(uint256,uint256,uint256,uint256) (internal)

+ Contract IMapleLoanFactory (Most derived contract)
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
  - From IDefaultImplementationBeacon
    - defaultImplementation() (external)
  - From IMapleLoanFactory
    - isLoan(address) (external)

+ Contract ILenderLike (Most derived contract)
  - From ILenderLike
    - poolDelegate() (external)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - globalAdmin() (external)
    - governor() (external)
    - investorFee() (external)
    - mapleTreasury() (external)
    - protocolPaused() (external)
    - treasuryFee() (external)

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

+ Contract IERC20 (Most derived contract)
  - From IERC20
    - DOMAIN_SEPARATOR() (external)
    - PERMIT_TYPEHASH() (external)
    - allowance(address,address) (external)
    - approve(address,uint256) (external)
    - balanceOf(address) (external)
    - decimals() (external)
    - decreaseAllowance(address,uint256) (external)
    - increaseAllowance(address,uint256) (external)
    - name() (external)
    - nonces(address) (external)
    - permit(address,address,uint256,uint256,uint8,bytes32,bytes32) (external)
    - symbol() (external)
    - totalSupply() (external)
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

+ Contract IMapleProxyFactory (Upgradeable Proxy)
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

modules/loan-v301/contracts/MapleLoanInternals.sol analyzed (12 contracts)
