
+ Contract WithdrawalManager (Most derived contract)
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
  - From IWithdrawalManagerStorage
    - cycleConfigs(uint256) (external)
    - exitCycleId(address) (external)
    - latestConfigId() (external)
    - lockedShares(address) (external)
    - pool() (external)
    - poolManager() (external)
    - totalCycleShares(uint256) (external)
  - From WithdrawalManager
    - _getConfigAtId(uint256) (internal)
    - _getCurrentConfig() (internal)
    - _getCurrentCycleId(WithdrawalManagerStorage.CycleConfig) (internal)
    - _getRedeemableAmounts(uint256,address) (internal)
    - _getWindowStart(WithdrawalManagerStorage.CycleConfig,uint256) (internal)
    - _previewRedeem(address,uint256,uint256,WithdrawalManagerStorage.CycleConfig) (internal)
    - addShares(uint256,address) (external)
    - asset() (public)
    - factory() (external)
    - globals() (public)
    - governor() (public)
    - implementation() (external)
    - isInExitWindow(address) (external)
    - lockedLiquidity() (external)
    - migrate(address,bytes) (external)
    - poolDelegate() (public)
    - previewRedeem(address,uint256) (external)
    - processExit(address,uint256) (external)
    - removeShares(uint256,address) (external)
    - setExitConfig(uint256,uint256) (external)
    - setImplementation(address) (external)
    - upgrade(uint256,bytes) (external)

+ Contract WithdrawalManagerStorage
  - From IWithdrawalManagerStorage
    - cycleConfigs(uint256) (external)
    - exitCycleId(address) (external)
    - latestConfigId() (external)
    - lockedShares(address) (external)
    - pool() (external)
    - poolManager() (external)
    - totalCycleShares(uint256) (external)

+ Contract IWithdrawalManager
  - From IWithdrawalManagerStorage
    - cycleConfigs(uint256) (external)
    - exitCycleId(address) (external)
    - latestConfigId() (external)
    - lockedShares(address) (external)
    - pool() (external)
    - poolManager() (external)
    - totalCycleShares(uint256) (external)
  - From IMapleProxied
    - upgrade(uint256,bytes) (external)
  - From IProxied
    - factory() (external)
    - implementation() (external)
    - migrate(address,bytes) (external)
    - setImplementation(address) (external)
  - From IWithdrawalManager
    - addShares(uint256,address) (external)
    - asset() (external)
    - globals() (external)
    - governor() (external)
    - isInExitWindow(address) (external)
    - lockedLiquidity() (external)
    - poolDelegate() (external)
    - previewRedeem(address,uint256) (external)
    - processExit(address,uint256) (external)
    - removeShares(uint256,address) (external)
    - setExitConfig(uint256,uint256) (external)

+ Contract IWithdrawalManagerStorage
  - From IWithdrawalManagerStorage
    - cycleConfigs(uint256) (external)
    - exitCycleId(address) (external)
    - latestConfigId() (external)
    - lockedShares(address) (external)
    - pool() (external)
    - poolManager() (external)
    - totalCycleShares(uint256) (external)

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

modules/withdrawal-manager/contracts/WithdrawalManager.sol analyzed (17 contracts)
