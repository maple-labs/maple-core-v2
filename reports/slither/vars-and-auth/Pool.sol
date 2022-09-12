
Contract Pool
+-------------------------------------+--------------------------------------------------------------------------------+--------------------------+
|               Function              |                            State variables written                             | Conditions on msg.sender |
+-------------------------------------+--------------------------------------------------------------------------------+--------------------------+
|             constructor             |                         ['name', 'decimals', 'symbol']                         |            []            |
|               approve               |                                 ['allowance']                                  |            []            |
|          decreaseAllowance          |                                 ['allowance']                                  |            []            |
|          increaseAllowance          |                                 ['allowance']                                  |            []            |
|                permit               |                            ['nonces', 'allowance']                             |            []            |
|               transfer              |                                 ['balanceOf']                                  |            []            |
|             transferFrom            |                           ['balanceOf', 'allowance']                           |            []            |
|           DOMAIN_SEPARATOR          |                                       []                                       |            []            |
|               _approve              |                                 ['allowance']                                  |            []            |
|                _burn                |                          ['balanceOf', 'totalSupply']                          |            []            |
|          _decreaseAllowance         |                                 ['allowance']                                  |            []            |
|                _mint                |                          ['balanceOf', 'totalSupply']                          |            []            |
|              _transfer              |                                 ['balanceOf']                                  |            []            |
|               approve               |                                       []                                       |            []            |
|          decreaseAllowance          |                                       []                                       |            []            |
|          increaseAllowance          |                                       []                                       |            []            |
|                permit               |                                       []                                       |            []            |
|               transfer              |                                       []                                       |            []            |
|             transferFrom            |                                       []                                       |            []            |
|              allowance              |                                       []                                       |            []            |
|              balanceOf              |                                       []                                       |            []            |
|               decimals              |                                       []                                       |            []            |
|           DOMAIN_SEPARATOR          |                                       []                                       |            []            |
|                 name                |                                       []                                       |            []            |
|                nonces               |                                       []                                       |            []            |
|           PERMIT_TYPEHASH           |                                       []                                       |            []            |
|                symbol               |                                       []                                       |            []            |
|             totalSupply             |                                       []                                       |            []            |
|               manager               |                                       []                                       |            []            |
|          depositWithPermit          |                                       []                                       |            []            |
|            mintWithPermit           |                                       []                                       |            []            |
|             removeShares            |                                       []                                       |            []            |
|           requestWithdraw           |                                       []                                       |            []            |
|            requestRedeem            |                                       []                                       |            []            |
|           balanceOfAssets           |                                       []                                       |            []            |
|         convertToExitShares         |                                       []                                       |            []            |
|           unrealizedLosses          |                                       []                                       |            []            |
|                asset                |                                       []                                       |            []            |
|               deposit               |                                       []                                       |            []            |
|                 mint                |                                       []                                       |            []            |
|                redeem               |                                       []                                       |            []            |
|               withdraw              |                                       []                                       |            []            |
|           convertToAssets           |                                       []                                       |            []            |
|           convertToShares           |                                       []                                       |            []            |
|              maxDeposit             |                                       []                                       |            []            |
|               maxMint               |                                       []                                       |            []            |
|              maxRedeem              |                                       []                                       |            []            |
|             maxWithdraw             |                                       []                                       |            []            |
|            previewDeposit           |                                       []                                       |            []            |
|             previewMint             |                                       []                                       |            []            |
|            previewRedeem            |                                       []                                       |            []            |
|           previewWithdraw           |                                       []                                       |            []            |
|             totalAssets             |                                       []                                       |            []            |
|             constructor             | ['name', 'asset', 'symbol', 'manager', 'decimals', 'totalSupply', 'balanceOf'] |            []            |
|               deposit               |                    ['_locked', 'totalSupply', 'balanceOf']                     |            []            |
|          depositWithPermit          |                    ['_locked', 'totalSupply', 'balanceOf']                     |            []            |
|                 mint                |                    ['_locked', 'totalSupply', 'balanceOf']                     |            []            |
|            mintWithPermit           |                    ['_locked', 'totalSupply', 'balanceOf']                     |            []            |
|                redeem               |              ['_locked', 'totalSupply', 'balanceOf', 'allowance']              |            []            |
|               withdraw              |              ['_locked', 'totalSupply', 'balanceOf', 'allowance']              |            []            |
|               transfer              |                                 ['balanceOf']                                  |            []            |
|             transferFrom            |                           ['balanceOf', 'allowance']                           |            []            |
|             removeShares            |                                  ['_locked']                                   |            []            |
|            requestRedeem            |                            ['_locked', 'balanceOf']                            |            []            |
|           requestWithdraw           |                            ['_locked', 'balanceOf']                            |            []            |
|                _burn                |                   ['balanceOf', 'totalSupply', 'allowance']                    |            []            |
|             _divRoundUp             |                                       []                                       |            []            |
|                _mint                |                          ['balanceOf', 'totalSupply']                          |            []            |
|            _requestRedeem           |                                 ['balanceOf']                                  |            []            |
|           balanceOfAssets           |                                       []                                       |            []            |
|              maxDeposit             |                                       []                                       |            []            |
|               maxMint               |                                       []                                       |            []            |
|              maxRedeem              |                                       []                                       |            []            |
|             maxWithdraw             |                                       []                                       |            []            |
|            previewRedeem            |                                       []                                       |            []            |
|           previewWithdraw           |                                       []                                       |            []            |
|           convertToAssets           |                                       []                                       |            []            |
|           convertToShares           |                                       []                                       |            []            |
|         convertToExitShares         |                                       []                                       |            []            |
|            previewDeposit           |                                       []                                       |            []            |
|             previewMint             |                                       []                                       |            []            |
|             totalAssets             |                                       []                                       |            []            |
|           unrealizedLosses          |                                       []                                       |            []            |
|     slitherConstructorVariables     |                                  ['_locked']                                   |            []            |
| slitherConstructorConstantVariables |                              ['PERMIT_TYPEHASH']                               |            []            |
+-------------------------------------+--------------------------------------------------------------------------------+--------------------------+

