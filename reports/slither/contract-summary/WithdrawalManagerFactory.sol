Function not found isPoolDeployer
Impossible to generate IR for WithdrawalManagerFactory.createInstance

+ Contract WithdrawalManagerFactory (Most derived contract)
  - From MapleProxyFactory
    - defaultImplementation() (external)
    - disableUpgradePath(uint256,uint256) (public)
    - enableUpgradePath(uint256,uint256,address) (public)
    - getInstanceAddress(bytes,bytes32) (public)
    - implementationOf(uint256) (public)
    - migratorForPath(uint256,uint256) (public)
    - registerImplementation(uint256,address,address) (public)
    - setDefaultVersion(uint256) (public)
    - setGlobals(address) (public)
    - upgradeInstance(uint256,bytes) (public)
    - versionOf(address) (public)
  - From ProxyFactory
    - _getDeterministicProxyAddress(bytes32) (internal)
    - _getImplementationOfProxy(address) (private)
    - _initializeInstance(address,uint256,bytes) (private)
    - _isContract(address) (internal)
    - _newInstance(bytes,bytes32) (internal)
    - _newInstance(uint256,bytes) (internal)
    - _registerImplementation(uint256,address) (internal)
    - _registerMigrator(uint256,uint256,address) (internal)
    - _upgradeInstance(address,uint256,bytes) (internal)
  - From IMapleProxyFactory
    - defaultVersion() (external)
    - mapleGlobals() (external)
    - upgradeEnabledForPath(uint256,uint256) (external)
  - From WithdrawalManagerFactory
    - constructor(address) (public)
    - createInstance(bytes,bytes32) (public)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - governor() (external)
    - isPoolDeployer(address) (external)
    - isValidScheduledCall(address,address,bytes32,bytes) (external)
    - unscheduleCall(address,bytes32,bytes) (external)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - balanceOf(address) (external)

+ Contract IPoolLike (Most derived contract)
  - From IPoolLike
    - asset() (external)
    - convertToShares(uint256) (external)
    - manager() (external)
    - previewRedeem(uint256) (external)
    - redeem(uint256,address,address) (external)
    - totalSupply() (external)
    - transfer(address,uint256) (external)

+ Contract IPoolManagerLike (Most derived contract)
  - From IPoolManagerLike
    - globals() (external)
    - poolDelegate() (external)
    - totalAssets() (external)
    - unrealizedLosses() (external)

+ Contract MapleProxyFactory (Upgradeable Proxy)
  - From ProxyFactory
    - _getDeterministicProxyAddress(bytes32) (internal)
    - _getImplementationOfProxy(address) (private)
    - _initializeInstance(address,uint256,bytes) (private)
    - _isContract(address) (internal)
    - _newInstance(bytes,bytes32) (internal)
    - _newInstance(uint256,bytes) (internal)
    - _registerImplementation(uint256,address) (internal)
    - _registerMigrator(uint256,uint256,address) (internal)
    - _upgradeInstance(address,uint256,bytes) (internal)
  - From IMapleProxyFactory
    - defaultVersion() (external)
    - mapleGlobals() (external)
    - upgradeEnabledForPath(uint256,uint256) (external)
  - From MapleProxyFactory
    - constructor(address) (public)
    - createInstance(bytes,bytes32) (public)
    - defaultImplementation() (external)
    - disableUpgradePath(uint256,uint256) (public)
    - enableUpgradePath(uint256,uint256,address) (public)
    - getInstanceAddress(bytes,bytes32) (public)
    - implementationOf(uint256) (public)
    - migratorForPath(uint256,uint256) (public)
    - registerImplementation(uint256,address,address) (public)
    - setDefaultVersion(uint256) (public)
    - setGlobals(address) (public)
    - upgradeInstance(uint256,bytes) (public)
    - versionOf(address) (public)

+ Contract IMapleProxied (Most derived contract)
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)

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

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - governor() (external)

+ Contract Proxy (Upgradeable Proxy) (Most derived contract)
  - From SlotManipulatable
    - _getReferenceTypeSlot(bytes32,bytes32) (internal)
    - _getSlotValue(bytes32) (internal)
    - _setSlotValue(bytes32,bytes32) (internal)
  - From Proxy
    - constructor(address,address) (public)
    - fallback() (external)

+ Contract ProxyFactory (Upgradeable Proxy)
  - From ProxyFactory
    - _getDeterministicProxyAddress(bytes32) (internal)
    - _getImplementationOfProxy(address) (private)
    - _initializeInstance(address,uint256,bytes) (private)
    - _isContract(address) (internal)
    - _newInstance(bytes,bytes32) (internal)
    - _newInstance(uint256,bytes) (internal)
    - _registerImplementation(uint256,address) (internal)
    - _registerMigrator(uint256,uint256,address) (internal)
    - _upgradeInstance(address,uint256,bytes) (internal)

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

modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol analyzed (14 contracts)
