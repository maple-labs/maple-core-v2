
Contract WithdrawalManager
Contract vars: ['pool', 'poolManager', 'latestConfigId', 'exitCycleId', 'lockedShares', 'totalCycleShares', 'cycleConfigs', 'FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'WithdrawalManagerStorage', 'IWithdrawalManager', 'IWithdrawalManagerStorage', 'IMapleProxied', 'IProxied']
 
+------------------------------------------------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
|                                   Function                                   | Visibility | Modifiers |                   Read                  |                  Write                  |                 Internal Calls                 |                                                              External Calls                                                             |
+------------------------------------------------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
|                           _migrate(address,bytes)                            |  internal  |     []    |                    []                   |                    []                   |                       []                       |                                                  ['migrator_.delegatecall(arguments_)']                                                 |
|                             _setFactory(address)                             |  internal  |     []    |             ['FACTORY_SLOT']            |                    []                   |               ['_setSlotValue']                |                                                                    []                                                                   |
|                         _setImplementation(address)                          |  internal  |     []    |         ['IMPLEMENTATION_SLOT']         |                    []                   |               ['_setSlotValue']                |                                                                    []                                                                   |
|                                  _factory()                                  |  internal  |     []    |             ['FACTORY_SLOT']            |                    []                   |               ['_getSlotValue']                |                                                                    []                                                                   |
|                              _implementation()                               |  internal  |     []    |         ['IMPLEMENTATION_SLOT']         |                    []                   |               ['_getSlotValue']                |                                                                    []                                                                   |
|                    _getReferenceTypeSlot(bytes32,bytes32)                    |  internal  |     []    |                    []                   |                    []                   |   ['abi.encodePacked()', 'keccak256(bytes)']   |                                                     ['abi.encodePacked(key_,slot_)']                                                    |
|                            _getSlotValue(bytes32)                            |  internal  |     []    |                    []                   |                    []                   |               ['sload(uint256)']               |                                                                    []                                                                   |
|                        _setSlotValue(bytes32,bytes32)                        |  internal  |     []    |                    []                   |                    []                   |          ['sstore(uint256,uint256)']           |                                                                    []                                                                   |
|                            cycleConfigs(uint256)                             |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                             exitCycleId(address)                             |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                               latestConfigId()                               |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                            lockedShares(address)                             |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                    pool()                                    |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                poolManager()                                 |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                          totalCycleShares(uint256)                           |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                          addShares(uint256,address)                          |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                         processExit(address,uint256)                         |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                        removeShares(uint256,address)                         |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                        setExitConfig(uint256,uint256)                        |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                   asset()                                    |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                  globals()                                   |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                  governor()                                  |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                           isInExitWindow(address)                            |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                              lockedLiquidity()                               |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                        previewRedeem(address,uint256)                        |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                poolDelegate()                                |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                            upgrade(uint256,bytes)                            |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                  factory()                                   |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                               implementation()                               |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                          setImplementation(address)                          |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                            migrate(address,bytes)                            |  external  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
|                            migrate(address,bytes)                            |  external  |     []    |              ['msg.sender']             |                    []                   |      ['_migrate', 'require(bool,string)']      |                                                                    []                                                                   |
|                                                                              |            |           |                                         |                                         |                  ['_factory']                  |                                                                                                                                         |
|                          setImplementation(address)                          |  external  |     []    |              ['msg.sender']             |                    []                   |      ['require(bool,string)', '_factory']      |                                                                    []                                                                   |
|                                                                              |            |           |                                         |                                         |             ['_setImplementation']             |                                                                                                                                         |
|                            upgrade(uint256,bytes)                            |  external  |     []    |        ['msg.data', 'msg.sender']       |                    []                   |            ['_factory', 'governor']            | ['mapleGlobals_.unscheduleCall(msg.sender,WM:UPGRADE,msg.data)', 'IMapleProxyFactory(_factory()).upgradeInstance(version_,arguments_)'] |
|                                                                              |            |           |                 ['this']                |                                         |      ['require(bool,string)', 'globals']       |                           ['mapleGlobals_.isValidScheduledCall(msg.sender,address(this),WM:UPGRADE,msg.data)']                          |
|                                                                              |            |           |                                         |                                         |                ['poolDelegate']                |                                                                                                                                         |
|                        setExitConfig(uint256,uint256)                        |  external  |     []    |    ['cycleConfigs', 'latestConfigId']   |    ['cycleConfigs', 'latestConfigId']   | ['require(bool,string)', '_getCurrentCycleId'] |                                                                    []                                                                   |
|                                                                              |            |           |    ['block.timestamp', 'msg.sender']    |                                         |      ['_getWindowStart', 'poolDelegate']       |                                                                                                                                         |
|                                                                              |            |           |                                         |                                         |             ['_getCurrentConfig']              |                                                                                                                                         |
|                          addShares(uint256,address)                          |  external  |     []    |     ['exitCycleId', 'lockedShares']     |     ['exitCycleId', 'lockedShares']     |     ['_getConfigAtId', '_getWindowStart']      |                                   ['ERC20Helper.transferFrom(pool,msg.sender,address(this),shares_)']                                   |
|                                                                              |            |           |         ['pool', 'poolManager']         |           ['totalCycleShares']          | ['require(bool,string)', '_getCurrentCycleId'] |                                                                                                                                         |
|                                                                              |            |           | ['totalCycleShares', 'block.timestamp'] |                                         |                                                |                                                                                                                                         |
|                                                                              |            |           |          ['msg.sender', 'this']         |                                         |                                                |                                                                                                                                         |
|                        removeShares(uint256,address)                         |  external  |     []    |     ['exitCycleId', 'lockedShares']     |     ['exitCycleId', 'lockedShares']     |     ['_getConfigAtId', '_getWindowStart']      |                                              ['ERC20Helper.transfer(pool,owner_,shares_)']                                              |
|                                                                              |            |           |         ['pool', 'poolManager']         |           ['totalCycleShares']          | ['require(bool,string)', '_getCurrentCycleId'] |                                                                                                                                         |
|                                                                              |            |           | ['totalCycleShares', 'block.timestamp'] |                                         |                                                |                                                                                                                                         |
|                                                                              |            |           |              ['msg.sender']             |                                         |                                                |                                                                                                                                         |
|                         processExit(address,uint256)                         |  external  |     []    |     ['exitCycleId', 'lockedShares']     |     ['exitCycleId', 'lockedShares']     |      ['_getConfigAtId', '_previewRedeem']      |                                        ['ERC20Helper.transfer(pool,account_,redeemableShares_)']                                        |
|                                                                              |            |           |         ['pool', 'poolManager']         |           ['totalCycleShares']          | ['require(bool,string)', '_getCurrentCycleId'] |                                                                                                                                         |
|                                                                              |            |           |    ['totalCycleShares', 'msg.sender']   |                                         |                                                |                                                                                                                                         |
|                           _getConfigAtId(uint256)                            |  internal  |     []    |    ['cycleConfigs', 'latestConfigId']   |                    []                   |                       []                       |                                                                    []                                                                   |
|                             _getCurrentConfig()                              |  internal  |     []    |    ['cycleConfigs', 'latestConfigId']   |                    []                   |                       []                       |                                                                    []                                                                   |
|                                                                              |            |           |           ['block.timestamp']           |                                         |                                                |                                                                                                                                         |
|           _getCurrentCycleId(WithdrawalManagerStorage.CycleConfig)           |  internal  |     []    |           ['block.timestamp']           |                    []                   |                       []                       |                                                                    []                                                                   |
|                    _getRedeemableAmounts(uint256,address)                    |  internal  |     []    |         ['exitCycleId', 'pool']         |                    []                   |                   ['asset']                    |                                   ['poolManager_.unrealizedLosses()', 'IPoolLike(pool).totalSupply()']                                  |
|                                                                              |            |           |   ['poolManager', 'totalCycleShares']   |                                         |                                                |                                  ['poolManager_.totalAssets()', 'IERC20Like(asset()).balanceOf(pool)']                                  |
|        _getWindowStart(WithdrawalManagerStorage.CycleConfig,uint256)         |  internal  |     []    |                    []                   |                    []                   |                       []                       |                                                                    []                                                                   |
| _previewRedeem(address,uint256,uint256,WithdrawalManagerStorage.CycleConfig) |  internal  |     []    |           ['block.timestamp']           |                    []                   |  ['_getWindowStart', 'require(bool,string)']   |                                                                    []                                                                   |
|                                                                              |            |           |                                         |                                         |           ['_getRedeemableAmounts']            |                                                                                                                                         |
|                                   asset()                                    |   public   |     []    |                 ['pool']                |                    []                   |                       []                       |                                                       ['IPoolLike(pool).asset()']                                                       |
|                                  factory()                                   |  external  |     []    |                    []                   |                    []                   |                  ['_factory']                  |                                                                    []                                                                   |
|                                  globals()                                   |   public   |     []    |                    []                   |                    []                   |                  ['_factory']                  |                                            ['IMapleProxyFactory(_factory()).mapleGlobals()']                                            |
|                                  governor()                                  |   public   |     []    |                    []                   |                    []                   |                  ['globals']                   |                                               ['IMapleGlobalsLike(globals()).governor()']                                               |
|                               implementation()                               |  external  |     []    |                    []                   |                    []                   |              ['_implementation']               |                                                                    []                                                                   |
|                           isInExitWindow(address)                            |  external  |     []    |    ['exitCycleId', 'block.timestamp']   |                    []                   |     ['_getConfigAtId', '_getWindowStart']      |                                                                    []                                                                   |
|                              lockedLiquidity()                               |  external  |     []    |         ['pool', 'poolManager']         |                    []                   |    ['_getWindowStart', '_getCurrentConfig']    |                                     ['poolManager_.totalAssets()', 'IPoolLike(pool).totalSupply()']                                     |
|                                                                              |            |           | ['totalCycleShares', 'block.timestamp'] |                                         |             ['_getCurrentCycleId']             |                                                   ['poolManager_.unrealizedLosses()']                                                   |
|                                poolDelegate()                                |   public   |     []    |             ['poolManager']             |                    []                   |                       []                       |                                             ['IPoolManagerLike(poolManager).poolDelegate()']                                            |
|                        previewRedeem(address,uint256)                        |  external  |     []    |     ['exitCycleId', 'lockedShares']     |                    []                   |      ['_getConfigAtId', '_previewRedeem']      |                                                                    []                                                                   |
|                                                                              |            |           |                                         |                                         |            ['require(bool,string)']            |                                                                                                                                         |
|                    slitherConstructorConstantVariables()                     |  internal  |     []    |                    []                   | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                       []                       |                                                                    []                                                                   |
+------------------------------------------------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract WithdrawalManagerStorage
Contract vars: ['pool', 'poolManager', 'latestConfigId', 'exitCycleId', 'lockedShares', 'totalCycleShares', 'cycleConfigs']
Inheritance:: ['IWithdrawalManagerStorage']
 
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|   cycleConfigs(uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    exitCycleId(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|      latestConfigId()     |  external  |     []    |  []  |   []  |       []       |       []       |
|   lockedShares(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|           pool()          |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolManager()       |  external  |     []    |  []  |   []  |       []       |       []       |
| totalCycleShares(uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IWithdrawalManager
Contract vars: []
Inheritance:: ['IWithdrawalManagerStorage', 'IMapleProxied', 'IProxied']
 
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|            Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|     cycleConfigs(uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|      exitCycleId(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|        latestConfigId()        |  external  |     []    |  []  |   []  |       []       |       []       |
|     lockedShares(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|             pool()             |  external  |     []    |  []  |   []  |       []       |       []       |
|         poolManager()          |  external  |     []    |  []  |   []  |       []       |       []       |
|   totalCycleShares(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|     upgrade(uint256,bytes)     |  external  |     []    |  []  |   []  |       []       |       []       |
|           factory()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        implementation()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   setImplementation(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|     migrate(address,bytes)     |  external  |     []    |  []  |   []  |       []       |       []       |
|   addShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|  processExit(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| removeShares(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
| setExitConfig(uint256,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|            asset()             |  external  |     []    |  []  |   []  |       []       |       []       |
|           globals()            |  external  |     []    |  []  |   []  |       []       |       []       |
|           governor()           |  external  |     []    |  []  |   []  |       []       |       []       |
|    isInExitWindow(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       lockedLiquidity()        |  external  |     []    |  []  |   []  |       []       |       []       |
| previewRedeem(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|         poolDelegate()         |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IWithdrawalManagerStorage
Contract vars: []
Inheritance:: []
 
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|   cycleConfigs(uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    exitCycleId(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|      latestConfigId()     |  external  |     []    |  []  |   []  |       []       |       []       |
|   lockedShares(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|           pool()          |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolManager()       |  external  |     []    |  []  |   []  |       []       |       []       |
| totalCycleShares(uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                       Function                      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                      governor()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDeployer(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
| isValidScheduledCall(address,address,bytes32,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|        unscheduleCall(address,bytes32,bytes)        |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+--------------------+------------+-----------+------+-------+----------------+----------------+
|      Function      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------+------------+-----------+------+-------+----------------+----------------+
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: []
 
+---------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------+------------+-----------+------+-------+----------------+----------------+
|             asset()             |  external  |     []    |  []  |   []  |       []       |       []       |
|     convertToShares(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|            manager()            |  external  |     []    |  []  |   []  |       []       |       []       |
|      previewRedeem(uint256)     |  external  |     []    |  []  |   []  |       []       |       []       |
| redeem(uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|          totalSupply()          |  external  |     []    |  []  |   []  |       []       |       []       |
|    transfer(address,uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+--------------------+------------+-----------+------+-------+----------------+----------------+
|      Function      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------+------------+-----------+------+-------+----------------+----------------+
|   poolDelegate()   |  external  |     []    |  []  |   []  |       []       |       []       |
|     globals()      |  external  |     []    |  []  |   []  |       []       |       []       |
|   totalAssets()    |  external  |     []    |  []  |   []  |       []       |       []       |
| unrealizedLosses() |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['abi.decode()', 'code(address)']   |                                               ['abi.decode(returnData,(bool))', 'token_.call(data_)']                                               |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                Function               | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|        approve(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       transfer(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| transferFrom(address,address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract MapleProxiedInternals
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['ProxiedInternals', 'SlotManipulatable']
 
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|                Function                | Visibility | Modifiers |           Read          |                  Write                  |               Internal Calls               |             External Calls             |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|        _migrate(address,bytes)         |  internal  |     []    |            []           |                    []                   |                     []                     | ['migrator_.delegatecall(arguments_)'] |
|          _setFactory(address)          |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_setSlotValue']              |                   []                   |
|      _setImplementation(address)       |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_setSlotValue']              |                   []                   |
|               _factory()               |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_getSlotValue']              |                   []                   |
|           _implementation()            |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_getSlotValue']              |                   []                   |
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['abi.encodePacked()', 'keccak256(bytes)'] |    ['abi.encodePacked(key_,slot_)']    |
|         _getSlotValue(bytes32)         |  internal  |     []    |            []           |                    []                   |             ['sload(uint256)']             |                   []                   |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |            []           |                    []                   |        ['sstore(uint256,uint256)']         |                   []                   |
| slitherConstructorConstantVariables()  |  internal  |     []    |            []           | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                   []                   |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxied
Contract vars: []
Inheritance:: ['IProxied']
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|         factory()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      implementation()      |  external  |     []    |  []  |   []  |       []       |       []       |
| setImplementation(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|   migrate(address,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
|   upgrade(uint256,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxyFactory
Contract vars: []
Inheritance:: ['IDefaultImplementationBeacon']
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|             defaultImplementation()             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 defaultVersion()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  mapleGlobals()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|      upgradeEnabledForPath(uint256,uint256)     |  external  |     []    |  []  |   []  |       []       |       []       |
|          createInstance(bytes,bytes32)          |  external  |     []    |  []  |   []  |       []       |       []       |
|    enableUpgradePath(uint256,uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|       disableUpgradePath(uint256,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| registerImplementation(uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|            setDefaultVersion(uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|               setGlobals(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|          upgradeInstance(uint256,bytes)         |  external  |     []    |  []  |   []  |       []       |       []       |
|        getInstanceAddress(bytes,bytes32)        |  external  |     []    |  []  |   []  |       []       |       []       |
|            implementationOf(uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|         migratorForPath(uint256,uint256)        |  external  |     []    |  []  |   []  |       []       |       []       |
|                versionOf(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ProxiedInternals
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['SlotManipulatable']
 
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|                Function                | Visibility | Modifiers |           Read          |                  Write                  |               Internal Calls               |             External Calls             |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['abi.encodePacked()', 'keccak256(bytes)'] |    ['abi.encodePacked(key_,slot_)']    |
|         _getSlotValue(bytes32)         |  internal  |     []    |            []           |                    []                   |             ['sload(uint256)']             |                   []                   |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |            []           |                    []                   |        ['sstore(uint256,uint256)']         |                   []                   |
|        _migrate(address,bytes)         |  internal  |     []    |            []           |                    []                   |                     []                     | ['migrator_.delegatecall(arguments_)'] |
|          _setFactory(address)          |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_setSlotValue']              |                   []                   |
|      _setImplementation(address)       |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_setSlotValue']              |                   []                   |
|               _factory()               |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_getSlotValue']              |                   []                   |
|           _implementation()            |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_getSlotValue']              |                   []                   |
| slitherConstructorConstantVariables()  |  internal  |     []    |            []           | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                   []                   |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract SlotManipulatable
Contract vars: []
Inheritance:: []
 
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+
|                Function                | Visibility | Modifiers | Read | Write |               Internal Calls               |          External Calls          |
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |  []  |   []  | ['abi.encodePacked()', 'keccak256(bytes)'] | ['abi.encodePacked(key_,slot_)'] |
|         _getSlotValue(bytes32)         |  internal  |     []    |  []  |   []  |             ['sload(uint256)']             |                []                |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |  []  |   []  |        ['sstore(uint256,uint256)']         |                []                |
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IDefaultImplementationBeacon
Contract vars: []
Inheritance:: []
 
+-------------------------+------------+-----------+------+-------+----------------+----------------+
|         Function        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------+------------+-----------+------+-------+----------------+----------------+
| defaultImplementation() |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IProxied
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|         factory()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      implementation()      |  external  |     []    |  []  |   []  |       []       |       []       |
| setImplementation(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|   migrate(address,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/withdrawal-manager/contracts/WithdrawalManager.sol analyzed (17 contracts)
