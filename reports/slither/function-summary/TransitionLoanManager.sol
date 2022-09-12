
Contract TransitionLoanManager
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT', '_locked', 'paymentCounter', 'paymentWithEarliestDueDate', 'domainStart', 'domainEnd', 'accountedInterest', 'principalOut', 'unrealizedLosses', 'issuanceRate', 'fundsAsset', 'pool', 'poolManager', 'paymentIdOf', 'allowedSlippageFor', 'minRatioFor', 'liquidationInfo', 'payments', 'sortedPayments', 'PRECISION', 'HUNDRED_PERCENT']
Inheritance:: ['LoanManagerStorage', 'MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'ITransitionLoanManager', 'ILoanManagerStorage', 'IMapleProxied', 'IProxied']
 
+--------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+-----------------------------------------------+-----------------------------------------------------------------------------------------------------------------+
|                  Function                  | Visibility |    Modifiers     |                       Read                       |                      Write                       |                 Internal Calls                |                                                  External Calls                                                 |
+--------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+-----------------------------------------------+-----------------------------------------------------------------------------------------------------------------+
|            accountedInterest()             |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|        allowedSlippageFor(address)         |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                domainEnd()                 |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|               domainStart()                |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                fundsAsset()                |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|               issuanceRate()               |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|          liquidationInfo(address)          |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|            minRatioFor(address)            |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|              paymentCounter()              |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|            paymentIdOf(address)            |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|             payments(uint256)              |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|        paymentWithEarliestDueDate()        |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                   pool()                   |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|               poolManager()                |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|               principalOut()               |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|          sortedPayments(uint256)           |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|             unrealizedLosses()             |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|          _migrate(address,bytes)           |  internal  |        []        |                        []                        |                        []                        |                       []                      |                                      ['migrator_.delegatecall(arguments_)']                                     |
|            _setFactory(address)            |  internal  |        []        |                 ['FACTORY_SLOT']                 |                        []                        |               ['_setSlotValue']               |                                                        []                                                       |
|        _setImplementation(address)         |  internal  |        []        |             ['IMPLEMENTATION_SLOT']              |                        []                        |               ['_setSlotValue']               |                                                        []                                                       |
|                 _factory()                 |  internal  |        []        |                 ['FACTORY_SLOT']                 |                        []                        |               ['_getSlotValue']               |                                                        []                                                       |
|             _implementation()              |  internal  |        []        |             ['IMPLEMENTATION_SLOT']              |                        []                        |               ['_getSlotValue']               |                                                        []                                                       |
|   _getReferenceTypeSlot(bytes32,bytes32)   |  internal  |        []        |                        []                        |                        []                        |   ['abi.encodePacked()', 'keccak256(bytes)']  |                                         ['abi.encodePacked(key_,slot_)']                                        |
|           _getSlotValue(bytes32)           |  internal  |        []        |                        []                        |                        []                        |               ['sload(uint256)']              |                                                        []                                                       |
|       _setSlotValue(bytes32,bytes32)       |  internal  |        []        |                        []                        |                        []                        |          ['sstore(uint256,uint256)']          |                                                        []                                                       |
|                add(address)                |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|     setOwnershipTo(address[],address)      |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|          takeOwnership(address[])          |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                PRECISION()                 |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|             HUNDRED_PERCENT()              |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|          assetsUnderManagement()           |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|            getAccruedInterest()            |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                 globals()                  |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|              migrationAdmin()              |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|           upgrade(uint256,bytes)           |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|                 factory()                  |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|              implementation()              |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|         setImplementation(address)         |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|           migrate(address,bytes)           |  external  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|           migrate(address,bytes)           |  external  |        []        |                  ['msg.sender']                  |                        []                        |            ['_factory', '_migrate']           |                                                        []                                                       |
|                                            |            |                  |                                                  |                                                  |            ['require(bool,string)']           |                                                                                                                 |
|         setImplementation(address)         |  external  |        []        |                  ['msg.sender']                  |                        []                        |      ['_factory', 'require(bool,string)']     |                                                        []                                                       |
|                                            |            |                  |                                                  |                                                  |             ['_setImplementation']            |                                                                                                                 |
|           upgrade(uint256,bytes)           |  external  |        []        |                  ['msg.sender']                  |                        []                        |      ['_factory', 'require(bool,string)']     |                     ['IMapleProxyFactory(_factory()).upgradeInstance(version_,arguments_)']                     |
|                                            |            |                  |                                                  |                                                  |               ['migrationAdmin']              |                                                                                                                 |
|                add(address)                |  external  | ['nonReentrant'] |  ['issuanceRate', 'paymentWithEarliestDueDate']  |           ['domainEnd', 'domainStart']           | ['require(bool,string)', '_queueNextPayment'] |               ['ILoanLike(loanAddress_).principal()', 'ILoanLike(loanAddress_).paymentInterval()']              |
|                                            |            |                  |           ['payments', 'principalOut']           |         ['issuanceRate', 'principalOut']         |          ['_uint48', 'nonReentrant']          |                                 ['ILoanLike(loanAddress_).nextPaymentDueDate()']                                |
|                                            |            |                  |        ['block.timestamp', 'msg.sender']         |                                                  |         ['_uint128', 'migrationAdmin']        |                                                                                                                 |
|     setOwnershipTo(address[],address)      |  external  |        []        |                  ['msg.sender']                  |                        []                        |   ['require(bool,string)', 'migrationAdmin']  |                           ['ILoanLike(loanAddress_[i_]).setPendingLender(newLender_)']                          |
|          takeOwnership(address[])          |  external  |        []        |                  ['msg.sender']                  |                        []                        |   ['require(bool,string)', 'migrationAdmin']  |                                  ['ILoanLike(loanAddress_[i_]).acceptLender()']                                 |
|         _addPaymentToList(uint48)          |  internal  |        []        | ['paymentCounter', 'paymentWithEarliestDueDate'] | ['paymentCounter', 'paymentWithEarliestDueDate'] |                       []                      |                                                        []                                                       |
|                                            |            |                  |                ['sortedPayments']                |                ['sortedPayments']                |                                               |                                                                                                                 |
|      _removePaymentFromList(uint256)       |  internal  |        []        | ['paymentWithEarliestDueDate', 'sortedPayments'] | ['paymentWithEarliestDueDate', 'sortedPayments'] |                       []                      |                                                        []                                                       |
| _queueNextPayment(address,uint256,uint256) |  internal  |        []        |         ['HUNDRED_PERCENT', 'PRECISION']         |       ['accountedInterest', 'paymentIdOf']       |        ['_uint24', '_addPaymentToList']       |   ['IPoolManagerLike(poolManager).delegateManagementFeeRate()', 'ILoanLike(loan_).getNextPaymentBreakdown()']   |
|                                            |            |                  |       ['accountedInterest', 'paymentIdOf']       |                   ['payments']                   |        ['_uint112', '_getNetInterest']        | ['IMapleGlobalsLike(globals()).platformManagementFeeRate(poolManager)', 'ILoanLike(loan_).refinanceInterest()'] |
|                                            |            |                  |        ['poolManager', 'block.timestamp']        |                                                  |              ['_min', '_uint48']              |                                                                                                                 |
|                                            |            |                  |                                                  |                                                  |            ['globals', '_uint128']            |                                                                                                                 |
|          assetsUnderManagement()           |   public   |        []        |      ['accountedInterest', 'principalOut']       |                        []                        |             ['getAccruedInterest']            |                                                        []                                                       |
|                 factory()                  |  external  |        []        |                        []                        |                        []                        |                  ['_factory']                 |                                                        []                                                       |
|            getAccruedInterest()            |   public   |        []        |            ['PRECISION', 'domainEnd']            |                        []                        |                    ['_min']                   |                                                        []                                                       |
|                                            |            |                  |         ['domainStart', 'issuanceRate']          |                                                  |                                               |                                                                                                                 |
|                                            |            |                  |               ['block.timestamp']                |                                                  |                                               |                                                                                                                 |
|                 globals()                  |   public   |        []        |                 ['poolManager']                  |                        []                        |                       []                      |                                   ['IPoolManagerLike(poolManager).globals()']                                   |
|              implementation()              |  external  |        []        |                        []                        |                        []                        |              ['_implementation']              |                                                        []                                                       |
|              migrationAdmin()              |   public   |        []        |                        []                        |                        []                        |                  ['globals']                  |                                ['IMapleGlobalsLike(globals()).migrationAdmin()']                                |
|      _getNetInterest(uint256,uint256)      |  internal  |        []        |               ['HUNDRED_PERCENT']                |                        []                        |                       []                      |                                                        []                                                       |
|           _max(uint256,uint256)            |  internal  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|           _min(uint256,uint256)            |  internal  |        []        |                        []                        |                        []                        |                       []                      |                                                        []                                                       |
|              _uint24(uint256)              |  internal  |        []        |                        []                        |                        []                        |            ['require(bool,string)']           |                                                        []                                                       |
|              _uint48(uint256)              |  internal  |        []        |                        []                        |                        []                        |            ['require(bool,string)']           |                                                        []                                                       |
|             _uint112(uint256)              |  internal  |        []        |                        []                        |                        []                        |            ['require(bool,string)']           |                                                        []                                                       |
|             _uint128(uint256)              |  internal  |        []        |                        []                        |                        []                        |            ['require(bool,string)']           |                                                        []                                                       |
|   slitherConstructorConstantVariables()    |  internal  |        []        |                        []                        |       ['FACTORY_SLOT', 'HUNDRED_PERCENT']        |                       []                      |                                                        []                                                       |
|                                            |            |                  |                                                  |       ['IMPLEMENTATION_SLOT', 'PRECISION']       |                                               |                                                                                                                 |
+--------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+-----------------------------------------------+-----------------------------------------------------------------------------------------------------------------+

+----------------+------------+-------------+-------------+--------------------------+----------------+
|   Modifiers    | Visibility |     Read    |    Write    |      Internal Calls      | External Calls |
+----------------+------------+-------------+-------------+--------------------------+----------------+
| nonReentrant() |  internal  | ['_locked'] | ['_locked'] | ['require(bool,string)'] |       []       |
+----------------+------------+-------------+-------------+--------------------------+----------------+


Contract ILoanManagerStorage
Contract vars: []
Inheritance:: []
 
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|     accountedInterest()      |  external  |     []    |  []  |   []  |       []       |       []       |
| allowedSlippageFor(address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|         domainEnd()          |  external  |     []    |  []  |   []  |       []       |       []       |
|        domainStart()         |  external  |     []    |  []  |   []  |       []       |       []       |
|         fundsAsset()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        issuanceRate()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   liquidationInfo(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|     minRatioFor(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       paymentCounter()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     paymentIdOf(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|      payments(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| paymentWithEarliestDueDate() |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolManager()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        principalOut()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   sortedPayments(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|      unrealizedLosses()      |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ITransitionLoanManager
Contract vars: []
Inheritance:: ['ILoanManagerStorage', 'IMapleProxied', 'IProxied']
 
+-----------------------------------+------------+-----------+------+-------+----------------+----------------+
|              Function             | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------+------------+-----------+------+-------+----------------+----------------+
|        accountedInterest()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    allowedSlippageFor(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|            domainEnd()            |  external  |     []    |  []  |   []  |       []       |       []       |
|           domainStart()           |  external  |     []    |  []  |   []  |       []       |       []       |
|            fundsAsset()           |  external  |     []    |  []  |   []  |       []       |       []       |
|           issuanceRate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      liquidationInfo(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|        minRatioFor(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|          paymentCounter()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        paymentIdOf(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|         payments(uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|    paymentWithEarliestDueDate()   |  external  |     []    |  []  |   []  |       []       |       []       |
|               pool()              |  external  |     []    |  []  |   []  |       []       |       []       |
|           poolManager()           |  external  |     []    |  []  |   []  |       []       |       []       |
|           principalOut()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      sortedPayments(uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|         unrealizedLosses()        |  external  |     []    |  []  |   []  |       []       |       []       |
|       upgrade(uint256,bytes)      |  external  |     []    |  []  |   []  |       []       |       []       |
|             factory()             |  external  |     []    |  []  |   []  |       []       |       []       |
|          implementation()         |  external  |     []    |  []  |   []  |       []       |       []       |
|     setImplementation(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|       migrate(address,bytes)      |  external  |     []    |  []  |   []  |       []       |       []       |
|            add(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
| setOwnershipTo(address[],address) |  external  |     []    |  []  |   []  |       []       |       []       |
|      takeOwnership(address[])     |  external  |     []    |  []  |   []  |       []       |       []       |
|            PRECISION()            |  external  |     []    |  []  |   []  |       []       |       []       |
|         HUNDRED_PERCENT()         |  external  |     []    |  []  |   []  |       []       |       []       |
|      assetsUnderManagement()      |  external  |     []    |  []  |   []  |       []       |       []       |
|        getAccruedInterest()       |  external  |     []    |  []  |   []  |       []       |       []       |
|             globals()             |  external  |     []    |  []  |   []  |       []       |       []       |
|          migrationAdmin()         |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|     decimals()     |  external  |     []    |  []  |   []  |       []       |       []       |
|   totalSupply()    |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| acceptNewTerms(address,address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|             assetsUnderManagement()             |  external  |     []    |  []  |   []  |       []       |       []       |
|               claim(address,bool)               |  external  |     []    |  []  |   []  |       []       |       []       |
|       finishCollateralLiquidation(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  fund(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|        removeDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       triggerDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|             triggerDefault(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                unrealizedLosses()               |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerInitializerLike
Contract vars: []
Inheritance:: []
 
+--------------------------+------------+-----------+------+-------+----------------+----------------+
|         Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------+------------+-----------+------+-------+----------------+----------------+
| encodeArguments(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|  decodeArguments(bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
| liquidatePortion(uint256,uint256,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|    pullFunds(address,address,uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanV3Like
Contract vars: []
Inheritance:: []
 
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------+------------+-----------+------+-------+----------------+----------------+
| getNextPaymentBreakdown() |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              acceptLender()             |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|   batchClaimFunds(uint256[],address[])  |  external  |     []    |  []  |   []  |       []       |       []       |
|                borrower()               |  external  |     []    |  []  |   []  |       []       |       []       |
|       claimFunds(uint256,address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|               collateral()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            collateralAsset()            |  external  |     []    |  []  |   []  |       []       |       []       |
|               feeManager()              |  external  |     []    |  []  |   []  |       []       |       []       |
|               fundsAsset()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            fundLoan(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|       getClosingPaymentBreakdown()      |  external  |     []    |  []  |   []  |       []       |       []       |
|    getNextPaymentDetailedBreakdown()    |  external  |     []    |  []  |   []  |       []       |       []       |
|        getNextPaymentBreakdown()        |  external  |     []    |  []  |   []  |       []       |       []       |
|              gracePeriod()              |  external  |     []    |  []  |   []  |       []       |       []       |
|              interestRate()             |  external  |     []    |  []  |   []  |       []       |       []       |
|           isInDefaultWarning()          |  external  |     []    |  []  |   []  |       []       |       []       |
|              lateFeeRate()              |  external  |     []    |  []  |   []  |       []       |       []       |
|           nextPaymentDueDate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|            paymentInterval()            |  external  |     []    |  []  |   []  |       []       |       []       |
|           paymentsRemaining()           |  external  |     []    |  []  |   []  |       []       |       []       |
|               principal()               |  external  |     []    |  []  |   []  |       []       |       []       |
|           principalRequested()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           refinanceInterest()           |  external  |     []    |  []  |   []  |       []       |       []       |
|          removeDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|            repossess(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|        setPendingLender(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         triggerDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        prewarningPaymentDueDate()       |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|               getLatestPrice(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      governor()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isBorrower(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|              isFactory(bytes32,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isPoolAsset(address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDelegate(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDeployer(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
| isValidScheduledCall(address,address,bytes32,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|          platformManagementFeeRate(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxCoverLiquidationPercent(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|                   migrationAdmin()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|               minCoverAmount(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                   mapleTreasury()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|              ownedPoolManager(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   protocolPaused()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|      transferOwnedPoolManager(address,address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|        unscheduleCall(address,bytes32,bytes)        |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanFeeManagerLike
Contract vars: []
Inheritance:: []
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
| platformServiceFee(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxyFactoryLike
Contract vars: []
Inheritance:: []
 
+----------------+------------+-----------+------+-------+----------------+----------------+
|    Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------+------------+-----------+------+-------+----------------+----------------+
| mapleGlobals() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolDelegateCoverLike
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
| moveFunds(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: ['IERC20Like']
 
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                   Function                   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              balanceOf(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                  decimals()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                totalSupply()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                   asset()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|           convertToAssets(uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|         convertToExitShares(uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|           deposit(uint256,address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                  manager()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             previewMint(uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
| processExit(uint256,uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|       redeem(uint256,address,address)        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function             | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|     addLoanManager(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|  canCall(bytes32,address,bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
|   convertToExitShares(uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          claim(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|   delegateManagementFeeRate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|  fund(uint256,address,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
| getEscrowParams(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|            globals()             |  external  |     []    |  []  |   []  |       []       |       []       |
|       hasSufficientCover()       |  external  |     []    |  []  |   []  |       []       |       []       |
|          loanManager()           |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxDeposit(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxMint(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|        maxRedeem(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxWithdraw(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|  previewRedeem(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| previewWithdraw(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
| processWithdraw(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|          poolDelegate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolDelegateCover()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    removeLoanManager(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|  removeShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|  requestRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|  setWithdrawalManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          totalAssets()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        unrealizedLosses()        |  external  |     []    |  []  |   []  |       []       |       []       |
|       withdrawalManager()        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IWithdrawalManagerLike
Contract vars: []
Inheritance:: []
 
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|            Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|   addShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isInExitWindow(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       lockedLiquidity()        |  external  |     []    |  []  |   []  |       []       |       []       |
|     lockedShares(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
| previewRedeem(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processExit(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| removeShares(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract LoanManagerStorage
Contract vars: ['_locked', 'paymentCounter', 'paymentWithEarliestDueDate', 'domainStart', 'domainEnd', 'accountedInterest', 'principalOut', 'unrealizedLosses', 'issuanceRate', 'fundsAsset', 'pool', 'poolManager', 'paymentIdOf', 'allowedSlippageFor', 'minRatioFor', 'liquidationInfo', 'payments', 'sortedPayments']
Inheritance:: ['ILoanManagerStorage']
 
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|     accountedInterest()      |  external  |     []    |  []  |   []  |       []       |       []       |
| allowedSlippageFor(address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|         domainEnd()          |  external  |     []    |  []  |   []  |       []       |       []       |
|        domainStart()         |  external  |     []    |  []  |   []  |       []       |       []       |
|         fundsAsset()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        issuanceRate()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   liquidationInfo(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|     minRatioFor(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       paymentCounter()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     paymentIdOf(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|      payments(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| paymentWithEarliestDueDate() |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolManager()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        principalOut()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   sortedPayments(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|      unrealizedLosses()      |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|               isInstance(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
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

modules/pool-v2/contracts/TransitionLoanManager.sol analyzed (24 contracts)
