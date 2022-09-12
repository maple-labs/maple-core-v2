
Contract DebtLockerInitializer
+-----------------+------------------------------------------------------+--------------------------+
|     Function    |               State variables written                | Conditions on msg.sender |
+-----------------+------------------------------------------------------+--------------------------+
| encodeArguments |                          []                          |            []            |
| decodeArguments |                          []                          |            []            |
| encodeArguments |                          []                          |            []            |
| decodeArguments |                          []                          |            []            |
|     fallback    | ['_principalRemainingAtLastClaim', '_loan', '_pool'] |            []            |
+-----------------+------------------------------------------------------+--------------------------+

Contract DebtLockerStorage
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
+----------+-------------------------+--------------------------+

Contract IDebtLockerInitializer
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
|  decimals |            []           |            []            |
| balanceOf |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract ILiquidatorLike
+------------+-------------------------+--------------------------+
|  Function  | State variables written | Conditions on msg.sender |
+------------+-------------------------+--------------------------+
| auctioneer |            []           |            []            |
+------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
|   defaultUniswapPath   |            []           |            []            |
|     getLatestPrice     |            []           |            []            |
|      investorFee       |            []           |            []            |
| isValidCollateralAsset |            []           |            []            |
| isValidLiquidityAsset  |            []           |            []            |
|     mapleTreasury      |            []           |            []            |
|     protocolPaused     |            []           |            []            |
|      treasuryFee       |            []           |            []            |
+------------------------+-------------------------+--------------------------+

Contract IMapleLoanLike
+---------------------+-------------------------+--------------------------+
|       Function      | State variables written | Conditions on msg.sender |
+---------------------+-------------------------+--------------------------+
|    acceptNewTerms   |            []           |            []            |
|    claimableFunds   |            []           |            []            |
|      claimFunds     |            []           |            []            |
|   collateralAsset   |            []           |            []            |
|      fundsAsset     |            []           |            []            |
|        lender       |            []           |            []            |
|      principal      |            []           |            []            |
|  principalRequested |            []           |            []            |
|      repossess      |            []           |            []            |
| refinanceCommitment |            []           |            []            |
|    rejectNewTerms   |            []           |            []            |
|   setPendingLender  |            []           |            []            |
+---------------------+-------------------------+--------------------------+

Contract IPoolLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| poolDelegate |            []           |            []            |
| superFactory |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract IPoolFactoryLike
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
| globals  |            []           |            []            |
+----------+-------------------------+--------------------------+

Contract IUniswapRouterLike
+--------------------------+-------------------------+--------------------------+
|         Function         | State variables written | Conditions on msg.sender |
+--------------------------+-------------------------+--------------------------+
| swapExactTokensForTokens |            []           |            []            |
+--------------------------+-------------------------+--------------------------+

modules/debt-locker-v4/contracts/DebtLockerInitializer.sol analyzed (10 contracts)
