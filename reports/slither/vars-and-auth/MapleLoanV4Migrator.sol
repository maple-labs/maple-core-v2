
Contract MapleLoanStorage
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
+----------+-------------------------+--------------------------+

Contract MapleLoanV4Migrator
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
|     fallback    |     ['_feeManager']     |            []            |
+-----------------+-------------------------+--------------------------+

Contract IMapleLoanV4Migrator
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
+-----------------+-------------------------+--------------------------+

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

modules/loan/contracts/MapleLoanV4Migrator.sol analyzed (11 contracts)
