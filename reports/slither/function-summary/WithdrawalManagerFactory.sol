Function not found isPoolDeployer
Impossible to generate IR for WithdrawalManagerFactory.createInstance

Contract WithdrawalManagerFactory
Contract vars: ['_implementationOf', '_versionOf', '_migratorForPath', 'mapleGlobals', 'defaultVersion', 'upgradeEnabledForPath', 'isInstance']
Inheritance:: ['MapleProxyFactory', 'ProxyFactory', 'IMapleProxyFactory', 'IDefaultImplementationBeacon']
 
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                     Function                    | Visibility |    Modifiers     |                    Read                   |                Write                |                     Internal Calls                    |                                                                                           External Calls                                                                                           |
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               constructor(address)              |   public   |        []        |              ['mapleGlobals']             |           ['mapleGlobals']          |                ['require(bool,string)']               |                                                                   ['IMapleGlobalsLike(mapleGlobals = mapleGlobals_).governor()']                                                                   |
|       disableUpgradePath(uint256,uint256)       |   public   | ['onlyGovernor'] |                     []                    |      ['upgradeEnabledForPath']      |         ['_registerMigrator', 'onlyGovernor']         |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |                ['require(bool,string)']               |                                                                                                                                                                                                    |
|    enableUpgradePath(uint256,uint256,address)   |   public   | ['onlyGovernor'] |                     []                    |      ['upgradeEnabledForPath']      |         ['_registerMigrator', 'onlyGovernor']         |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |                ['require(bool,string)']               |                                                                                                                                                                                                    |
| registerImplementation(uint256,address,address) |   public   | ['onlyGovernor'] |                     []                    |                  []                 |    ['_registerImplementation', '_registerMigrator']   |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |        ['onlyGovernor', 'require(bool,string)']       |                                                                                                                                                                                                    |
|            setDefaultVersion(uint256)           |   public   | ['onlyGovernor'] |  ['_implementationOf', 'defaultVersion']  |          ['defaultVersion']         |        ['onlyGovernor', 'require(bool,string)']       |                                                                                                 []                                                                                                 |
|               setGlobals(address)               |   public   | ['onlyGovernor'] |              ['mapleGlobals']             |           ['mapleGlobals']          |        ['onlyGovernor', 'require(bool,string)']       |                                                                          ['IMapleGlobalsLike(mapleGlobals_).governor()']                                                                           |
|          createInstance(bytes,bytes32)          |   public   |        []        |             ['defaultVersion']            |                  []                 |          ['keccak256(bytes)', '_newInstance']         |                                                                               ['abi.encodePacked(arguments_,salt_)']                                                                               |
|                                                 |            |                  |                                           |                                     |     ['require(bool,string)', 'abi.encodePacked()']    |                                                                                                                                                                                                    |
|          upgradeInstance(uint256,bytes)         |   public   |        []        |  ['_versionOf', 'upgradeEnabledForPath']  |                  []                 |      ['_upgradeInstance', 'require(bool,string)']     |                                                                           ['IMapleProxied(msg.sender).implementation()']                                                                           |
|                                                 |            |                  |               ['msg.sender']              |                                     |                                                       |                                                                                                                                                                                                    |
|        getInstanceAddress(bytes,bytes32)        |   public   |        []        |                     []                    |                  []                 | ['keccak256(bytes)', '_getDeterministicProxyAddress'] |                                                                               ['abi.encodePacked(arguments_,salt_)']                                                                               |
|                                                 |            |                  |                                           |                                     |                 ['abi.encodePacked()']                |                                                                                                                                                                                                    |
|            implementationOf(uint256)            |   public   |        []        |           ['_implementationOf']           |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|             defaultImplementation()             |  external  |        []        |  ['_implementationOf', 'defaultVersion']  |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|         migratorForPath(uint256,uint256)        |   public   |        []        |            ['_migratorForPath']           |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                versionOf(address)               |   public   |        []        |               ['_versionOf']              |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|        _getImplementationOfProxy(address)       |  private   |        []        |                     []                    |                  []                 |      ['abi.encodeWithSelector()', 'abi.decode()']     |                                        ['abi.decode(returnData,(address))', 'proxy_.staticcall(abi.encodeWithSelector(IProxied.implementation.selector))']                                         |
|                                                 |            |                  |                                           |                                     |                                                       |                                                                    ['abi.encodeWithSelector(IProxied.implementation.selector)']                                                                    |
|    _initializeInstance(address,uint256,bytes)   |  private   |        []        |            ['_migratorForPath']           |                  []                 |              ['abi.encodeWithSelector()']             |               ['proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_))', 'abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_)']                |
|           _newInstance(uint256,bytes)           |  internal  |        []        |       ['_implementationOf', 'this']       |                  []                 |                ['_initializeInstance']                |                                                                            ['new Proxy(address(this),implementation)']                                                                             |
|           _newInstance(bytes,bytes32)           |  internal  |        []        |           ['_versionOf', 'this']          |                  []                 |  ['_initializeInstance', '_getImplementationOfProxy'] |                                                                              ['new Proxy(address(this),address(0))']                                                                               |
|     _registerImplementation(uint256,address)    |  internal  |        []        |    ['_implementationOf', '_versionOf']    | ['_implementationOf', '_versionOf'] |                    ['_isContract']                    |                                                                                                 []                                                                                                 |
|    _registerMigrator(uint256,uint256,address)   |  internal  |        []        |                     []                    |         ['_migratorForPath']        |                    ['_isContract']                    |                                                                                                 []                                                                                                 |
|     _upgradeInstance(address,uint256,bytes)     |  internal  |        []        | ['_implementationOf', '_migratorForPath'] |                  []                 |      ['_isContract', 'abi.encodeWithSelector()']      |        ['proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_))', 'proxy_.call(abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation))']         |
|                                                 |            |                  |               ['_versionOf']              |                                     |             ['_getImplementationOfProxy']             |                     ['abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation)', 'abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_)']                      |
|      _getDeterministicProxyAddress(bytes32)     |  internal  |        []        |                  ['this']                 |                  []                 |             ['keccak256(bytes)', 'type()']            | ['abi.encode(address(this),address(0))', 'abi.encodePacked(bytes1(0xff),address(this),salt_,keccak256(bytes)(abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))))'] |
|                                                 |            |                  |                                           |                                     |         ['abi.encode()', 'abi.encodePacked()']        |                                                       ['abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))']                                                        |
|               _isContract(address)              |  internal  |        []        |                     []                    |                  []                 |                   ['code(address)']                   |                                                                                                 []                                                                                                 |
|                 defaultVersion()                |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                  mapleGlobals()                 |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|      upgradeEnabledForPath(uint256,uint256)     |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|          createInstance(bytes,bytes32)          |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|    enableUpgradePath(uint256,uint256,address)   |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|       disableUpgradePath(uint256,uint256)       |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
| registerImplementation(uint256,address,address) |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|            setDefaultVersion(uint256)           |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|               setGlobals(address)               |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|          upgradeInstance(uint256,bytes)         |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|        getInstanceAddress(bytes,bytes32)        |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|            implementationOf(uint256)            |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|         migratorForPath(uint256,uint256)        |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                versionOf(address)               |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|             defaultImplementation()             |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|               constructor(address)              |   public   |        []        |                     []                    |                  []                 |                          ['']                         |                                                                                                 []                                                                                                 |
|          createInstance(bytes,bytes32)          |   public   |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+
|   Modifiers    | Visibility |              Read              | Write |      Internal Calls      |                 External Calls                 |
+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+
| onlyGovernor() |  internal  | ['mapleGlobals', 'msg.sender'] |   []  | ['require(bool,string)'] | ['IMapleGlobalsLike(mapleGlobals).governor()'] |
+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+


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


