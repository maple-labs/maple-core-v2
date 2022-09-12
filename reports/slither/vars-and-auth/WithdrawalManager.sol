
Contract WithdrawalManager
+-------------------------------------+-----------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               Function              |               State variables written               |                                                                                                                        Conditions on msg.sender                                                                                                                        |
+-------------------------------------+-----------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               _migrate              |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             _setFactory             |                          []                         |                                                                                                                                   []                                                                                                                                   |
|          _setImplementation         |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               _factory              |                          []                         |                                                                                                                                   []                                                                                                                                   |
|           _implementation           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|        _getReferenceTypeSlot        |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            _getSlotValue            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            _setSlotValue            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             cycleConfigs            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             exitCycleId             |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            latestConfigId           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             lockedShares            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|                 pool                |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             poolManager             |                          []                         |                                                                                                                                   []                                                                                                                                   |
|           totalCycleShares          |                          []                         |                                                                                                                                   []                                                                                                                                   |
|              addShares              |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             processExit             |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             removeShares            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            setExitConfig            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|                asset                |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               globals               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               governor              |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            isInExitWindow           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|           lockedLiquidity           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            previewRedeem            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             poolDelegate            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               upgrade               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               factory               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            implementation           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|          setImplementation          |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               migrate               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               migrate               |                          []                         |                                                                                                  ['require(bool,string)(msg.sender == _factory(),WM:M:NOT_FACTORY)']                                                                                                   |
|          setImplementation          |                          []                         |                                                                                                  ['require(bool,string)(msg.sender == _factory(),WM:SI:NOT_FACTORY)']                                                                                                  |
|               upgrade               |                          []                         | ['require(bool,string)(msg.sender == poolDelegate_ || msg.sender == governor(),WM:U:NOT_AUTHORIZED)', 'msg.sender == poolDelegate_', 'require(bool,string)(mapleGlobals_.isValidScheduledCall(msg.sender,address(this),WM:UPGRADE,msg.data),WM:U:INVALID_SCHED_CALL)'] |
|            setExitConfig            |          ['latestConfigId', 'cycleConfigs']         |                                                                                              ['require(bool,string)(msg.sender == poolDelegate(),WM:SEC:NOT_AUTHORIZED)']                                                                                              |
|              addShares              | ['lockedShares', 'exitCycleId', 'totalCycleShares'] |                                      ['require(bool,string)(msg.sender == poolManager,WM:AS:NOT_POOL_MANAGER)', 'require(bool,string)(ERC20Helper.transferFrom(pool,msg.sender,address(this),shares_),WM:AS:TRANSFER_FROM_FAIL)']                                      |
|             removeShares            | ['lockedShares', 'exitCycleId', 'totalCycleShares'] |                                                                                               ['require(bool,string)(msg.sender == poolManager,WM:RS:NOT_POOL_MANAGER)']                                                                                               |
|             processExit             | ['lockedShares', 'exitCycleId', 'totalCycleShares'] |                                                                                                    ['require(bool,string)(msg.sender == poolManager,WM:PE:NOT_PM)']                                                                                                    |
|            _getConfigAtId           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|          _getCurrentConfig          |                          []                         |                                                                                                                                   []                                                                                                                                   |
|          _getCurrentCycleId         |                          []                         |                                                                                                                                   []                                                                                                                                   |
|        _getRedeemableAmounts        |                          []                         |                                                                                                                                   []                                                                                                                                   |
|           _getWindowStart           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            _previewRedeem           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|                asset                |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               factory               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               globals               |                          []                         |                                                                                                                                   []                                                                                                                                   |
|               governor              |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            implementation           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            isInExitWindow           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|           lockedLiquidity           |                          []                         |                                                                                                                                   []                                                                                                                                   |
|             poolDelegate            |                          []                         |                                                                                                                                   []                                                                                                                                   |
|            previewRedeem            |                          []                         |                                                                                                                                   []                                                                                                                                   |
| slitherConstructorConstantVariables |       ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']       |                                                                                                                                   []                                                                                                                                   |
+-------------------------------------+-----------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Contract WithdrawalManagerStorage
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   cycleConfigs   |            []           |            []            |
|   exitCycleId    |            []           |            []            |
|  latestConfigId  |            []           |            []            |
|   lockedShares   |            []           |            []            |
|       pool       |            []           |            []            |
|   poolManager    |            []           |            []            |
| totalCycleShares |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IWithdrawalManager
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|    cycleConfigs   |            []           |            []            |
|    exitCycleId    |            []           |            []            |
|   latestConfigId  |            []           |            []            |
|    lockedShares   |            []           |            []            |
|        pool       |            []           |            []            |
|    poolManager    |            []           |            []            |
|  totalCycleShares |            []           |            []            |
|      upgrade      |            []           |            []            |
|      factory      |            []           |            []            |
|   implementation  |            []           |            []            |
| setImplementation |            []           |            []            |
|      migrate      |            []           |            []            |
|     addShares     |            []           |            []            |
|    processExit    |            []           |            []            |
|    removeShares   |            []           |            []            |
|   setExitConfig   |            []           |            []            |
|       asset       |            []           |            []            |
|      globals      |            []           |            []            |
|      governor     |            []           |            []            |
|   isInExitWindow  |            []           |            []            |
|  lockedLiquidity  |            []           |            []            |
|   previewRedeem   |            []           |            []            |
|    poolDelegate   |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IWithdrawalManagerStorage
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   cycleConfigs   |            []           |            []            |
|   exitCycleId    |            []           |            []            |
|  latestConfigId  |            []           |            []            |
|   lockedShares   |            []           |            []            |
|       pool       |            []           |            []            |
|   poolManager    |            []           |            []            |
| totalCycleShares |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+----------------------+-------------------------+--------------------------+
|       Function       | State variables written | Conditions on msg.sender |
+----------------------+-------------------------+--------------------------+
|       governor       |            []           |            []            |
|    isPoolDeployer    |            []           |            []            |
| isValidScheduledCall |            []           |            []            |
|    unscheduleCall    |            []           |            []            |
+----------------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
| balanceOf |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract IPoolLike
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
|      asset      |            []           |            []            |
| convertToShares |            []           |            []            |
|     manager     |            []           |            []            |
|  previewRedeem  |            []           |            []            |
|      redeem     |            []           |            []            |
|   totalSupply   |            []           |            []            |
|     transfer    |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract IPoolManagerLike
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   poolDelegate   |            []           |            []            |
|     globals      |            []           |            []            |
|   totalAssets    |            []           |            []            |
| unrealizedLosses |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract ERC20Helper
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
|   transfer   |            []           |            []            |
| transferFrom |            []           |            []            |
|   approve    |            []           |            []            |
|    _call     |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract IERC20Like
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
|   approve    |            []           |            []            |
|   transfer   |            []           |            []            |
| transferFrom |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract MapleProxiedInternals
+-------------------------------------+-----------------------------------------+--------------------------+
|               Function              |         State variables written         | Conditions on msg.sender |
+-------------------------------------+-----------------------------------------+--------------------------+
|               _migrate              |                    []                   |            []            |
|             _setFactory             |                    []                   |            []            |
|          _setImplementation         |                    []                   |            []            |
|               _factory              |                    []                   |            []            |
|           _implementation           |                    []                   |            []            |
|        _getReferenceTypeSlot        |                    []                   |            []            |
|            _getSlotValue            |                    []                   |            []            |
|            _setSlotValue            |                    []                   |            []            |
| slitherConstructorConstantVariables | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract IMapleProxied
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|      factory      |            []           |            []            |
|   implementation  |            []           |            []            |
| setImplementation |            []           |            []            |
|      migrate      |            []           |            []            |
|      upgrade      |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IMapleProxyFactory
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
| defaultImplementation  |            []           |            []            |
|     defaultVersion     |            []           |            []            |
|      mapleGlobals      |            []           |            []            |
| upgradeEnabledForPath  |            []           |            []            |
|     createInstance     |            []           |            []            |
|   enableUpgradePath    |            []           |            []            |
|   disableUpgradePath   |            []           |            []            |
| registerImplementation |            []           |            []            |
|   setDefaultVersion    |            []           |            []            |
|       setGlobals       |            []           |            []            |
|    upgradeInstance     |            []           |            []            |
|   getInstanceAddress   |            []           |            []            |
|    implementationOf    |            []           |            []            |
|    migratorForPath     |            []           |            []            |
|       versionOf        |            []           |            []            |
+------------------------+-------------------------+--------------------------+