Contract IERC4626
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
|       asset       |            []           |            []            |
|      deposit      |            []           |            []            |
|        mint       |            []           |            []            |
|       redeem      |            []           |            []            |
|      withdraw     |            []           |            []            |
|  convertToAssets  |            []           |            []            |
|  convertToShares  |            []           |            []            |
|     maxDeposit    |            []           |            []            |
|      maxMint      |            []           |            []            |
|     maxRedeem     |            []           |            []            |
|    maxWithdraw    |            []           |            []            |
|   previewDeposit  |            []           |            []            |
|    previewMint    |            []           |            []            |
|   previewRedeem   |            []           |            []            |
|  previewWithdraw  |            []           |            []            |
|    totalAssets    |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IPool
+---------------------+-------------------------+--------------------------+
|       Function      | State variables written | Conditions on msg.sender |
+---------------------+-------------------------+--------------------------+
|        asset        |            []           |            []            |
|       deposit       |            []           |            []            |
|         mint        |            []           |            []            |
|        redeem       |            []           |            []            |
|       withdraw      |            []           |            []            |
|   convertToAssets   |            []           |            []            |
|   convertToShares   |            []           |            []            |
|      maxDeposit     |            []           |            []            |
|       maxMint       |            []           |            []            |
|      maxRedeem      |            []           |            []            |
|     maxWithdraw     |            []           |            []            |
|    previewDeposit   |            []           |            []            |
|     previewMint     |            []           |            []            |
|    previewRedeem    |            []           |            []            |
|   previewWithdraw   |            []           |            []            |
|     totalAssets     |            []           |            []            |
|       approve       |            []           |            []            |
|  decreaseAllowance  |            []           |            []            |
|  increaseAllowance  |            []           |            []            |
|        permit       |            []           |            []            |
|       transfer      |            []           |            []            |
|     transferFrom    |            []           |            []            |
|      allowance      |            []           |            []            |
|      balanceOf      |            []           |            []            |
|       decimals      |            []           |            []            |
|   DOMAIN_SEPARATOR  |            []           |            []            |
|         name        |            []           |            []            |
|        nonces       |            []           |            []            |
|   PERMIT_TYPEHASH   |            []           |            []            |
|        symbol       |            []           |            []            |
|     totalSupply     |            []           |            []            |
|       manager       |            []           |            []            |
|  depositWithPermit  |            []           |            []            |
|    mintWithPermit   |            []           |            []            |
|     removeShares    |            []           |            []            |
|   requestWithdraw   |            []           |            []            |
|    requestRedeem    |            []           |            []            |
|   balanceOfAssets   |            []           |            []            |
| convertToExitShares |            []           |            []            |
|   unrealizedLosses  |            []           |            []            |
+---------------------+-------------------------+--------------------------+

