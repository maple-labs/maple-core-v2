
DebtLockerStorage:
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

modules/debt-locker-v4/contracts/DebtLockerStorage.sol analyzed (1 contracts)
