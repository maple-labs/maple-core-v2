
Contract DebtLockerInitializer
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator']
Inheritance:: ['DebtLockerStorage', 'IDebtLockerInitializer']
 
+----------------------------------+------------+-----------+--------------+------------------------------------+---------------------------------------------+---------------------------------------------------------------------------------------------------------------+
|             Function             | Visibility | Modifiers |     Read     |               Write                |                Internal Calls               |                                                 External Calls                                                |
+----------------------------------+------------+-----------+--------------+------------------------------------+---------------------------------------------+---------------------------------------------------------------------------------------------------------------+
| encodeArguments(address,address) |  external  |     []    |      []      |                 []                 |                      []                     |                                                       []                                                      |
|      decodeArguments(bytes)      |  external  |     []    |      []      |                 []                 |                      []                     |                                                       []                                                      |
| encodeArguments(address,address) |  external  |     []    |      []      |                 []                 |               ['abi.encode()']              |                                          ['abi.encode(loan_,pool_)']                                          |
|      decodeArguments(bytes)      |   public   |     []    |      []      |                 []                 |               ['abi.decode()']              |                              ['abi.decode(encodedArguments_,(address,address))']                              |
|            fallback()            |  external  |     []    | ['msg.data'] |         ['_loan', '_pool']         | ['require(bool,string)', 'decodeArguments'] | ['IMapleLoanLike(loan_).principalRequested()', 'IPoolFactoryLike(IPoolLike(pool_).superFactory()).globals()'] |
|                                  |            |           |              | ['_principalRemainingAtLastClaim'] |                                             |               ['IMapleLoanLike(loan_).collateralAsset()', 'IMapleLoanLike(loan_).fundsAsset()']               |
|                                  |            |           |              |                                    |                                             |    ['globals.isValidLiquidityAsset(IMapleLoanLike(loan_).fundsAsset())', 'IPoolLike(pool_).superFactory()']   |
|                                  |            |           |              |                                    |                                             |                  ['globals.isValidCollateralAsset(IMapleLoanLike(loan_).collateralAsset())']                  |
+----------------------------------+------------+-----------+--------------+------------------------------------+---------------------------------------------+---------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract DebtLockerStorage
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator']
Inheritance:: []
 
+----------+------------+-----------+------+-------+----------------+----------------+
| Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------+------------+-----------+------+-------+----------------+----------------+
+----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IDebtLockerInitializer
Contract vars: []
Inheritance:: []
 
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function             | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
| encodeArguments(address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|      decodeArguments(bytes)      |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|     decimals()     |  external  |     []    |  []  |   []  |       []       |       []       |
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+--------------+------------+-----------+------+-------+----------------+----------------+
|   Function   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------+------------+-----------+------+-------+----------------+----------------+
| auctioneer() |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               Function              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
| defaultUniswapPath(address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|       getLatestPrice(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|            investorFee()            |  external  |     []    |  []  |   []  |       []       |       []       |
|   isValidCollateralAsset(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidLiquidityAsset(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|           mapleTreasury()           |  external  |     []    |  []  |   []  |       []       |       []       |
|           protocolPaused()          |  external  |     []    |  []  |   []  |       []       |       []       |
|            treasuryFee()            |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| acceptNewTerms(address,uint256,bytes[],uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|                 claimableFunds()                |  external  |     []    |  []  |   []  |       []       |       []       |
|           claimFunds(uint256,address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                collateralAsset()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                   fundsAsset()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                     lender()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                   principal()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|               principalRequested()              |  external  |     []    |  []  |   []  |       []       |       []       |
|                repossess(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|              refinanceCommitment()              |  external  |     []    |  []  |   []  |       []       |       []       |
|     rejectNewTerms(address,uint256,bytes[])     |  external  |     []    |  []  |   []  |       []       |       []       |
|            setPendingLender(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: []
 
+----------------+------------+-----------+------+-------+----------------+----------------+
|    Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------+------------+-----------+------+-------+----------------+----------------+
| poolDelegate() |  external  |     []    |  []  |   []  |       []       |       []       |
| superFactory() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolFactoryLike
Contract vars: []
Inheritance:: []
 
+-----------+------------+-----------+------+-------+----------------+----------------+
|  Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------+------------+-----------+------+-------+----------------+----------------+
| globals() |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IUniswapRouterLike
Contract vars: []
Inheritance:: []
 
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                               Function                              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| swapExactTokensForTokens(uint256,uint256,address[],address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/debt-locker-v4/contracts/DebtLockerInitializer.sol analyzed (10 contracts)
