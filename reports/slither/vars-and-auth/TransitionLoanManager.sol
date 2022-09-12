
Contract TransitionLoanManager
+-------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------------------------------------------------+
|               Function              |                                                                                  State variables written                                                                                  |                              Conditions on msg.sender                             |
+-------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------------------------------------------------+
|          accountedInterest          |                                                                                             []                                                                                            |                                         []                                        |
|          allowedSlippageFor         |                                                                                             []                                                                                            |                                         []                                        |
|              domainEnd              |                                                                                             []                                                                                            |                                         []                                        |
|             domainStart             |                                                                                             []                                                                                            |                                         []                                        |
|              fundsAsset             |                                                                                             []                                                                                            |                                         []                                        |
|             issuanceRate            |                                                                                             []                                                                                            |                                         []                                        |
|           liquidationInfo           |                                                                                             []                                                                                            |                                         []                                        |
|             minRatioFor             |                                                                                             []                                                                                            |                                         []                                        |
|            paymentCounter           |                                                                                             []                                                                                            |                                         []                                        |
|             paymentIdOf             |                                                                                             []                                                                                            |                                         []                                        |
|               payments              |                                                                                             []                                                                                            |                                         []                                        |
|      paymentWithEarliestDueDate     |                                                                                             []                                                                                            |                                         []                                        |
|                 pool                |                                                                                             []                                                                                            |                                         []                                        |
|             poolManager             |                                                                                             []                                                                                            |                                         []                                        |
|             principalOut            |                                                                                             []                                                                                            |                                         []                                        |
|            sortedPayments           |                                                                                             []                                                                                            |                                         []                                        |
|           unrealizedLosses          |                                                                                             []                                                                                            |                                         []                                        |
|               _migrate              |                                                                                             []                                                                                            |                                         []                                        |
|             _setFactory             |                                                                                             []                                                                                            |                                         []                                        |
|          _setImplementation         |                                                                                             []                                                                                            |                                         []                                        |
|               _factory              |                                                                                             []                                                                                            |                                         []                                        |
|           _implementation           |                                                                                             []                                                                                            |                                         []                                        |
|        _getReferenceTypeSlot        |                                                                                             []                                                                                            |                                         []                                        |
|            _getSlotValue            |                                                                                             []                                                                                            |                                         []                                        |
|            _setSlotValue            |                                                                                             []                                                                                            |                                         []                                        |
|                 add                 |                                                                                             []                                                                                            |                                         []                                        |
|            setOwnershipTo           |                                                                                             []                                                                                            |                                         []                                        |
|            takeOwnership            |                                                                                             []                                                                                            |                                         []                                        |
|              PRECISION              |                                                                                             []                                                                                            |                                         []                                        |
|           HUNDRED_PERCENT           |                                                                                             []                                                                                            |                                         []                                        |
|        assetsUnderManagement        |                                                                                             []                                                                                            |                                         []                                        |
|          getAccruedInterest         |                                                                                             []                                                                                            |                                         []                                        |
|               globals               |                                                                                             []                                                                                            |                                         []                                        |
|            migrationAdmin           |                                                                                             []                                                                                            |                                         []                                        |
|               upgrade               |                                                                                             []                                                                                            |                                         []                                        |
|               factory               |                                                                                             []                                                                                            |                                         []                                        |
|            implementation           |                                                                                             []                                                                                            |                                         []                                        |
|          setImplementation          |                                                                                             []                                                                                            |                                         []                                        |
|               migrate               |                                                                                             []                                                                                            |                                         []                                        |
|               migrate               |                                                                                             []                                                                                            |        ['require(bool,string)(msg.sender == _factory(),LM:M:NOT_FACTORY)']        |
|          setImplementation          |                                                                                             []                                                                                            |        ['require(bool,string)(msg.sender == _factory(),LM:SI:NOT_FACTORY)']       |
|               upgrade               |                                                                                             []                                                                                            | ['require(bool,string)(msg.sender == migrationAdmin(),LM:F:NOT_MIGRATION_ADMIN)'] |
|                 add                 | ['sortedPayments', 'paymentIdOf', 'paymentWithEarliestDueDate', 'domainStart', 'issuanceRate', 'domainEnd', 'accountedInterest', '_locked', 'payments', 'principalOut', 'paymentCounter'] | ['require(bool,string)(msg.sender == migrationAdmin(),LM:F:NOT_MIGRATION_ADMIN)'] |
|            setOwnershipTo           |                                                                                             []                                                                                            | ['require(bool,string)(msg.sender == migrationAdmin(),LM:F:NOT_MIGRATION_ADMIN)'] |
|            takeOwnership            |                                                                                             []                                                                                            | ['require(bool,string)(msg.sender == migrationAdmin(),LM:F:NOT_MIGRATION_ADMIN)'] |
|          _addPaymentToList          |                                                             ['sortedPayments', 'paymentWithEarliestDueDate', 'paymentCounter']                                                            |                                         []                                        |
|        _removePaymentFromList       |                                                                      ['sortedPayments', 'paymentWithEarliestDueDate']                                                                     |                                         []                                        |
|          _queueNextPayment          |                                     ['sortedPayments', 'paymentWithEarliestDueDate', 'paymentIdOf', 'accountedInterest', 'payments', 'paymentCounter']                                    |                                         []                                        |
|        assetsUnderManagement        |                                                                                             []                                                                                            |                                         []                                        |
|               factory               |                                                                                             []                                                                                            |                                         []                                        |
|          getAccruedInterest         |                                                                                             []                                                                                            |                                         []                                        |
|               globals               |                                                                                             []                                                                                            |                                         []                                        |
|            implementation           |                                                                                             []                                                                                            |                                         []                                        |
|            migrationAdmin           |                                                                                             []                                                                                            |                                         []                                        |
|           _getNetInterest           |                                                                                             []                                                                                            |                                         []                                        |
|                 _max                |                                                                                             []                                                                                            |                                         []                                        |
|                 _min                |                                                                                             []                                                                                            |                                         []                                        |
|               _uint24               |                                                                                             []                                                                                            |                                         []                                        |
|               _uint48               |                                                                                             []                                                                                            |                                         []                                        |
|               _uint112              |                                                                                             []                                                                                            |                                         []                                        |
|               _uint128              |                                                                                             []                                                                                            |                                         []                                        |
| slitherConstructorConstantVariables |                                                          ['PRECISION', 'HUNDRED_PERCENT', 'IMPLEMENTATION_SLOT', 'FACTORY_SLOT']                                                          |                                         []                                        |
+-------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------------------------------------------------+