Contract ProxiedInternals
+-------------------------------------+-----------------------------------------+--------------------------+
|               Function              |         State variables written         | Conditions on msg.sender |
+-------------------------------------+-----------------------------------------+--------------------------+
|        _getReferenceTypeSlot        |                    []                   |            []            |
|            _getSlotValue            |                    []                   |            []            |
|            _setSlotValue            |                    []                   |            []            |
|               _migrate              |                    []                   |            []            |
|             _setFactory             |                    []                   |            []            |
|          _setImplementation         |                    []                   |            []            |
|               _factory              |                    []                   |            []            |
|           _implementation           |                    []                   |            []            |
| slitherConstructorConstantVariables | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract SlotManipulatable
+-----------------------+-------------------------+--------------------------+
|        Function       | State variables written | Conditions on msg.sender |
+-----------------------+-------------------------+--------------------------+
| _getReferenceTypeSlot |            []           |            []            |
|     _getSlotValue     |            []           |            []            |
|     _setSlotValue     |            []           |            []            |
+-----------------------+-------------------------+--------------------------+

Contract IDefaultImplementationBeacon
+-----------------------+-------------------------+--------------------------+
|        Function       | State variables written | Conditions on msg.sender |
+-----------------------+-------------------------+--------------------------+
| defaultImplementation |            []           |            []            |
+-----------------------+-------------------------+--------------------------+

Contract IProxied
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|      factory      |            []           |            []            |
|   implementation  |            []           |            []            |
| setImplementation |            []           |            []            |
|      migrate      |            []           |            []            |
+-------------------+-------------------------+--------------------------+

modules/withdrawal-manager/contracts/WithdrawalManager.sol analyzed (17 contracts)
