
Contract MapleLoanStorage
Contract vars: ['_borrower', '_lender', '_pendingBorrower', '_pendingLender', '_collateralAsset', '_fundsAsset', '_gracePeriod', '_paymentInterval', '_interestRate', '_closingRate', '_lateFeeRate', '_lateInterestPremium', '_collateralRequired', '_principalRequested', '_endingPrincipal', '_drawableFunds', '__deprecated_claimableFunds', '_collateral', '_nextPaymentDueDate', '_paymentsRemaining', '_principal', '_refinanceCommitment', '_refinanceInterest', '__deprecated_delegateFee', '__deprecated_treasuryFee', '_feeManager', '_originalNextPaymentDueDate']
Inheritance:: []
 
+----------+------------+-----------+------+-------+----------------+----------------+
| Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------+------------+-----------+------+-------+----------------+----------------+
+----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract MapleLoanV4Migrator
Contract vars: ['_borrower', '_lender', '_pendingBorrower', '_pendingLender', '_collateralAsset', '_fundsAsset', '_gracePeriod', '_paymentInterval', '_interestRate', '_closingRate', '_lateFeeRate', '_lateInterestPremium', '_collateralRequired', '_principalRequested', '_endingPrincipal', '_drawableFunds', '__deprecated_claimableFunds', '_collateral', '_nextPaymentDueDate', '_paymentsRemaining', '_principal', '_refinanceCommitment', '_refinanceInterest', '__deprecated_delegateFee', '__deprecated_treasuryFee', '_feeManager', '_originalNextPaymentDueDate']
Inheritance:: ['MapleLoanStorage', 'IMapleLoanV4Migrator']
 
+--------------------------+------------+-----------+---------------------------------------------+-----------------+---------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|         Function         | Visibility | Modifiers |                     Read                    |      Write      |    Internal Calls   |                                                                            External Calls                                                                            |
+--------------------------+------------+-----------+---------------------------------------------+-----------------+---------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| encodeArguments(address) |  external  |     []    |                      []                     |        []       |          []         |                                                                                  []                                                                                  |
|  decodeArguments(bytes)  |  external  |     []    |                      []                     |        []       |          []         |                                                                                  []                                                                                  |
| encodeArguments(address) |  external  |     []    |                      []                     |        []       |   ['abi.encode()']  |                                                                     ['abi.encode(feeManager_)']                                                                      |
|  decodeArguments(bytes)  |   public   |     []    |                      []                     |        []       |   ['abi.decode()']  |                                                             ['abi.decode(encodedArguments_,(address))']                                                              |
|        fallback()        |  external  |     []    | ['__deprecated_delegateFee', '_feeManager'] | ['_feeManager'] | ['decodeArguments'] | ['IMapleFeeManagerLike(feeManager_).updatePlatformServiceFee(_principalRequested,_paymentInterval)', 'IERC20(_fundsAsset).approve(_feeManager,type()(uint256).max)'] |
|                          |            |           |     ['_fundsAsset', '_paymentInterval']     |                 |                     |                                       ['IMapleFeeManagerLike(feeManager_).updateDelegateFeeTerms(0,__deprecated_delegateFee)']                                       |
|                          |            |           |     ['_principalRequested', 'msg.data']     |                 |                     |                                                                                                                                                                      |
+--------------------------+------------+-----------+---------------------------------------------+-----------------+---------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanV4Migrator
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

modules/loan/contracts/MapleLoanV4Migrator.sol analyzed (11 contracts)