Contract ILoanManagerStorage
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|     accountedInterest      |            []           |            []            |
|     allowedSlippageFor     |            []           |            []            |
|         domainEnd          |            []           |            []            |
|        domainStart         |            []           |            []            |
|         fundsAsset         |            []           |            []            |
|        issuanceRate        |            []           |            []            |
|      liquidationInfo       |            []           |            []            |
|        minRatioFor         |            []           |            []            |
|       paymentCounter       |            []           |            []            |
|        paymentIdOf         |            []           |            []            |
|          payments          |            []           |            []            |
| paymentWithEarliestDueDate |            []           |            []            |
|            pool            |            []           |            []            |
|        poolManager         |            []           |            []            |
|        principalOut        |            []           |            []            |
|       sortedPayments       |            []           |            []            |
|      unrealizedLosses      |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

Contract ITransitionLoanManager
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|     accountedInterest      |            []           |            []            |
|     allowedSlippageFor     |            []           |            []            |
|         domainEnd          |            []           |            []            |
|        domainStart         |            []           |            []            |
|         fundsAsset         |            []           |            []            |
|        issuanceRate        |            []           |            []            |
|      liquidationInfo       |            []           |            []            |
|        minRatioFor         |            []           |            []            |
|       paymentCounter       |            []           |            []            |
|        paymentIdOf         |            []           |            []            |
|          payments          |            []           |            []            |
| paymentWithEarliestDueDate |            []           |            []            |
|            pool            |            []           |            []            |
|        poolManager         |            []           |            []            |
|        principalOut        |            []           |            []            |
|       sortedPayments       |            []           |            []            |
|      unrealizedLosses      |            []           |            []            |
|          upgrade           |            []           |            []            |
|          factory           |            []           |            []            |
|       implementation       |            []           |            []            |
|     setImplementation      |            []           |            []            |
|          migrate           |            []           |            []            |
|            add             |            []           |            []            |
|       setOwnershipTo       |            []           |            []            |
|       takeOwnership        |            []           |            []            |
|         PRECISION          |            []           |            []            |
|      HUNDRED_PERCENT       |            []           |            []            |
|   assetsUnderManagement    |            []           |            []            |
|     getAccruedInterest     |            []           |            []            |
|          globals           |            []           |            []            |
|       migrationAdmin       |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

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

