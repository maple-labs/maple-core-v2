
DebtLockerInitializer:
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

modules/debt-locker-v4/contracts/DebtLockerInitializer.sol analyzed (10 contracts)