Contract MapleProxyFactory
Contract vars: ['_implementationOf', '_versionOf', '_migratorForPath', 'mapleGlobals', 'defaultVersion', 'upgradeEnabledForPath']
Inheritance:: ['ProxyFactory', 'IMapleProxyFactory', 'IDefaultImplementationBeacon']
 
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                     Function                    | Visibility |    Modifiers     |                    Read                   |                Write                |                     Internal Calls                    |                                                                                           External Calls                                                                                           |
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|        _getImplementationOfProxy(address)       |  private   |        []        |                     []                    |                  []                 |      ['abi.encodeWithSelector()', 'abi.decode()']     |                                                  ['abi.encodeWithSelector(IProxied.implementation.selector)', 'abi.decode(returnData,(address))']                                                  |
|                                                 |            |                  |                                           |                                     |                                                       |                                                          ['proxy_.staticcall(abi.encodeWithSelector(IProxied.implementation.selector))']                                                           |
|    _initializeInstance(address,uint256,bytes)   |  private   |        []        |            ['_migratorForPath']           |                  []                 |              ['abi.encodeWithSelector()']             |               ['proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_))', 'abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_)']                |
|           _newInstance(uint256,bytes)           |  internal  |        []        |       ['_implementationOf', 'this']       |                  []                 |                ['_initializeInstance']                |                                                                            ['new Proxy(address(this),implementation)']                                                                             |
|           _newInstance(bytes,bytes32)           |  internal  |        []        |           ['_versionOf', 'this']          |                  []                 |  ['_initializeInstance', '_getImplementationOfProxy'] |                                                                              ['new Proxy(address(this),address(0))']                                                                               |
|     _registerImplementation(uint256,address)    |  internal  |        []        |    ['_implementationOf', '_versionOf']    | ['_implementationOf', '_versionOf'] |                    ['_isContract']                    |                                                                                                 []                                                                                                 |
|    _registerMigrator(uint256,uint256,address)   |  internal  |        []        |                     []                    |         ['_migratorForPath']        |                    ['_isContract']                    |                                                                                                 []                                                                                                 |
|     _upgradeInstance(address,uint256,bytes)     |  internal  |        []        | ['_implementationOf', '_migratorForPath'] |                  []                 |      ['_isContract', 'abi.encodeWithSelector()']      |           ['proxy_.call(abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation))', 'abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation)']            |
|                                                 |            |                  |               ['_versionOf']              |                                     |             ['_getImplementationOfProxy']             |                  ['proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_))', 'abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_)']                   |
|      _getDeterministicProxyAddress(bytes32)     |  internal  |        []        |                  ['this']                 |                  []                 |             ['keccak256(bytes)', 'type()']            | ['abi.encode(address(this),address(0))', 'abi.encodePacked(bytes1(0xff),address(this),salt_,keccak256(bytes)(abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))))'] |
|                                                 |            |                  |                                           |                                     |         ['abi.encode()', 'abi.encodePacked()']        |                                                       ['abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))']                                                        |
|               _isContract(address)              |  internal  |        []        |                     []                    |                  []                 |                   ['code(address)']                   |                                                                                                 []                                                                                                 |
|                 defaultVersion()                |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                  mapleGlobals()                 |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|      upgradeEnabledForPath(uint256,uint256)     |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|          createInstance(bytes,bytes32)          |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|    enableUpgradePath(uint256,uint256,address)   |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|       disableUpgradePath(uint256,uint256)       |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
| registerImplementation(uint256,address,address) |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|            setDefaultVersion(uint256)           |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|               setGlobals(address)               |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|          upgradeInstance(uint256,bytes)         |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|        getInstanceAddress(bytes,bytes32)        |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|            implementationOf(uint256)            |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|         migratorForPath(uint256,uint256)        |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                versionOf(address)               |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|             defaultImplementation()             |  external  |        []        |                     []                    |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|               constructor(address)              |   public   |        []        |              ['mapleGlobals']             |           ['mapleGlobals']          |                ['require(bool,string)']               |                                                                   ['IMapleGlobalsLike(mapleGlobals = mapleGlobals_).governor()']                                                                   |
|       disableUpgradePath(uint256,uint256)       |   public   | ['onlyGovernor'] |                     []                    |      ['upgradeEnabledForPath']      |         ['onlyGovernor', '_registerMigrator']         |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |                ['require(bool,string)']               |                                                                                                                                                                                                    |
|    enableUpgradePath(uint256,uint256,address)   |   public   | ['onlyGovernor'] |                     []                    |      ['upgradeEnabledForPath']      |         ['onlyGovernor', '_registerMigrator']         |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |                ['require(bool,string)']               |                                                                                                                                                                                                    |
| registerImplementation(uint256,address,address) |   public   | ['onlyGovernor'] |                     []                    |                  []                 |      ['_registerImplementation', 'onlyGovernor']      |                                                                                                 []                                                                                                 |
|                                                 |            |                  |                                           |                                     |     ['_registerMigrator', 'require(bool,string)']     |                                                                                                                                                                                                    |
|            setDefaultVersion(uint256)           |   public   | ['onlyGovernor'] |  ['_implementationOf', 'defaultVersion']  |          ['defaultVersion']         |        ['onlyGovernor', 'require(bool,string)']       |                                                                                                 []                                                                                                 |
|               setGlobals(address)               |   public   | ['onlyGovernor'] |              ['mapleGlobals']             |           ['mapleGlobals']          |        ['onlyGovernor', 'require(bool,string)']       |                                                                          ['IMapleGlobalsLike(mapleGlobals_).governor()']                                                                           |
|          createInstance(bytes,bytes32)          |   public   |        []        |             ['defaultVersion']            |                  []                 |          ['keccak256(bytes)', '_newInstance']         |                                                                               ['abi.encodePacked(arguments_,salt_)']                                                                               |
|                                                 |            |                  |                                           |                                     |     ['require(bool,string)', 'abi.encodePacked()']    |                                                                                                                                                                                                    |
|          upgradeInstance(uint256,bytes)         |   public   |        []        |  ['_versionOf', 'upgradeEnabledForPath']  |                  []                 |      ['_upgradeInstance', 'require(bool,string)']     |                                                                           ['IMapleProxied(msg.sender).implementation()']                                                                           |
|                                                 |            |                  |               ['msg.sender']              |                                     |                                                       |                                                                                                                                                                                                    |
|        getInstanceAddress(bytes,bytes32)        |   public   |        []        |                     []                    |                  []                 | ['keccak256(bytes)', '_getDeterministicProxyAddress'] |                                                                               ['abi.encodePacked(arguments_,salt_)']                                                                               |
|                                                 |            |                  |                                           |                                     |                 ['abi.encodePacked()']                |                                                                                                                                                                                                    |
|            implementationOf(uint256)            |   public   |        []        |           ['_implementationOf']           |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|             defaultImplementation()             |  external  |        []        |  ['_implementationOf', 'defaultVersion']  |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|         migratorForPath(uint256,uint256)        |   public   |        []        |            ['_migratorForPath']           |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
|                versionOf(address)               |   public   |        []        |               ['_versionOf']              |                  []                 |                           []                          |                                                                                                 []                                                                                                 |
+-------------------------------------------------+------------+------------------+-------------------------------------------+-------------------------------------+-------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+
|   Modifiers    | Visibility |              Read              | Write |      Internal Calls      |                 External Calls                 |
+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+
| onlyGovernor() |  internal  | ['mapleGlobals', 'msg.sender'] |   []  | ['require(bool,string)'] | ['IMapleGlobalsLike(mapleGlobals).governor()'] |
+----------------+------------+--------------------------------+-------+--------------------------+------------------------------------------------+


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


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+------------+------------+-----------+------+-------+----------------+----------------+
|  Function  | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------+------------+-----------+------+-------+----------------+----------------+
| governor() |  external  |     []    |  []  |   []  |       []       |       []       |
+------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract Proxy
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['SlotManipulatable']
 