Contract IERC20Like
+-------------+-------------------------+--------------------------+
|   Function  | State variables written | Conditions on msg.sender |
+-------------+-------------------------+--------------------------+
|  balanceOf  |            []           |            []            |
|   decimals  |            []           |            []            |
| totalSupply |            []           |            []            |
+-------------+-------------------------+--------------------------+

Contract ILoanManagerLike
+-----------------------------+-------------------------+--------------------------+
|           Function          | State variables written | Conditions on msg.sender |
+-----------------------------+-------------------------+--------------------------+
|        acceptNewTerms       |            []           |            []            |
|    assetsUnderManagement    |            []           |            []            |
|            claim            |            []           |            []            |
| finishCollateralLiquidation |            []           |            []            |
|             fund            |            []           |            []            |
|     removeDefaultWarning    |            []           |            []            |
|    triggerDefaultWarning    |            []           |            []            |
|        triggerDefault       |            []           |            []            |
|       unrealizedLosses      |            []           |            []            |
+-----------------------------+-------------------------+--------------------------+

Contract ILoanManagerInitializerLike
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract ILiquidatorLike
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
| liquidatePortion |            []           |            []            |
|    pullFunds     |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract ILoanV3Like
+-------------------------+-------------------------+--------------------------+
|         Function        | State variables written | Conditions on msg.sender |
+-------------------------+-------------------------+--------------------------+
| getNextPaymentBreakdown |            []           |            []            |
+-------------------------+-------------------------+--------------------------+

Contract ILoanLike
+---------------------------------+-------------------------+--------------------------+
|             Function            | State variables written | Conditions on msg.sender |
+---------------------------------+-------------------------+--------------------------+
|           acceptLender          |            []           |            []            |
|          acceptNewTerms         |            []           |            []            |
|         batchClaimFunds         |            []           |            []            |
|             borrower            |            []           |            []            |
|            claimFunds           |            []           |            []            |
|            collateral           |            []           |            []            |
|         collateralAsset         |            []           |            []            |
|            feeManager           |            []           |            []            |
|            fundsAsset           |            []           |            []            |
|             fundLoan            |            []           |            []            |
|    getClosingPaymentBreakdown   |            []           |            []            |
| getNextPaymentDetailedBreakdown |            []           |            []            |
|     getNextPaymentBreakdown     |            []           |            []            |
|           gracePeriod           |            []           |            []            |
|           interestRate          |            []           |            []            |
|        isInDefaultWarning       |            []           |            []            |
|           lateFeeRate           |            []           |            []            |
|        nextPaymentDueDate       |            []           |            []            |
|         paymentInterval         |            []           |            []            |
|        paymentsRemaining        |            []           |            []            |
|            principal            |            []           |            []            |
|        principalRequested       |            []           |            []            |
|        refinanceInterest        |            []           |            []            |
|       removeDefaultWarning      |            []           |            []            |
|            repossess            |            []           |            []            |
|         setPendingLender        |            []           |            []            |
|      triggerDefaultWarning      |            []           |            []            |
|     prewarningPaymentDueDate    |            []           |            []            |
+---------------------------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|       getLatestPrice       |            []           |            []            |
|          governor          |            []           |            []            |
|         isBorrower         |            []           |            []            |
|         isFactory          |            []           |            []            |
|        isPoolAsset         |            []           |            []            |
|       isPoolDelegate       |            []           |            []            |
|       isPoolDeployer       |            []           |            []            |
|    isValidScheduledCall    |            []           |            []            |
| platformManagementFeeRate  |            []           |            []            |
| maxCoverLiquidationPercent |            []           |            []            |
|       migrationAdmin       |            []           |            []            |
|       minCoverAmount       |            []           |            []            |
|       mapleTreasury        |            []           |            []            |
|      ownedPoolManager      |            []           |            []            |
|       protocolPaused       |            []           |            []            |
|  transferOwnedPoolManager  |            []           |            []            |
|       unscheduleCall       |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

Contract IMapleLoanFeeManagerLike
+--------------------+-------------------------+--------------------------+
|      Function      | State variables written | Conditions on msg.sender |
+--------------------+-------------------------+--------------------------+
| platformServiceFee |            []           |            []            |
+--------------------+-------------------------+--------------------------+

