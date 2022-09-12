
Contract WithdrawalManagerInitializer
Contract vars: ['pool', 'poolManager', 'latestConfigId', 'exitCycleId', 'lockedShares', 'totalCycleShares', 'cycleConfigs', 'FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'WithdrawalManagerStorage', 'IWithdrawalManagerStorage']
 
+----------------------------------------+------------+-----------+---------------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------------------------------------------------+
|                Function                | Visibility | Modifiers |               Read              |                  Write                  |               Internal Calls               |                                  External Calls                                  |
+----------------------------------------+------------+-----------+---------------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------------------------------------------------+
|        _migrate(address,bytes)         |  internal  |     []    |                []               |                    []                   |                     []                     |                      ['migrator_.delegatecall(arguments_)']                      |
|          _setFactory(address)          |  internal  |     []    |         ['FACTORY_SLOT']        |                    []                   |             ['_setSlotValue']              |                                        []                                        |
|      _setImplementation(address)       |  internal  |     []    |     ['IMPLEMENTATION_SLOT']     |                    []                   |             ['_setSlotValue']              |                                        []                                        |
|               _factory()               |  internal  |     []    |         ['FACTORY_SLOT']        |                    []                   |             ['_getSlotValue']              |                                        []                                        |
|           _implementation()            |  internal  |     []    |     ['IMPLEMENTATION_SLOT']     |                    []                   |             ['_getSlotValue']              |                                        []                                        |
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |                []               |                    []                   | ['keccak256(bytes)', 'abi.encodePacked()'] |                         ['abi.encodePacked(key_,slot_)']                         |
|         _getSlotValue(bytes32)         |  internal  |     []    |                []               |                    []                   |             ['sload(uint256)']             |                                        []                                        |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |                []               |                    []                   |        ['sstore(uint256,uint256)']         |                                        []                                        |
|         cycleConfigs(uint256)          |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|          exitCycleId(address)          |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|            latestConfigId()            |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|         lockedShares(address)          |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|                 pool()                 |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|             poolManager()              |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|       totalCycleShares(uint256)        |  external  |     []    |                []               |                    []                   |                     []                     |                                        []                                        |
|               fallback()               |  external  |     []    | ['block.timestamp', 'msg.data'] |         ['cycleConfigs', 'pool']        |  ['require(bool,string)', 'abi.decode()']  | ['abi.decode(msg.data,(address,uint256,uint256))', 'IPoolLike(pool_).manager()'] |
|                                        |            |           |                                 |             ['poolManager']             |                                            |                                                                                  |
| slitherConstructorConstantVariables()  |  internal  |     []    |                []               | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                                        []                                        |
+----------------------------------------+------------+-----------+---------------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------------------------------------------------+

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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['keccak256(bytes)', 'abi.encodePacked()'] |    ['abi.encodePacked(key_,slot_)']    |
|         _getSlotValue(bytes32)         |  internal  |     []    |            []           |                    []                   |             ['sload(uint256)']             |                   []                   |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |            []           |                    []                   |        ['sstore(uint256,uint256)']         |                   []                   |
| slitherConstructorConstantVariables()  |  internal  |     []    |            []           | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                   []                   |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+

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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['keccak256(bytes)', 'abi.encodePacked()'] |    ['abi.encodePacked(key_,slot_)']    |
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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |  []  |   []  | ['keccak256(bytes)', 'abi.encodePacked()'] | ['abi.encodePacked(key_,slot_)'] |
|         _getSlotValue(bytes32)         |  internal  |     []    |  []  |   []  |             ['sload(uint256)']             |                []                |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |  []  |   []  |        ['sstore(uint256,uint256)']         |                []                |
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol analyzed (10 contracts)