+----------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------------------------------------------+--------------------------------------------------------------------+
|                Function                | Visibility | Modifiers |                   Read                  |                  Write                  |                                   Internal Calls                                   |                           External Calls                           |
+----------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------------------------------------------+--------------------------------------------------------------------+
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |                    []                   |                    []                   |                     ['keccak256(bytes)', 'abi.encodePacked()']                     |                  ['abi.encodePacked(key_,slot_)']                  |
|         _getSlotValue(bytes32)         |  internal  |     []    |                    []                   |                    []                   |                                 ['sload(uint256)']                                 |                                 []                                 |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |                    []                   |                    []                   |                            ['sstore(uint256,uint256)']                             |                                 []                                 |
|      constructor(address,address)      |   public   |     []    | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                    []                   |                         ['_setSlotValue', 'require(bool)']                         | ['IDefaultImplementationBeacon(factory_).defaultImplementation()'] |
|               fallback()               |  external  |     []    |         ['IMPLEMENTATION_SLOT']         |                    []                   | ['code(address)', 'delegatecall(uint256,uint256,uint256,uint256,uint256,uint256)'] |                                 []                                 |
|                                        |            |           |                                         |                                         |                        ['calldatasize()', 'require(bool)']                         |                                                                    |
|                                        |            |           |                                         |                                         |               ['revert(uint256,uint256)', 'return(uint256,uint256)']               |                                                                    |
|                                        |            |           |                                         |                                         |           ['returndatasize()', 'calldatacopy(uint256,uint256,uint256)']            |                                                                    |
|                                        |            |           |                                         |                                         |                ['gas()', 'returndatacopy(uint256,uint256,uint256)']                |                                                                    |
|                                        |            |           |                                         |                                         |                                 ['_getSlotValue']                                  |                                                                    |
| slitherConstructorConstantVariables()  |  internal  |     []    |                    []                   | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                                         []                                         |                                 []                                 |
+----------------------------------------+------------+-----------+-----------------------------------------+-----------------------------------------+------------------------------------------------------------------------------------+--------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ProxyFactory
Contract vars: ['_implementationOf', '_versionOf', '_migratorForPath']
Inheritance:: []
 
