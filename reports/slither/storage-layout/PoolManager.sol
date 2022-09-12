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



PoolManager:
+----------------------------------------------+-----------------------------+------+--------+
|                     Name                     |             Type            | Slot | Offset |
+----------------------------------------------+-----------------------------+------+--------+
|          PoolManagerStorage._locked          |           uint256           |  0   |   0    |
|       PoolManagerStorage.poolDelegate        |           address           |  1   |   0    |
|    PoolManagerStorage.pendingPoolDelegate    |           address           |  2   |   0    |
|           PoolManagerStorage.asset           |           address           |  3   |   0    |
|           PoolManagerStorage.pool            |           address           |  4   |   0    |
|     PoolManagerStorage.poolDelegateCover     |           address           |  5   |   0    |
|     PoolManagerStorage.withdrawalManager     |           address           |  6   |   0    |
|          PoolManagerStorage.active           |             bool            |  6   |   20   |
|        PoolManagerStorage.configured         |             bool            |  6   |   21   |
|       PoolManagerStorage.openToPublic        |             bool            |  6   |   22   |
|       PoolManagerStorage.liquidityCap        |           uint256           |  7   |   0    |
| PoolManagerStorage.delegateManagementFeeRate |           uint256           |  8   |   0    |
|       PoolManagerStorage.loanManagers        | mapping(address => address) |  9   |   0    |
|       PoolManagerStorage.isLoanManager       |   mapping(address => bool)  |  10  |   0    |
|       PoolManagerStorage.isValidLender       |   mapping(address => bool)  |  11  |   0    |
|      PoolManagerStorage.loanManagerList      |          address[]          |  12  |   0    |
+----------------------------------------------+-----------------------------+------+--------+

ILoanManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanManagerInitializerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILiquidatorLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanV3Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleLoanFeeManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleProxyFactoryLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolDelegateCoverLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IWithdrawalManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ERC20Helper:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleProxyFactory:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

modules/pool-v2/contracts/PoolManager.sol analyzed (26 contracts)
