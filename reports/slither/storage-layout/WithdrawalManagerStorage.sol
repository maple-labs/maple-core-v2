
WithdrawalManagerStorage:
+-------------------------------------------+----------------------------------------------------------+------+--------+
|                    Name                   |                           Type                           | Slot | Offset |
+-------------------------------------------+----------------------------------------------------------+------+--------+
|       WithdrawalManagerStorage.pool       |                         address                          |  0   |   0    |
|    WithdrawalManagerStorage.poolManager   |                         address                          |  1   |   0    |
|  WithdrawalManagerStorage.latestConfigId  |                         uint256                          |  2   |   0    |
|    WithdrawalManagerStorage.exitCycleId   |               mapping(address => uint256)                |  3   |   0    |
|   WithdrawalManagerStorage.lockedShares   |               mapping(address => uint256)                |  4   |   0    |
| WithdrawalManagerStorage.totalCycleShares |               mapping(uint256 => uint256)                |  5   |   0    |
|   WithdrawalManagerStorage.cycleConfigs   | mapping(uint256 => WithdrawalManagerStorage.CycleConfig) |  6   |   0    |
+-------------------------------------------+----------------------------------------------------------+------+--------+

modules/withdrawal-manager/contracts/WithdrawalManagerStorage.sol analyzed (2 contracts)