+--------------------------------------------+------------+-----------+-------------------------------------------+-------------------------------------+------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                  Function                  | Visibility | Modifiers |                    Read                   |                Write                |                    Internal Calls                    |                                                                                 External Calls                                                                                |
+--------------------------------------------+------------+-----------+-------------------------------------------+-------------------------------------+------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|     _getImplementationOfProxy(address)     |  private   |     []    |                     []                    |                  []                 |     ['abi.encodeWithSelector()', 'abi.decode()']     |                  ['abi.encodeWithSelector(IProxied.implementation.selector)', 'proxy_.staticcall(abi.encodeWithSelector(IProxied.implementation.selector))']                  |
|                                            |            |           |                                           |                                     |                                                      |                                                                      ['abi.decode(returnData,(address))']                                                                     |
| _initializeInstance(address,uint256,bytes) |  private   |     []    |            ['_migratorForPath']           |                  []                 |             ['abi.encodeWithSelector()']             |     ['abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_)', 'proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,initializer,arguments_))']     |
|        _newInstance(uint256,bytes)         |  internal  |     []    |       ['_implementationOf', 'this']       |                  []                 |               ['_initializeInstance']                |                                                                  ['new Proxy(address(this),implementation)']                                                                  |
|        _newInstance(bytes,bytes32)         |  internal  |     []    |           ['_versionOf', 'this']          |                  []                 | ['_initializeInstance', '_getImplementationOfProxy'] |                                                                    ['new Proxy(address(this),address(0))']                                                                    |
|  _registerImplementation(uint256,address)  |  internal  |     []    |    ['_implementationOf', '_versionOf']    | ['_implementationOf', '_versionOf'] |                   ['_isContract']                    |                                                                                       []                                                                                      |
| _registerMigrator(uint256,uint256,address) |  internal  |     []    |                     []                    |         ['_migratorForPath']        |                   ['_isContract']                    |                                                                                       []                                                                                      |
|  _upgradeInstance(address,uint256,bytes)   |  internal  |     []    | ['_implementationOf', '_migratorForPath'] |                  []                 |     ['abi.encodeWithSelector()', '_isContract']      | ['proxy_.call(abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation))', 'abi.encodeWithSelector(IProxied.setImplementation.selector,toImplementation)'] |
|                                            |            |           |               ['_versionOf']              |                                     |            ['_getImplementationOfProxy']             |        ['proxy_.call(abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_))', 'abi.encodeWithSelector(IProxied.migrate.selector,migrator,arguments_)']        |
|   _getDeterministicProxyAddress(bytes32)   |  internal  |     []    |                  ['this']                 |                  []                 |            ['keccak256(bytes)', 'type()']            |                         ['abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))', 'abi.encode(address(this),address(0))']                         |
|                                            |            |           |                                           |                                     |        ['abi.encode()', 'abi.encodePacked()']        |           ['abi.encodePacked(bytes1(0xff),address(this),salt_,keccak256(bytes)(abi.encodePacked(type()(Proxy).creationCode,abi.encode(address(this),address(0)))))']          |
|            _isContract(address)            |  internal  |     []    |                     []                    |                  []                 |                  ['code(address)']                   |                                                                                       []                                                                                      |
+--------------------------------------------+------------+-----------+-------------------------------------------+-------------------------------------+------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

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

modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol analyzed (14 contracts)