Contract IMapleProxyFactoryLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| mapleGlobals |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract IPoolDelegateCoverLike
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
| moveFunds |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract IPoolLike
+---------------------+-------------------------+--------------------------+
|       Function      | State variables written | Conditions on msg.sender |
+---------------------+-------------------------+--------------------------+
|      balanceOf      |            []           |            []            |
|       decimals      |            []           |            []            |
|     totalSupply     |            []           |            []            |
|        asset        |            []           |            []            |
|   convertToAssets   |            []           |            []            |
| convertToExitShares |            []           |            []            |
|       deposit       |            []           |            []            |
|       manager       |            []           |            []            |
|     previewMint     |            []           |            []            |
|     processExit     |            []           |            []            |
|        redeem       |            []           |            []            |
+---------------------+-------------------------+--------------------------+

Contract IPoolManagerLike
+---------------------------+-------------------------+--------------------------+
|          Function         | State variables written | Conditions on msg.sender |
+---------------------------+-------------------------+--------------------------+
|       addLoanManager      |            []           |            []            |
|          canCall          |            []           |            []            |
|    convertToExitShares    |            []           |            []            |
|           claim           |            []           |            []            |
| delegateManagementFeeRate |            []           |            []            |
|            fund           |            []           |            []            |
|      getEscrowParams      |            []           |            []            |
|          globals          |            []           |            []            |
|     hasSufficientCover    |            []           |            []            |
|        loanManager        |            []           |            []            |
|         maxDeposit        |            []           |            []            |
|          maxMint          |            []           |            []            |
|         maxRedeem         |            []           |            []            |
|        maxWithdraw        |            []           |            []            |
|       previewRedeem       |            []           |            []            |
|      previewWithdraw      |            []           |            []            |
|       processRedeem       |            []           |            []            |
|      processWithdraw      |            []           |            []            |
|        poolDelegate       |            []           |            []            |
|     poolDelegateCover     |            []           |            []            |
|     removeLoanManager     |            []           |            []            |
|        removeShares       |            []           |            []            |
|       requestRedeem       |            []           |            []            |
|    setWithdrawalManager   |            []           |            []            |
|        totalAssets        |            []           |            []            |
|      unrealizedLosses     |            []           |            []            |
|     withdrawalManager     |            []           |            []            |
+---------------------------+-------------------------+--------------------------+

Contract IWithdrawalManagerLike
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
|    addShares    |            []           |            []            |
|  isInExitWindow |            []           |            []            |
| lockedLiquidity |            []           |            []            |
|   lockedShares  |            []           |            []            |
|  previewRedeem  |            []           |            []            |
|   processExit   |            []           |            []            |
|   removeShares  |            []           |            []            |
+-----------------+-------------------------+--------------------------+

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

Contract ERC20
+-------------------------------------+--------------------------------+--------------------------+
|               Function              |    State variables written     | Conditions on msg.sender |
+-------------------------------------+--------------------------------+--------------------------+
|               approve               |               []               |            []            |
|          decreaseAllowance          |               []               |            []            |
|          increaseAllowance          |               []               |            []            |
|                permit               |               []               |            []            |
|               transfer              |               []               |            []            |
|             transferFrom            |               []               |            []            |
|              allowance              |               []               |            []            |
|              balanceOf              |               []               |            []            |
|               decimals              |               []               |            []            |
|           DOMAIN_SEPARATOR          |               []               |            []            |
|                 name                |               []               |            []            |
|                nonces               |               []               |            []            |
|           PERMIT_TYPEHASH           |               []               |            []            |
|                symbol               |               []               |            []            |
|             totalSupply             |               []               |            []            |
|             constructor             | ['name', 'decimals', 'symbol'] |            []            |
|               approve               |         ['allowance']          |            []            |
|          decreaseAllowance          |         ['allowance']          |            []            |
|          increaseAllowance          |         ['allowance']          |            []            |
|                permit               |    ['nonces', 'allowance']     |            []            |
|               transfer              |         ['balanceOf']          |            []            |
|             transferFrom            |   ['balanceOf', 'allowance']   |            []            |
|           DOMAIN_SEPARATOR          |               []               |            []            |
|               _approve              |         ['allowance']          |            []            |
|                _burn                |  ['balanceOf', 'totalSupply']  |            []            |
|          _decreaseAllowance         |         ['allowance']          |            []            |
|                _mint                |  ['balanceOf', 'totalSupply']  |            []            |
|              _transfer              |         ['balanceOf']          |            []            |
| slitherConstructorConstantVariables |      ['PERMIT_TYPEHASH']       |            []            |
+-------------------------------------+--------------------------------+--------------------------+

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

modules/pool-v2/contracts/Pool.sol analyzed (20 contracts)