Contract LoanManagerStorage
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|     accountedInterest      |            []           |            []            |
|     allowedSlippageFor     |            []           |            []            |
|         domainEnd          |            []           |            []            |
|        domainStart         |            []           |            []            |
|         fundsAsset         |            []           |            []            |
|        issuanceRate        |            []           |            []            |
|      liquidationInfo       |            []           |            []            |
|        minRatioFor         |            []           |            []            |
|       paymentCounter       |            []           |            []            |
|        paymentIdOf         |            []           |            []            |
|          payments          |            []           |            []            |
| paymentWithEarliestDueDate |            []           |            []            |
|            pool            |            []           |            []            |
|        poolManager         |            []           |            []            |
|        principalOut        |            []           |            []            |
|       sortedPayments       |            []           |            []            |
|      unrealizedLosses      |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

Contract MapleProxiedInternals
+-------------------------------------+-----------------------------------------+--------------------------+
|               Function              |         State variables written         | Conditions on msg.sender |
+-------------------------------------+-----------------------------------------+--------------------------+
|               _migrate              |                    []                   |            []            |
|             _setFactory             |                    []                   |            []            |
|          _setImplementation         |                    []                   |            []            |
|               _factory              |                    []                   |            []            |
|           _implementation           |                    []                   |            []            |
|        _getReferenceTypeSlot        |                    []                   |            []            |
|            _getSlotValue            |                    []                   |            []            |
|            _setSlotValue            |                    []                   |            []            |
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract IMapleProxied
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|      factory      |            []           |            []            |
|   implementation  |            []           |            []            |
| setImplementation |            []           |            []            |
|      migrate      |            []           |            []            |
|      upgrade      |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IMapleProxyFactory
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
| defaultImplementation  |            []           |            []            |
|     defaultVersion     |            []           |            []            |
|      mapleGlobals      |            []           |            []            |
| upgradeEnabledForPath  |            []           |            []            |
|     createInstance     |            []           |            []            |
|   enableUpgradePath    |            []           |            []            |
|   disableUpgradePath   |            []           |            []            |
| registerImplementation |            []           |            []            |
|   setDefaultVersion    |            []           |            []            |
|       setGlobals       |            []           |            []            |
|    upgradeInstance     |            []           |            []            |
|   getInstanceAddress   |            []           |            []            |
|    implementationOf    |            []           |            []            |
|       isInstance       |            []           |            []            |
|    migratorForPath     |            []           |            []            |
|       versionOf        |            []           |            []            |
+------------------------+-------------------------+--------------------------+

Contract ProxiedInternals
+-------------------------------------+-----------------------------------------+--------------------------+
|               Function              |         State variables written         | Conditions on msg.sender |
+-------------------------------------+-----------------------------------------+--------------------------+
|        _getReferenceTypeSlot        |                    []                   |            []            |
|            _getSlotValue            |                    []                   |            []            |
|            _setSlotValue            |                    []                   |            []            |
|               _migrate              |                    []                   |            []            |
|             _setFactory             |                    []                   |            []            |
|          _setImplementation         |                    []                   |            []            |
|               _factory              |                    []                   |            []            |
|           _implementation           |                    []                   |            []            |
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract SlotManipulatable
+-----------------------+-------------------------+--------------------------+
|        Function       | State variables written | Conditions on msg.sender |
+-----------------------+-------------------------+--------------------------+
| _getReferenceTypeSlot |            []           |            []            |
|     _getSlotValue     |            []           |            []            |
|     _setSlotValue     |            []           |            []            |
+-----------------------+-------------------------+--------------------------+

Contract IDefaultImplementationBeacon
+-----------------------+-------------------------+--------------------------+
|        Function       | State variables written | Conditions on msg.sender |
+-----------------------+-------------------------+--------------------------+
| defaultImplementation |            []           |            []            |
+-----------------------+-------------------------+--------------------------+

Contract IProxied
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|      factory      |            []           |            []            |
|   implementation  |            []           |            []            |
| setImplementation |            []           |            []            |
|      migrate      |            []           |            []            |
+-------------------+-------------------------+--------------------------+

modules/pool-v2/contracts/TransitionLoanManager.sol analyzed (24 contracts)
