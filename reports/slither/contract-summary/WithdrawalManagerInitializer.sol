
+ Contract WithdrawalManagerInitializer (Most derived contract)
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
  - From WithdrawalManagerInitializer
    - fallback() (external)

+ Contract WithdrawalManagerStorage
  - From IWithdrawalManagerStorage
    - cycleConfigs(uint256) (external)
    - exitCycleId(address) (external)
    - latestConfigId() (external)
    - lockedShares(address) (external)
    - pool() (external)
    - poolManager() (external)
    - totalCycleShares(uint256) (external)

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

modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol analyzed (10 contracts)
