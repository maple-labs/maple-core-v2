
Contract MapleGlobals
Contract vars: ['ADMIN_SLOT', 'IMPLEMENTATION_SLOT', 'HUNDRED_PERCENT', 'mapleTreasury', 'migrationAdmin', 'pendingGovernor', 'securityAdmin', 'protocolPaused', 'defaultTimelockParameters', 'oracleFor', 'isBorrower', 'isPoolAsset', 'isPoolDeployer', 'manualOverridePrice', 'maxCoverLiquidationPercent', 'minCoverAmount', 'platformManagementFeeRate', 'platformOriginationFeeRate', 'platformServiceFeeRate', 'timelockParametersOf', 'isFactory', 'scheduledCalls', 'poolDelegates']
Inheritance:: ['NonTransparentProxied', 'INonTransparentProxied', 'IMapleGlobals']
 
+-----------------------------------------------------------+------------+----------------+-------------------------------------------------+-----------------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------+
|                          Function                         | Visibility |   Modifiers    |                       Read                      |               Write               |             Internal Calls             |                                            External Calls                                           |
+-----------------------------------------------------------+------------+----------------+-------------------------------------------------+-----------------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------+
|                          admin()                          |   public   |       []       |                  ['ADMIN_SLOT']                 |                 []                |            ['_getAddress']             |                                                  []                                                 |
|                      implementation()                     |   public   |       []       |             ['IMPLEMENTATION_SLOT']             |                 []                |            ['_getAddress']             |                                                  []                                                 |
|                    _getAddress(bytes32)                   |  private   |       []       |                        []                       |                 []                |           ['sload(uint256)']           |                                                  []                                                 |
|                          admin()                          |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                      implementation()                     |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                defaultTimelockParameters()                |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                    isBorrower(address)                    |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                 isFactory(bytes32,address)                |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                    isPoolAsset(address)                   |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                  isPoolDelegate(address)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                  isPoolDeployer(address)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                  getLatestPrice(address)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                         governor()                        |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                manualOverridePrice(address)               |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                      mapleTreasury()                      |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|            maxCoverLiquidationPercent(address)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                      migrationAdmin()                     |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                  minCoverAmount(address)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                     oracleFor(address)                    |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                 ownedPoolManager(address)                 |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                     pendingGovernor()                     |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|             platformManagementFeeRate(address)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|            platformOriginationFeeRate(address)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|              platformServiceFeeRate(address)              |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                   poolDelegates(address)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                      protocolPaused()                     |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|          scheduledCalls(address,address,bytes32)          |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                      securityAdmin()                      |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|           timelockParametersOf(address,bytes32)           |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                activatePoolManager(address)               |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                 setMapleTreasury(address)                 |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                 setMigrationAdmin(address)                |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|              setPriceOracle(address,address)              |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                 setSecurityAdmin(address)                 |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|       setDefaultTimelockParameters(uint128,uint128)       |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                   setProtocolPause(bool)                  |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|               setValidBorrower(address,bool)              |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|           setValidFactory(bytes32,address,bool)           |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|              setValidPoolAsset(address,bool)              |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|             setValidPoolDelegate(address,bool)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|             setValidPoolDeployer(address,bool)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|          setManualOverridePrice(address,uint256)          |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|       setMaxCoverLiquidationPercent(address,uint256)      |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|             setMinCoverAmount(address,uint256)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|       setPlatformManagementFeeRate(address,uint256)       |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|       setPlatformOriginationFeeRate(address,uint256)      |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|         setPlatformServiceFeeRate(address,uint256)        |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|     setTimelockWindow(address,bytes32,uint128,uint128)    |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
| setTimelockWindows(address,bytes32[],uint128[],uint128[]) |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|         transferOwnedPoolManager(address,address)         |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|            scheduleCall(address,bytes32,bytes)            |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|           unscheduleCall(address,bytes32,bytes)           |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|       unscheduleCall(address,address,bytes32,bytes)       |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|    isValidScheduledCall(address,address,bytes32,bytes)    |  external  |       []       |                        []                       |                 []                |                   []                   |                                                  []                                                 |
|                constructor(uint128,uint128)               |   public   |       []       |                        []                       |   ['defaultTimelockParameters']   |                   []                   |                                                  []                                                 |
|                      acceptGovernor()                     |  external  |       []       |        ['ADMIN_SLOT', 'pendingGovernor']        |        ['pendingGovernor']        |        ['_setAddress', 'admin']        |                                                  []                                                 |
|                                                           |            |                |                  ['msg.sender']                 |                                   |        ['require(bool,string)']        |                                                                                                     |
|                setPendingGovernor(address)                |  external  | ['isGovernor'] |               ['pendingGovernor']               |        ['pendingGovernor']        |             ['isGovernor']             |                                                  []                                                 |
|                activatePoolManager(address)               |  external  | ['isGovernor'] |                ['poolDelegates']                |         ['poolDelegates']         |             ['isGovernor']             | ['IPoolManagerLike(poolManager_).poolDelegate()', 'IPoolManagerLike(poolManager_).setActive(true)'] |
|                 setMapleTreasury(address)                 |  external  | ['isGovernor'] |                ['mapleTreasury']                |         ['mapleTreasury']         | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|                 setMigrationAdmin(address)                |  external  | ['isGovernor'] |                ['migrationAdmin']               |         ['migrationAdmin']        | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|              setPriceOracle(address,address)              |  external  | ['isGovernor'] |                        []                       |           ['oracleFor']           |             ['isGovernor']             |                                                  []                                                 |
|                 setSecurityAdmin(address)                 |  external  | ['isGovernor'] |                ['securityAdmin']                |         ['securityAdmin']         | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|       setDefaultTimelockParameters(uint128,uint128)       |  external  | ['isGovernor'] |          ['defaultTimelockParameters']          |   ['defaultTimelockParameters']   |             ['isGovernor']             |                                                  []                                                 |
|                   setProtocolPause(bool)                  |  external  |       []       |         ['securityAdmin', 'msg.sender']         |         ['protocolPaused']        |        ['require(bool,string)']        |                                                  []                                                 |
|               setValidBorrower(address,bool)              |  external  | ['isGovernor'] |                        []                       |           ['isBorrower']          |             ['isGovernor']             |                                                  []                                                 |
|           setValidFactory(bytes32,address,bool)           |  external  | ['isGovernor'] |                        []                       |           ['isFactory']           |             ['isGovernor']             |                                                  []                                                 |
|              setValidPoolAsset(address,bool)              |  external  | ['isGovernor'] |                        []                       |          ['isPoolAsset']          |             ['isGovernor']             |                                                  []                                                 |
|             setValidPoolDelegate(address,bool)            |  external  | ['isGovernor'] |                ['poolDelegates']                |         ['poolDelegates']         | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|             setValidPoolDeployer(address,bool)            |  external  | ['isGovernor'] |                        []                       |         ['isPoolDeployer']        |             ['isGovernor']             |                                                  []                                                 |
|          setManualOverridePrice(address,uint256)          |  external  | ['isGovernor'] |                        []                       |      ['manualOverridePrice']      |             ['isGovernor']             |                                                  []                                                 |
|             setMinCoverAmount(address,uint256)            |  external  | ['isGovernor'] |                        []                       |         ['minCoverAmount']        |             ['isGovernor']             |                                                  []                                                 |
|       setMaxCoverLiquidationPercent(address,uint256)      |  external  | ['isGovernor'] |               ['HUNDRED_PERCENT']               |   ['maxCoverLiquidationPercent']  | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|       setPlatformManagementFeeRate(address,uint256)       |  external  | ['isGovernor'] |               ['HUNDRED_PERCENT']               |   ['platformManagementFeeRate']   | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|       setPlatformOriginationFeeRate(address,uint256)      |  external  | ['isGovernor'] |               ['HUNDRED_PERCENT']               |   ['platformOriginationFeeRate']  | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|         setPlatformServiceFeeRate(address,uint256)        |  external  | ['isGovernor'] |               ['HUNDRED_PERCENT']               |     ['platformServiceFeeRate']    | ['isGovernor', 'require(bool,string)'] |                                                  []                                                 |
|     setTimelockWindow(address,bytes32,uint128,uint128)    |   public   | ['isGovernor'] |                        []                       |      ['timelockParametersOf']     |             ['isGovernor']             |                                                  []                                                 |
| setTimelockWindows(address,bytes32[],uint128[],uint128[]) |   public   | ['isGovernor'] |                        []                       |                 []                |  ['setTimelockWindow', 'isGovernor']   |                                                  []                                                 |
|         transferOwnedPoolManager(address,address)         |  external  |       []       |         ['poolDelegates', 'msg.sender']         |         ['poolDelegates']         |        ['require(bool,string)']        |                                                  []                                                 |
|            scheduleCall(address,bytes32,bytes)            |  external  |       []       |        ['block.timestamp', 'msg.sender']        |         ['scheduledCalls']        |  ['keccak256(bytes)', 'abi.encode()']  |                                      ['abi.encode(callData_)']                                      |
|           unscheduleCall(address,bytes32,bytes)           |  external  |       []       |      ['scheduledCalls', 'block.timestamp']      |         ['scheduledCalls']        |  ['keccak256(bytes)', 'abi.encode()']  |                                      ['abi.encode(callData_)']                                      |
|                                                           |            |                |                  ['msg.sender']                 |                                   |                                        |                                                                                                     |
|       unscheduleCall(address,address,bytes32,bytes)       |  external  | ['isGovernor'] |      ['scheduledCalls', 'block.timestamp']      |         ['scheduledCalls']        |  ['keccak256(bytes)', 'abi.encode()']  |                                      ['abi.encode(callData_)']                                      |
|                                                           |            |                |                                                 |                                   |             ['isGovernor']             |                                                                                                     |
|    isValidScheduledCall(address,address,bytes32,bytes)    |   public   |       []       | ['defaultTimelockParameters', 'scheduledCalls'] |                 []                |  ['keccak256(bytes)', 'abi.encode()']  |                                      ['abi.encode(callData_)']                                      |
|                                                           |            |                |   ['timelockParametersOf', 'block.timestamp']   |                                   |                                        |                                                                                                     |
|                  getLatestPrice(address)                  |  external  |       []       |       ['manualOverridePrice', 'oracleFor']      |                 []                |        ['require(bool,string)']        |                 ['IChainlinkAggregatorV3Like(oracleFor[asset_]).latestRoundData()']                 |
|                         governor()                        |  external  |       []       |                        []                       |                 []                |               ['admin']                |                                                  []                                                 |
|                  isPoolDelegate(address)                  |  external  |       []       |                ['poolDelegates']                |                 []                |                   []                   |                                                  []                                                 |
|                 ownedPoolManager(address)                 |  external  |       []       |                ['poolDelegates']                |                 []                |                   []                   |                                                  []                                                 |
|                _setAddress(bytes32,address)               |  private   |       []       |                        []                       |                 []                |      ['sstore(uint256,uint256)']       |                                                  []                                                 |
|           slitherConstructorConstantVariables()           |  internal  |       []       |                        []                       | ['ADMIN_SLOT', 'HUNDRED_PERCENT'] |          ['keccak256(bytes)']          |                                                  []                                                 |
|                                                           |            |                |                                                 |      ['IMPLEMENTATION_SLOT']      |                                        |                                                                                                     |
+-----------------------------------------------------------+------------+----------------+-------------------------------------------------+-----------------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------+

