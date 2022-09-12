
Contract MapleLoanFeeManager
+-------------------------------------+----------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+
|               Function              |                    State variables written                     |                                         Conditions on msg.sender                                         |
+-------------------------------------+----------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+
|            payServiceFees           |                               []                               |                                                    []                                                    |
|          payOriginationFees         |                               []                               |                                                    []                                                    |
|        updateDelegateFeeTerms       |                               []                               |                                                    []                                                    |
|      updateRefinanceServiceFees     |                               []                               |                                                    []                                                    |
|       updatePlatformServiceFee      |                               []                               |                                                    []                                                    |
|        delegateOriginationFee       |                               []                               |                                                    []                                                    |
|          delegateServiceFee         |                               []                               |                                                    []                                                    |
|     delegateRefinanceServiceFee     |                               []                               |                                                    []                                                    |
|   getDelegateServiceFeesForPeriod   |                               []                               |                                                    []                                                    |
|          getOriginationFees         |                               []                               |                                                    []                                                    |
|      getPlatformOriginationFee      |                               []                               |                                                    []                                                    |
|    getPlatformServiceFeeForPeriod   |                               []                               |                                                    []                                                    |
|        getServiceFeeBreakdown       |                               []                               |                                                    []                                                    |
|            getServiceFees           |                               []                               |                                                    []                                                    |
|       getServiceFeesForPeriod       |                               []                               |                                                    []                                                    |
|               globals               |                               []                               |                                                    []                                                    |
|     platformRefinanceServiceFee     |                               []                               |                                                    []                                                    |
|          platformServiceFee         |                               []                               |                                                    []                                                    |
|             constructor             |                          ['globals']                           |                                                    []                                                    |
|          payOriginationFees         |                               []                               | ['require(bool,string)(ERC20Helper.transferFrom(asset_,msg.sender,destination_,amount_),errorMessage_)'] |
|            payServiceFees           | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] | ['require(bool,string)(ERC20Helper.transferFrom(asset_,msg.sender,destination_,amount_),errorMessage_)'] |
|        updateDelegateFeeTerms       |        ['delegateServiceFee', 'delegateOriginationFee']        |                                                    []                                                    |
|      updateRefinanceServiceFees     | ['delegateRefinanceServiceFee', 'platformRefinanceServiceFee'] |                                                    []                                                    |
|       updatePlatformServiceFee      |                     ['platformServiceFee']                     |                                                    []                                                    |
|   getDelegateServiceFeesForPeriod   |                               []                               |                                                    []                                                    |
|      getPlatformOriginationFee      |                               []                               |                                                    []                                                    |
|    getPlatformServiceFeeForPeriod   |                               []                               |                                                    []                                                    |
|            getServiceFees           |                               []                               |                                                    []                                                    |
|        getServiceFeeBreakdown       |                               []                               |                                                    []                                                    |
|       getServiceFeesForPeriod       |                               []                               |                                                    []                                                    |
|          getOriginationFees         |                               []                               |                                                    []                                                    |
|              _getAsset              |                               []                               |                                                    []                                                    |
|      _getPlatformOriginationFee     |                               []                               |                                                    []                                                    |
|           _getPoolManager           |                               []                               |                                                    []                                                    |
|           _getPoolDelegate          |                               []                               |                                                    []                                                    |
|             _getTreasury            |                               []                               |                                                    []                                                    |
|             _transferTo             |                               []                               | ['require(bool,string)(ERC20Helper.transferFrom(asset_,msg.sender,destination_,amount_),errorMessage_)'] |
| slitherConstructorConstantVariables |                      ['HUNDRED_PERCENT']                       |                                                    []                                                    |
+-------------------------------------+----------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+

Contract IMapleLoanFeeManager
+---------------------------------+-------------------------+--------------------------+
|             Function            | State variables written | Conditions on msg.sender |
+---------------------------------+-------------------------+--------------------------+
|          payServiceFees         |            []           |            []            |
|        payOriginationFees       |            []           |            []            |
|      updateDelegateFeeTerms     |            []           |            []            |
|    updateRefinanceServiceFees   |            []           |            []            |
|     updatePlatformServiceFee    |            []           |            []            |
|      delegateOriginationFee     |            []           |            []            |
|        delegateServiceFee       |            []           |            []            |
|   delegateRefinanceServiceFee   |            []           |            []            |
| getDelegateServiceFeesForPeriod |            []           |            []            |
|        getOriginationFees       |            []           |            []            |
|    getPlatformOriginationFee    |            []           |            []            |
|  getPlatformServiceFeeForPeriod |            []           |            []            |
|      getServiceFeeBreakdown     |            []           |            []            |
|          getServiceFees         |            []           |            []            |
|     getServiceFeesForPeriod     |            []           |            []            |
|             globals             |            []           |            []            |
|   platformRefinanceServiceFee   |            []           |            []            |
|        platformServiceFee       |            []           |            []            |
+---------------------------------+-------------------------+--------------------------+

Contract IGlobalsLike
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|          governor          |            []           |            []            |
|         isBorrower         |            []           |            []            |
|         isFactory          |            []           |            []            |
|       mapleTreasury        |            []           |            []            |
| platformOriginationFeeRate |            []           |            []            |
|   platformServiceFeeRate   |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

Contract ILenderLike
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
|  claim   |            []           |            []            |
+----------+-------------------------+--------------------------+

Contract ILoanLike
+--------------------+-------------------------+--------------------------+
|      Function      | State variables written | Conditions on msg.sender |
+--------------------+-------------------------+--------------------------+
|      factory       |            []           |            []            |
|     fundsAsset     |            []           |            []            |
|       lender       |            []           |            []            |
|  paymentInterval   |            []           |            []            |
| paymentsRemaining  |            []           |            []            |
|     principal      |            []           |            []            |
| principalRequested |            []           |            []            |
+--------------------+-------------------------+--------------------------+

Contract ILoanManagerLike
+-------------+-------------------------+--------------------------+
|   Function  | State variables written | Conditions on msg.sender |
+-------------+-------------------------+--------------------------+
|    owner    |            []           |            []            |
| poolManager |            []           |            []            |
+-------------+-------------------------+--------------------------+

Contract IMapleFeeManagerLike
+--------------------------+-------------------------+--------------------------+
|         Function         | State variables written | Conditions on msg.sender |
+--------------------------+-------------------------+--------------------------+
|  updateDelegateFeeTerms  |            []           |            []            |
| updatePlatformServiceFee |            []           |            []            |
+--------------------------+-------------------------+--------------------------+

Contract IMapleProxyFactoryLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| mapleGlobals |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract IPoolManagerLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| poolDelegate |            []           |            []            |
+--------------+-------------------------+--------------------------+

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

Contract IERC20
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|      approve      |            []           |            []            |
| decreaseAllowance |            []           |            []            |
| increaseAllowance |            []           |            []            |
|       permit      |            []           |            []            |
|      transfer     |            []           |            []            |
|    transferFrom   |            []           |            []            |
|     allowance     |            []           |            []            |
|     balanceOf     |            []           |            []            |
|      decimals     |            []           |            []            |
|  DOMAIN_SEPARATOR |            []           |            []            |
|        name       |            []           |            []            |
|       nonces      |            []           |            []            |
|  PERMIT_TYPEHASH  |            []           |            []            |
|       symbol      |            []           |            []            |
|    totalSupply    |            []           |            []            |
+-------------------+-------------------------+--------------------------+

modules/loan/contracts/MapleLoanFeeManager.sol analyzed (12 contracts)
