
MapleGlobals:
+-----------------------------------------+----------------------------------------------------------------------------------------+------+--------+
|                   Name                  |                                          Type                                          | Slot | Offset |
+-----------------------------------------+----------------------------------------------------------------------------------------+------+--------+
|        MapleGlobals.mapleTreasury       |                                        address                                         |  0   |   0    |
|       MapleGlobals.migrationAdmin       |                                        address                                         |  1   |   0    |
|       MapleGlobals.pendingGovernor      |                                        address                                         |  2   |   0    |
|        MapleGlobals.securityAdmin       |                                        address                                         |  3   |   0    |
|       MapleGlobals.protocolPaused       |                                          bool                                          |  3   |   20   |
|  MapleGlobals.defaultTimelockParameters |                            MapleGlobals.TimelockParameters                             |  4   |   0    |
|          MapleGlobals.oracleFor         |                              mapping(address => address)                               |  5   |   0    |
|         MapleGlobals.isBorrower         |                                mapping(address => bool)                                |  6   |   0    |
|         MapleGlobals.isPoolAsset        |                                mapping(address => bool)                                |  7   |   0    |
|       MapleGlobals.isPoolDeployer       |                                mapping(address => bool)                                |  8   |   0    |
|     MapleGlobals.manualOverridePrice    |                              mapping(address => uint256)                               |  9   |   0    |
| MapleGlobals.maxCoverLiquidationPercent |                              mapping(address => uint256)                               |  10  |   0    |
|       MapleGlobals.minCoverAmount       |                              mapping(address => uint256)                               |  11  |   0    |
|  MapleGlobals.platformManagementFeeRate |                              mapping(address => uint256)                               |  12  |   0    |
| MapleGlobals.platformOriginationFeeRate |                              mapping(address => uint256)                               |  13  |   0    |
|   MapleGlobals.platformServiceFeeRate   |                              mapping(address => uint256)                               |  14  |   0    |
|    MapleGlobals.timelockParametersOf    |        mapping(address => mapping(bytes32 => MapleGlobals.TimelockParameters))         |  15  |   0    |
|          MapleGlobals.isFactory         |                      mapping(bytes32 => mapping(address => bool))                      |  16  |   0    |
|       MapleGlobals.scheduledCalls       | mapping(address => mapping(address => mapping(bytes32 => MapleGlobals.ScheduledCall))) |  17  |   0    |
|        MapleGlobals.poolDelegates       |                     mapping(address => MapleGlobals.PoolDelegate)                      |  18  |   0    |
+-----------------------------------------+----------------------------------------------------------------------------------------+------+--------+

IChainlinkAggregatorV3Like:
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

modules/globals-v2/contracts/MapleGlobals.sol analyzed (7 contracts)
