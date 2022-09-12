
Contract MapleLoanFeeManager
Contract vars: ['HUNDRED_PERCENT', 'globals', 'delegateOriginationFee', 'delegateRefinanceServiceFee', 'delegateServiceFee', 'platformServiceFee', 'platformRefinanceServiceFee']
Inheritance:: ['IMapleLoanFeeManager']
 
+---------------------------------------------------------+------------+-----------+----------------------------------------------------------------+----------------------------------------------------------------+-----------------------------------------------------------------------+--------------------------------------------------------------------------------------------+
|                         Function                        | Visibility | Modifiers |                              Read                              |                             Write                              |                             Internal Calls                            |                                       External Calls                                       |
+---------------------------------------------------------+------------+-----------+----------------------------------------------------------------+----------------------------------------------------------------+-----------------------------------------------------------------------+--------------------------------------------------------------------------------------------+
|             payServiceFees(address,uint256)             |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|           payOriginationFees(address,uint256)           |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|         updateDelegateFeeTerms(uint256,uint256)         |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|       updateRefinanceServiceFees(uint256,uint256)       |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|        updatePlatformServiceFee(uint256,uint256)        |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|             delegateOriginationFee(address)             |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|               delegateServiceFee(address)               |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|           delegateRefinanceServiceFee(address)          |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|     getDelegateServiceFeesForPeriod(address,uint256)    |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|           getOriginationFees(address,uint256)           |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|        getPlatformOriginationFee(address,uint256)       |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
| getPlatformServiceFeeForPeriod(address,uint256,uint256) |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|         getServiceFeeBreakdown(address,uint256)         |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|             getServiceFees(address,uint256)             |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|         getServiceFeesForPeriod(address,uint256)        |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|                        globals()                        |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|           platformRefinanceServiceFee(address)          |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|               platformServiceFee(address)               |  external  |     []    |                               []                               |                               []                               |                                   []                                  |                                             []                                             |
|                   constructor(address)                  |   public   |     []    |                               []                               |                          ['globals']                           |                                   []                                  |                                             []                                             |
|           payOriginationFees(address,uint256)           |  external  |     []    |            ['delegateOriginationFee', 'msg.sender']            |                               []                               |           ['_getPoolDelegate', '_getPlatformOriginationFee']          |                                             []                                             |
|                                                         |            |           |                                                                |                                                                |                    ['_getTreasury', '_transferTo']                    |                                                                                            |
|             payServiceFees(address,uint256)             |  external  |     []    | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] |                  ['_getPoolDelegate', '_getTreasury']                 |                                             []                                             |
|                                                         |            |           |                         ['msg.sender']                         |                                                                |               ['getServiceFeeBreakdown', '_transferTo']               |                                                                                            |
|         updateDelegateFeeTerms(uint256,uint256)         |  external  |     []    |                         ['msg.sender']                         |        ['delegateOriginationFee', 'delegateServiceFee']        |                                   []                                  |                                             []                                             |
|       updateRefinanceServiceFees(uint256,uint256)       |  external  |     []    | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] | ['getDelegateServiceFeesForPeriod', 'getPlatformServiceFeeForPeriod'] |                                             []                                             |
|                                                         |            |           |                         ['msg.sender']                         |                                                                |                                                                       |                                                                                            |
|        updatePlatformServiceFee(uint256,uint256)        |  external  |     []    |                 ['HUNDRED_PERCENT', 'globals']                 |                     ['platformServiceFee']                     |                          ['_getPoolManager']                          |       ['IGlobalsLike(globals).platformServiceFeeRate(_getPoolManager(msg.sender))']        |
|                                                         |            |           |                         ['msg.sender']                         |                                                                |                                                                       |                                                                                            |
|     getDelegateServiceFeesForPeriod(address,uint256)    |   public   |     []    |                     ['delegateServiceFee']                     |                               []                               |                                   []                                  |                           ['ILoanLike(loan_).paymentInterval()']                           |
|        getPlatformOriginationFee(address,uint256)       |  external  |     []    |                               []                               |                               []                               |                     ['_getPlatformOriginationFee']                    |                                             []                                             |
| getPlatformServiceFeeForPeriod(address,uint256,uint256) |   public   |     []    |                 ['HUNDRED_PERCENT', 'globals']                 |                               []                               |                          ['_getPoolManager']                          |          ['IGlobalsLike(globals).platformServiceFeeRate(_getPoolManager(loan_))']          |
|             getServiceFees(address,uint256)             |  external  |     []    |                               []                               |                               []                               |                       ['getServiceFeeBreakdown']                      |                                             []                                             |
|         getServiceFeeBreakdown(address,uint256)         |   public   |     []    |     ['delegateRefinanceServiceFee', 'delegateServiceFee']      |                               []                               |                                   []                                  |                                             []                                             |
|                                                         |            |           |     ['platformRefinanceServiceFee', 'platformServiceFee']      |                                                                |                                                                       |                                                                                            |
|         getServiceFeesForPeriod(address,uint256)        |  external  |     []    |                               []                               |                               []                               | ['getDelegateServiceFeesForPeriod', 'getPlatformServiceFeeForPeriod'] |                         ['ILoanLike(loan_).principalRequested()']                          |
|           getOriginationFees(address,uint256)           |  external  |     []    |                   ['delegateOriginationFee']                   |                               []                               |                     ['_getPlatformOriginationFee']                    |                                             []                                             |
|                    _getAsset(address)                   |  internal  |     []    |                               []                               |                               []                               |                                   []                                  |                             ['ILoanLike(loan_).fundsAsset()']                              |
|       _getPlatformOriginationFee(address,uint256)       |  internal  |     []    |                 ['HUNDRED_PERCENT', 'globals']                 |                               []                               |                          ['_getPoolManager']                          |       ['ILoanLike(loan_).paymentInterval()', 'ILoanLike(loan_).paymentsRemaining()']       |
|                                                         |            |           |                                                                |                                                                |                                                                       |        ['IGlobalsLike(globals).platformOriginationFeeRate(_getPoolManager(loan_))']        |
|                 _getPoolManager(address)                |  internal  |     []    |                               []                               |                               []                               |                                   []                                  | ['ILoanLike(loan_).lender()', 'ILoanManagerLike(ILoanLike(loan_).lender()).poolManager()'] |
|                _getPoolDelegate(address)                |  internal  |     []    |                               []                               |                               []                               |                          ['_getPoolManager']                          |                ['IPoolManagerLike(_getPoolManager(loan_)).poolDelegate()']                 |
|                      _getTreasury()                     |  internal  |     []    |                          ['globals']                           |                               []                               |                                   []                                  |                         ['IGlobalsLike(globals).mapleTreasury()']                          |
|       _transferTo(address,address,uint256,string)       |  internal  |     []    |                         ['msg.sender']                         |                               []                               |                        ['require(bool,string)']                       |            ['ERC20Helper.transferFrom(asset_,msg.sender,destination_,amount_)']            |
|          slitherConstructorConstantVariables()          |  internal  |     []    |                               []                               |                      ['HUNDRED_PERCENT']                       |                                   []                                  |                                             []                                             |
+---------------------------------------------------------+------------+-----------+----------------------------------------------------------------+----------------------------------------------------------------+-----------------------------------------------------------------------+--------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanFeeManager
Contract vars: []
Inheritance:: []
 
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         Function                        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|             payServiceFees(address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|           payOriginationFees(address,uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|         updateDelegateFeeTerms(uint256,uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|       updateRefinanceServiceFees(uint256,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|        updatePlatformServiceFee(uint256,uint256)        |  external  |     []    |  []  |   []  |       []       |       []       |
|             delegateOriginationFee(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|               delegateServiceFee(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|           delegateRefinanceServiceFee(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|     getDelegateServiceFeesForPeriod(address,uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|           getOriginationFees(address,uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|        getPlatformOriginationFee(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| getPlatformServiceFeeForPeriod(address,uint256,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|         getServiceFeeBreakdown(address,uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|             getServiceFees(address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|         getServiceFeesForPeriod(address,uint256)        |  external  |     []    |  []  |   []  |       []       |       []       |
|                        globals()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|           platformRefinanceServiceFee(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|               platformServiceFee(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IGlobalsLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               Function              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              governor()             |  external  |     []    |  []  |   []  |       []       |       []       |
|         isBorrower(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|      isFactory(bytes32,address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|           mapleTreasury()           |  external  |     []    |  []  |   []  |       []       |       []       |
| platformOriginationFeeRate(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|   platformServiceFeeRate(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILenderLike
Contract vars: []
Inheritance:: []
 
+----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------------+------------+-----------+------+-------+----------------+----------------+
| claim(uint256,uint256,uint256,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanLike
Contract vars: []
Inheritance:: []
 
+----------------------+------------+-----------+------+-------+----------------+----------------+
|       Function       | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------+------------+-----------+------+-------+----------------+----------------+
|      factory()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     fundsAsset()     |  external  |     []    |  []  |   []  |       []       |       []       |
|       lender()       |  external  |     []    |  []  |   []  |       []       |       []       |
|  paymentInterval()   |  external  |     []    |  []  |   []  |       []       |       []       |
| paymentsRemaining()  |  external  |     []    |  []  |   []  |       []       |       []       |
|     principal()      |  external  |     []    |  []  |   []  |       []       |       []       |
| principalRequested() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerLike
Contract vars: []
Inheritance:: []
 
+---------------+------------+-----------+------+-------+----------------+----------------+
|    Function   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------+------------+-----------+------+-------+----------------+----------------+
|    owner()    |  external  |     []    |  []  |   []  |       []       |       []       |
| poolManager() |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleFeeManagerLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                  Function                 | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|  updateDelegateFeeTerms(uint256,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| updatePlatformServiceFee(uint256,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------+------------+-----------+------+-------+----------------+----------------+

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


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+----------------+------------+-----------+------+-------+----------------+----------------+
|    Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------+------------+-----------+------+-------+----------------+----------------+
| poolDelegate() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------+------------+-----------+------+-------+----------------+----------------+

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
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['abi.decode()', 'code(address)']   |                                               ['token_.call(data_)', 'abi.decode(returnData,(bool))']                                               |
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


Contract IERC20
Contract vars: []
Inheritance:: []
 
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                            Function                           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                    approve(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|               decreaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
|               increaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
| permit(address,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |     []    |  []  |   []  |       []       |       []       |
|                   transfer(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             transferFrom(address,address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                   allowance(address,address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                       balanceOf(address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                           decimals()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                       DOMAIN_SEPARATOR()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                             name()                            |  external  |     []    |  []  |   []  |       []       |       []       |
|                        nonces(address)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                       PERMIT_TYPEHASH()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                            symbol()                           |  external  |     []    |  []  |   []  |       []       |       []       |
|                         totalSupply()                         |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/loan/contracts/MapleLoanFeeManager.sol analyzed (12 contracts)
