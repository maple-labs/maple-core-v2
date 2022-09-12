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



DebtLocker:
+--------------------------------------------------+---------+------+--------+
|                       Name                       |   Type  | Slot | Offset |
+--------------------------------------------------+---------+------+--------+
|          DebtLockerStorage._liquidator           | address |  0   |   0    |
|             DebtLockerStorage._loan              | address |  1   |   0    |
|             DebtLockerStorage._pool              | address |  2   |   0    |
|          DebtLockerStorage._repossessed          |   bool  |  2   |   20   |
|        DebtLockerStorage._allowedSlippage        | uint256 |  3   |   0    |
|        DebtLockerStorage._amountRecovered        | uint256 |  4   |   0    |
|        DebtLockerStorage._fundsToCapture         | uint256 |  5   |   0    |
|           DebtLockerStorage._minRatio            | uint256 |  6   |   0    |
| DebtLockerStorage._principalRemainingAtLastClaim | uint256 |  7   |   0    |
|         DebtLockerStorage._loanMigrator          | address |  8   |   0    |
+--------------------------------------------------+---------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILiquidatorLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleLoanLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolFactoryLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IUniswapRouterLike:
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

Liquidator:
+----------------------------+---------+------+--------+
|            Name            |   Type  | Slot | Offset |
+----------------------------+---------+------+--------+
|     Liquidator._locked     | uint256 |  0   |   0    |
| Liquidator.collateralAsset | address |  1   |   0    |
|   Liquidator.destination   | address |  2   |   0    |
|   Liquidator.fundsAsset    | address |  3   |   0    |
|     Liquidator.globals     | address |  4   |   0    |
|      Liquidator.owner      | address |  5   |   0    |
|   Liquidator.auctioneer    | address |  6   |   0    |
+----------------------------+---------+------+--------+

IAuctioneerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILiquidatorLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IOracleLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IUniswapRouterLike:
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

modules/debt-locker-v4/contracts/DebtLocker.sol analyzed (29 contracts)
