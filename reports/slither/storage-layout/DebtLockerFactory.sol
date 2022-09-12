
DebtLockerFactory:
+-----------------------------------------+-------------------------------------------------+------+--------+
|                   Name                  |                       Type                      | Slot | Offset |
+-----------------------------------------+-------------------------------------------------+------+--------+
|      ProxyFactory._implementationOf     |           mapping(uint256 => address)           |  0   |   0    |
|         ProxyFactory._versionOf         |           mapping(address => uint256)           |  1   |   0    |
|      ProxyFactory._migratorForPath      | mapping(uint256 => mapping(uint256 => address)) |  2   |   0    |
|      MapleProxyFactory.mapleGlobals     |                     address                     |  3   |   0    |
|     MapleProxyFactory.defaultVersion    |                     uint256                     |  4   |   0    |
| MapleProxyFactory.upgradeEnabledForPath |   mapping(uint256 => mapping(uint256 => bool))  |  5   |   0    |
+-----------------------------------------+-------------------------------------------------+------+--------+

IMapleProxied:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

Proxy:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

modules/debt-locker-v4/contracts/DebtLockerFactory.sol analyzed (11 contracts)
