Function not found isPoolDeployer
Impossible to generate IR for WithdrawalManagerFactory.createInstance

Contract WithdrawalManagerFactory
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|            Function           |                 State variables written                 |                                                                                        Conditions on msg.sender                                                                                        |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|          constructor          |                     ['mapleGlobals']                    |                                                                                                   []                                                                                                   |
|       disableUpgradePath      |      ['upgradeEnabledForPath', '_migratorForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       enableUpgradePath       |      ['upgradeEnabledForPath', '_migratorForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|     registerImplementation    | ['_versionOf', '_implementationOf', '_migratorForPath'] | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       setDefaultVersion       |                    ['defaultVersion']                   | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|           setGlobals          |                     ['mapleGlobals']                    | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|         createInstance        |                            []                           |                                                                                                   []                                                                                                   |
|        upgradeInstance        |                            []                           |                                                       ['require(bool,string)(_upgradeInstance(msg.sender,toVersion_,arguments_),MPF:UI:FAILED)']                                                       |
|       getInstanceAddress      |                            []                           |                                                                                                   []                                                                                                   |
|        implementationOf       |                            []                           |                                                                                                   []                                                                                                   |
|     defaultImplementation     |                            []                           |                                                                                                   []                                                                                                   |
|        migratorForPath        |                            []                           |                                                                                                   []                                                                                                   |
|           versionOf           |                            []                           |                                                                                                   []                                                                                                   |
|   _getImplementationOfProxy   |                            []                           |                                                                                                   []                                                                                                   |
|      _initializeInstance      |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|    _registerImplementation    |           ['_versionOf', '_implementationOf']           |                                                                                                   []                                                                                                   |
|       _registerMigrator       |                   ['_migratorForPath']                  |                                                                                                   []                                                                                                   |
|        _upgradeInstance       |                            []                           |                                                                                                   []                                                                                                   |
| _getDeterministicProxyAddress |                            []                           |                                                                                                   []                                                                                                   |
|          _isContract          |                            []                           |                                                                                                   []                                                                                                   |
|         defaultVersion        |                            []                           |                                                                                                   []                                                                                                   |
|          mapleGlobals         |                            []                           |                                                                                                   []                                                                                                   |
|     upgradeEnabledForPath     |                            []                           |                                                                                                   []                                                                                                   |
|         createInstance        |                            []                           |                                                                                                   []                                                                                                   |
|       enableUpgradePath       |                            []                           |                                                                                                   []                                                                                                   |
|       disableUpgradePath      |                            []                           |                                                                                                   []                                                                                                   |
|     registerImplementation    |                            []                           |                                                                                                   []                                                                                                   |
|       setDefaultVersion       |                            []                           |                                                                                                   []                                                                                                   |
|           setGlobals          |                            []                           |                                                                                                   []                                                                                                   |
|        upgradeInstance        |                            []                           |                                                                                                   []                                                                                                   |
|       getInstanceAddress      |                            []                           |                                                                                                   []                                                                                                   |
|        implementationOf       |                            []                           |                                                                                                   []                                                                                                   |
|        migratorForPath        |                            []                           |                                                                                                   []                                                                                                   |
|           versionOf           |                            []                           |                                                                                                   []                                                                                                   |
|     defaultImplementation     |                            []                           |                                                                                                   []                                                                                                   |
|          constructor          |                     ['mapleGlobals']                    |                                                                                                   []                                                                                                   |
|         createInstance        |                            []                           |                                                                                                   []                                                                                                   |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

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

Contract MapleProxyFactory
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|            Function           |                 State variables written                 |                                                                                        Conditions on msg.sender                                                                                        |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|   _getImplementationOfProxy   |                            []                           |                                                                                                   []                                                                                                   |
|      _initializeInstance      |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|    _registerImplementation    |           ['_versionOf', '_implementationOf']           |                                                                                                   []                                                                                                   |
|       _registerMigrator       |                   ['_migratorForPath']                  |                                                                                                   []                                                                                                   |
|        _upgradeInstance       |                            []                           |                                                                                                   []                                                                                                   |
| _getDeterministicProxyAddress |                            []                           |                                                                                                   []                                                                                                   |
|          _isContract          |                            []                           |                                                                                                   []                                                                                                   |
|         defaultVersion        |                            []                           |                                                                                                   []                                                                                                   |
|          mapleGlobals         |                            []                           |                                                                                                   []                                                                                                   |
|     upgradeEnabledForPath     |                            []                           |                                                                                                   []                                                                                                   |
|         createInstance        |                            []                           |                                                                                                   []                                                                                                   |
|       enableUpgradePath       |                            []                           |                                                                                                   []                                                                                                   |
|       disableUpgradePath      |                            []                           |                                                                                                   []                                                                                                   |
|     registerImplementation    |                            []                           |                                                                                                   []                                                                                                   |
|       setDefaultVersion       |                            []                           |                                                                                                   []                                                                                                   |
|           setGlobals          |                            []                           |                                                                                                   []                                                                                                   |
|        upgradeInstance        |                            []                           |                                                                                                   []                                                                                                   |
|       getInstanceAddress      |                            []                           |                                                                                                   []                                                                                                   |
|        implementationOf       |                            []                           |                                                                                                   []                                                                                                   |
|        migratorForPath        |                            []                           |                                                                                                   []                                                                                                   |
|           versionOf           |                            []                           |                                                                                                   []                                                                                                   |
|     defaultImplementation     |                            []                           |                                                                                                   []                                                                                                   |
|          constructor          |                     ['mapleGlobals']                    |                                                                                                   []                                                                                                   |
|       disableUpgradePath      |      ['upgradeEnabledForPath', '_migratorForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       enableUpgradePath       |      ['upgradeEnabledForPath', '_migratorForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|     registerImplementation    | ['_versionOf', '_implementationOf', '_migratorForPath'] | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       setDefaultVersion       |                    ['defaultVersion']                   | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|           setGlobals          |                     ['mapleGlobals']                    | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|         createInstance        |                            []                           |                                                                                                   []                                                                                                   |
|        upgradeInstance        |                            []                           |                                                       ['require(bool,string)(_upgradeInstance(msg.sender,toVersion_,arguments_),MPF:UI:FAILED)']                                                       |
|       getInstanceAddress      |                            []                           |                                                                                                   []                                                                                                   |
|        implementationOf       |                            []                           |                                                                                                   []                                                                                                   |
|     defaultImplementation     |                            []                           |                                                                                                   []                                                                                                   |
|        migratorForPath        |                            []                           |                                                                                                   []                                                                                                   |
|           versionOf           |                            []                           |                                                                                                   []                                                                                                   |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

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

Contract IMapleGlobalsLike
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
| governor |            []           |            []            |
+----------+-------------------------+--------------------------+

Contract Proxy
+-------------------------------------+-----------------------------------------+--------------------------+
|               Function              |         State variables written         | Conditions on msg.sender |
+-------------------------------------+-----------------------------------------+--------------------------+
|        _getReferenceTypeSlot        |                    []                   |            []            |
|            _getSlotValue            |                    []                   |            []            |
|            _setSlotValue            |                    []                   |            []            |
|             constructor             |                    []                   |            []            |
|               fallback              |                    []                   |            []            |
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract ProxyFactory
+-------------------------------+-------------------------------------+--------------------------+
|            Function           |       State variables written       | Conditions on msg.sender |
+-------------------------------+-------------------------------------+--------------------------+
|   _getImplementationOfProxy   |                  []                 |            []            |
|      _initializeInstance      |                  []                 |            []            |
|          _newInstance         |                  []                 |            []            |
|          _newInstance         |                  []                 |            []            |
|    _registerImplementation    | ['_versionOf', '_implementationOf'] |            []            |
|       _registerMigrator       |         ['_migratorForPath']        |            []            |
|        _upgradeInstance       |                  []                 |            []            |
| _getDeterministicProxyAddress |                  []                 |            []            |
|          _isContract          |                  []                 |            []            |
+-------------------------------+-------------------------------------+--------------------------+

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

modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol analyzed (14 contracts)
