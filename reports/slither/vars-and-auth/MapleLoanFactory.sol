
Contract MapleLoanFactory
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|            Function           |                 State variables written                 |                                                                                        Conditions on msg.sender                                                                                        |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|          constructor          |                     ['mapleGlobals']                    |                                                                                                   []                                                                                                   |
|       disableUpgradePath      |      ['_migratorForPath', 'upgradeEnabledForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       enableUpgradePath       |      ['_migratorForPath', 'upgradeEnabledForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|     registerImplementation    | ['_implementationOf', '_migratorForPath', '_versionOf'] | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
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
|    _registerImplementation    |           ['_implementationOf', '_versionOf']           |                                                                                                   []                                                                                                   |
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
|             isLoan            |                            []                           |                                                                                                   []                                                                                                   |
|          constructor          |                     ['mapleGlobals']                    |                                                                                                   []                                                                                                   |
|         createInstance        |                        ['isLoan']                       |                                                                                                   []                                                                                                   |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Contract IMapleLoanFactory
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
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
| defaultImplementation  |            []           |            []            |
|         isLoan         |            []           |            []            |
+------------------------+-------------------------+--------------------------+

Contract MapleProxyFactory
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|            Function           |                 State variables written                 |                                                                                        Conditions on msg.sender                                                                                        |
+-------------------------------+---------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|   _getImplementationOfProxy   |                            []                           |                                                                                                   []                                                                                                   |
|      _initializeInstance      |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|          _newInstance         |                            []                           |                                                                                                   []                                                                                                   |
|    _registerImplementation    |           ['_implementationOf', '_versionOf']           |                                                                                                   []                                                                                                   |
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
|       disableUpgradePath      |      ['_migratorForPath', 'upgradeEnabledForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|       enableUpgradePath       |      ['_migratorForPath', 'upgradeEnabledForPath']      | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
|     registerImplementation    | ['_implementationOf', '_migratorForPath', '_versionOf'] | ['require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(),MPF:NOT_GOVERNOR)'] |
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
|    _registerImplementation    | ['_implementationOf', '_versionOf'] |            []            |
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

modules/loan-v301/contracts/MapleLoanFactory.sol analyzed (11 contracts)