+--------------+------------+----------------+-------+-----------------------------------+----------------+
|  Modifiers   | Visibility |      Read      | Write |           Internal Calls          | External Calls |
+--------------+------------+----------------+-------+-----------------------------------+----------------+
| isGovernor() |  internal  | ['msg.sender'] |   []  | ['admin', 'require(bool,string)'] |       []       |
+--------------+------------+----------------+-------+-----------------------------------+----------------+


Contract IMapleGlobals
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                          Function                         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                defaultTimelockParameters()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                    isBorrower(address)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isFactory(bytes32,address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                    isPoolAsset(address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isPoolDelegate(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isPoolDeployer(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                  getLatestPrice(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                         governor()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                manualOverridePrice(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      mapleTreasury()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|            maxCoverLiquidationPercent(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|                      migrationAdmin()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                  minCoverAmount(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                     oracleFor(address)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                 ownedPoolManager(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                     pendingGovernor()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|             platformManagementFeeRate(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|            platformOriginationFeeRate(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|              platformServiceFeeRate(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   poolDelegates(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                      protocolPaused()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|          scheduledCalls(address,address,bytes32)          |  external  |     []    |  []  |   []  |       []       |       []       |
|                      securityAdmin()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|           timelockParametersOf(address,bytes32)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                activatePoolManager(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                 setMapleTreasury(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                 setMigrationAdmin(address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|              setPriceOracle(address,address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                 setSecurityAdmin(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|       setDefaultTimelockParameters(uint128,uint128)       |  external  |     []    |  []  |   []  |       []       |       []       |
|                   setProtocolPause(bool)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|               setValidBorrower(address,bool)              |  external  |     []    |  []  |   []  |       []       |       []       |
|           setValidFactory(bytes32,address,bool)           |  external  |     []    |  []  |   []  |       []       |       []       |
|              setValidPoolAsset(address,bool)              |  external  |     []    |  []  |   []  |       []       |       []       |
|             setValidPoolDelegate(address,bool)            |  external  |     []    |  []  |   []  |       []       |       []       |
|             setValidPoolDeployer(address,bool)            |  external  |     []    |  []  |   []  |       []       |       []       |
|          setManualOverridePrice(address,uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|       setMaxCoverLiquidationPercent(address,uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|             setMinCoverAmount(address,uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|       setPlatformManagementFeeRate(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       setPlatformOriginationFeeRate(address,uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|         setPlatformServiceFeeRate(address,uint256)        |  external  |     []    |  []  |   []  |       []       |       []       |
|     setTimelockWindow(address,bytes32,uint128,uint128)    |  external  |     []    |  []  |   []  |       []       |       []       |
| setTimelockWindows(address,bytes32[],uint128[],uint128[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|         transferOwnedPoolManager(address,address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|            scheduleCall(address,bytes32,bytes)            |  external  |     []    |  []  |   []  |       []       |       []       |
|           unscheduleCall(address,bytes32,bytes)           |  external  |     []    |  []  |   []  |       []       |       []       |
|       unscheduleCall(address,address,bytes32,bytes)       |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidScheduledCall(address,address,bytes32,bytes)    |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IChainlinkAggregatorV3Like
Contract vars: []
Inheritance:: []
 
+-------------------+------------+-----------+------+-------+----------------+----------------+
|      Function     | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------+------------+-----------+------+-------+----------------+----------------+
| latestRoundData() |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: []
 
+-----------+------------+-----------+------+-------+----------------+----------------+
|  Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------+------------+-----------+------+-------+----------------+----------------+
| manager() |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+-----------------+------------+-----------+------+-------+----------------+----------------+
|     Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------+------------+-----------+------+-------+----------------+----------------+
|  poolDelegate() |  external  |     []    |  []  |   []  |       []       |       []       |
| setActive(bool) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract NonTransparentProxied
Contract vars: ['ADMIN_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['INonTransparentProxied']
 
+---------------------------------------+------------+-----------+-------------------------+---------------------------------------+----------------------+----------------+
|                Function               | Visibility | Modifiers |           Read          |                 Write                 |    Internal Calls    | External Calls |
+---------------------------------------+------------+-----------+-------------------------+---------------------------------------+----------------------+----------------+
|                admin()                |  external  |     []    |            []           |                   []                  |          []          |       []       |
|            implementation()           |  external  |     []    |            []           |                   []                  |          []          |       []       |
|                admin()                |   public   |     []    |      ['ADMIN_SLOT']     |                   []                  |   ['_getAddress']    |       []       |
|            implementation()           |   public   |     []    | ['IMPLEMENTATION_SLOT'] |                   []                  |   ['_getAddress']    |       []       |
|          _getAddress(bytes32)         |  private   |     []    |            []           |                   []                  |  ['sload(uint256)']  |       []       |
| slitherConstructorConstantVariables() |  internal  |     []    |            []           | ['ADMIN_SLOT', 'IMPLEMENTATION_SLOT'] | ['keccak256(bytes)'] |       []       |
+---------------------------------------+------------+-----------+-------------------------+---------------------------------------+----------------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract INonTransparentProxied
Contract vars: []
Inheritance:: []
 
+------------------+------------+-----------+------+-------+----------------+----------------+
|     Function     | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------+------------+-----------+------+-------+----------------+----------------+
|     admin()      |  external  |     []    |  []  |   []  |       []       |       []       |
| implementation() |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/globals-v2/contracts/MapleGlobals.sol analyzed (7 contracts)
