
Contract PoolDeployer
Contract vars: ['globals']
Inheritance:: ['IPoolDeployer']
 
+--------------------------------------------------------------------+------------+-----------+---------------------------+-------------+------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                              Function                              | Visibility | Modifiers |            Read           |    Write    |              Internal Calls              |                                                                            External Calls                                                                            |
+--------------------------------------------------------------------+------------+-----------+---------------------------+-------------+------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                             globals()                              |  external  |     []    |             []            |      []     |                    []                    |                                                                                  []                                                                                  |
| deployPool(address[3],address[3],address,string,string,uint256[6]) |  external  |     []    |             []            |      []     |                    []                    |                                                                                  []                                                                                  |
|                        constructor(address)                        |   public   |     []    |        ['globals']        | ['globals'] |         ['require(bool,string)']         |                                                                                  []                                                                                  |
| deployPool(address[3],address[3],address,string,string,uint256[6]) |  external  |     []    | ['globals', 'msg.sender'] |      []     | ['abi.encode()', 'require(bool,string)'] | ['IPoolManager(poolManager_).poolDelegateCover()', 'ERC20Helper.transferFrom(asset_,poolDelegate_,IPoolManager(poolManager_).poolDelegateCover(),configParams_[2])'] |
|                                                                    |            |           |                           |             |           ['keccak256(bytes)']           |        ['IPoolManager(poolManager_).configure(loanManager_,withdrawalManager_,configParams_[0],configParams_[1])', 'globals_.isPoolDelegate(poolDelegate_)']         |
|                                                                    |            |           |                           |             |                                          |       ['IPoolManagerInitializer(initializers_[0]).encodeArguments(poolDelegate_,asset_,configParams_[5],name_,symbol_)', 'IPoolManager(poolManager_).pool()']        |
|                                                                    |            |           |                           |             |                                          |                       ['IMapleProxyFactory(factories_[0]).createInstance(arguments,salt_)', 'globals_.isFactory(POOL_MANAGER,factories_[0])']                        |
|                                                                    |            |           |                           |             |                                          |                                           ['globals_.isFactory(LOAN_MANAGER,factories_[1])', 'abi.encode(poolDelegate_)']                                            |
|                                                                    |            |           |                           |             |                                          |                     ['abi.encode(pool_,configParams_[3],configParams_[4])', 'IMapleProxyFactory(factories_[1]).createInstance(arguments,salt_)']                     |
|                                                                    |            |           |                           |             |                                          |                    ['globals_.isFactory(WITHDRAWAL_MANAGER,factories_[2])', 'IMapleProxyFactory(factories_[2]).createInstance(arguments,salt_)']                     |
|                                                                    |            |           |                           |             |                                          |                                               ['ILoanManagerInitializerLike(initializers_[1]).encodeArguments(pool_)']                                               |
+--------------------------------------------------------------------+------------+-----------+---------------------------+-------------+------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolDeployer
Contract vars: []
Inheritance:: []
 
+--------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                              Function                              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                             globals()                              |  external  |     []    |  []  |   []  |       []       |       []       |
| deployPool(address[3],address[3],address,string,string,uint256[6]) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManager
Contract vars: []
Inheritance:: ['IPoolManagerStorage', 'IMapleProxied', 'IProxied']
 
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         Function                        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         active()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                         asset()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                       configured()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isLoanManager(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isValidLender(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                 loanManagerList(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  loanManagers(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                      liquidityCap()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|               delegateManagementFeeRate()               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      openToPublic()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                  pendingPoolDelegate()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                          pool()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                      poolDelegate()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                   poolDelegateCover()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                   withdrawalManager()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                  upgrade(uint256,bytes)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                        factory()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                     implementation()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                setImplementation(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                  migrate(address,bytes)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|               acceptPendingPoolDelegate()               |  external  |     []    |  []  |   []  |       []       |       []       |
|             setPendingPoolDelegate(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|        configure(address,address,uint256,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|                 addLoanManager(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                removeLoanManager(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                     setActive(bool)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|              setAllowedLender(address,bool)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 setLiquidityCap(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|          setDelegateManagementFeeRate(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|                    setOpenToPublic()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|              setWithdrawalManager(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,address,uint256,bytes[],uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|              fund(uint256,address,address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|           finishCollateralLiquidation(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|              removeDefaultWarning(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                 triggerDefault(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|              triggerDefaultWarning(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|              processRedeem(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|              removeShares(uint256,address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|              requestRedeem(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                  depositCover(uint256)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|              withdrawCover(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|             getEscrowParams(address,uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|               convertToExitShares(uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   maxDeposit(address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                     maxMint(address)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                    maxRedeem(address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                   maxWithdraw(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|              previewRedeem(address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|             previewWithdraw(address,uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|              canCall(bytes32,address,bytes)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                        globals()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                        governor()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                   hasSufficientCover()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                      totalAssets()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                    unrealizedLosses()                   |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerInitializer
Contract vars: []
Inheritance:: []
 
+--------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                        Function                        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 decodeArguments(bytes)                 |  external  |     []    |  []  |   []  |       []       |       []       |
| encodeArguments(address,address,uint256,string,string) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerStorage
Contract vars: []
Inheritance:: []
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           active()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           asset()           |  external  |     []    |  []  |   []  |       []       |       []       |
|         configured()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    isLoanManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidLender(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|   loanManagerList(uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
|    loanManagers(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|        liquidityCap()       |  external  |     []    |  []  |   []  |       []       |       []       |
| delegateManagementFeeRate() |  external  |     []    |  []  |   []  |       []       |       []       |
|        openToPublic()       |  external  |     []    |  []  |   []  |       []       |       []       |
|    pendingPoolDelegate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolDelegate()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     poolDelegateCover()     |  external  |     []    |  []  |   []  |       []       |       []       |
|     withdrawalManager()     |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

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


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['code(address)', 'abi.decode()']   |                                               ['abi.decode(returnData,(bool))', 'token_.call(data_)']                                               |
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

modules/pool-v2/contracts/PoolDeployer.sol analyzed (24 contracts)
