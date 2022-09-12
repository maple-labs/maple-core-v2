Compilation warnings/errors on modules/pool-v2/contracts/LoanManager.sol:
Warning: Return value of low-level calls not used.
  --> modules/pool-v2/modules/liquidations/contracts/Liquidator.sol:87:9:
   |
87 |         msg.sender.call(data_);
   |         ^^^^^^^^^^^^^^^^^^^^^^

Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/pool-v2/contracts/LoanManager.sol:21:1:
   |
21 | contract LoanManager is ILoanManager, MapleProxiedInternals, LoanManagerStorage {
   | ^ (Relevant source part starts here and spans across multiple lines).


Function not found isValidScheduledCall
Impossible to generate IR for LoanManager.upgrade
Function not found pullFunds
Impossible to generate IR for LoanManager.finishCollateralLiquidation
Function not found platformManagementFeeRate
Impossible to generate IR for LoanManager._queueNextPayment
Function not found decimals
Impossible to generate IR for LoanManager.getExpectedAmount
Function not found governor
Impossible to generate IR for LoanManager.governor
Function not found mapleTreasury
Impossible to generate IR for LoanManager.mapleTreasury

Contract LoanManager
+----------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------+
|                Function                |                                                                                             State variables written                                                                                              |                                                       Conditions on msg.sender                                                       |
+----------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------+
|           accountedInterest            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           allowedSlippageFor           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|               domainEnd                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              domainStart               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|               fundsAsset               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              issuanceRate              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|            liquidationInfo             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              minRatioFor               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             paymentCounter             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              paymentIdOf               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                payments                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|       paymentWithEarliestDueDate       |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                  pool                  |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              poolManager               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              principalOut              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             sortedPayments             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|            unrealizedLosses            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _migrate                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              _setFactory               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           _setImplementation           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _factory                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|            _implementation             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|         _getReferenceTypeSlot          |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             _getSlotValue              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             _setSlotValue              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             acceptNewTerms             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                 claim                  |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|      finishCollateralLiquidation       |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                  fund                  |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|          removeDefaultWarning          |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           setAllowedSlippage           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              setMinRatio               |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|         triggerDefaultWarning          |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             triggerDefault             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|               PRECISION                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|            HUNDRED_PERCENT             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|         assetsUnderManagement          |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           getAccruedInterest           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           getExpectedAmount            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                globals                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                governor                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|          isLiquidationActive           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              poolDelegate              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             mapleTreasury              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                upgrade                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                factory                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             implementation             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           setImplementation            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                migrate                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                migrate                 |                                                                                                        []                                                                                                        |                                 ['require(bool,string)(msg.sender == _factory(),LM:M:NOT_FACTORY)']                                  |
|           setImplementation            |                                                                                                        []                                                                                                        |                                 ['require(bool,string)(msg.sender == _factory(),LM:SI:NOT_FACTORY)']                                 |
|                upgrade                 |                                                                                                        []                                                                                                        | ['require(bool,string)(msg.sender == poolDelegate_ || msg.sender == governor(),LM:U:NOT_AUTHORIZED)', 'msg.sender == poolDelegate_'] |
|           setAllowedSlippage           |                                                                                              ['allowedSlippageFor']                                                                                              |                             ['require(bool,string)(msg.sender == poolManager,LM:SAS:NOT_POOL_MANAGER)']                              |
|              setMinRatio               |                                                                                                 ['minRatioFor']                                                                                                  |                             ['require(bool,string)(msg.sender == poolManager,LM:SMR:NOT_POOL_MANAGER)']                              |
|             acceptNewTerms             |                     ['issuanceRate', 'domainStart', 'domainEnd', 'accountedInterest', 'payments', '_locked', 'principalOut', 'sortedPayments', 'paymentIdOf', 'paymentWithEarliestDueDate']                      |                                 ['require(bool,string)(msg.sender == poolManager,LM:ANT:NOT_ADMIN)']                                 |
|                 claim                  |  ['issuanceRate', 'domainStart', 'domainEnd', 'liquidationInfo', 'accountedInterest', 'payments', '_locked', 'principalOut', 'sortedPayments', 'paymentIdOf', 'unrealizedLosses', 'paymentWithEarliestDueDate']  |                                 ['require(bool,string)(paymentIdOf[msg.sender] != 0,LM:C:NOT_LOAN)']                                 |
|                  fund                  |                             ['issuanceRate', 'domainStart', 'domainEnd', 'accountedInterest', '_locked', 'payments', 'principalOut', 'sortedPayments', 'paymentWithEarliestDueDate']                             |                              ['require(bool,string)(msg.sender == poolManager,LM:F:NOT_POOL_MANAGER)']                               |
|      finishCollateralLiquidation       |                                                                        ['unrealizedLosses', '_locked', 'liquidationInfo', 'principalOut']                                                                        |                             ['require(bool,string)(msg.sender == poolManager,LM:FCL:NOT_POOL_MANAGER)']                              |
|          removeDefaultWarning          | ['issuanceRate', 'domainStart', 'domainEnd', 'liquidationInfo', 'sortedPayments', 'accountedInterest', 'payments', '_locked', 'paymentCounter', 'paymentIdOf', 'unrealizedLosses', 'paymentWithEarliestDueDate'] |                                  ['require(bool,string)(msg.sender == poolManager,LM:RDW:NOT_PM)']                                   |
|             triggerDefault             |       ['issuanceRate', 'domainStart', 'domainEnd', 'liquidationInfo', 'accountedInterest', 'payments', 'principalOut', 'sortedPayments', 'paymentIdOf', 'unrealizedLosses', 'paymentWithEarliestDueDate']        |                              ['require(bool,string)(msg.sender == poolManager,LM:TL:NOT_POOL_MANAGER)']                              |
|         triggerDefaultWarning          |                       ['issuanceRate', 'domainStart', 'domainEnd', 'liquidationInfo', 'accountedInterest', 'payments', 'sortedPayments', 'unrealizedLosses', 'paymentWithEarliestDueDate']                       |                                  ['require(bool,string)(msg.sender == poolManager,LM:TDW:NOT_PM)']                                   |
|           _addPaymentToList            |                                                                        ['paymentCounter', 'sortedPayments', 'paymentWithEarliestDueDate']                                                                        |                                                                  []                                                                  |
|         _removePaymentFromList         |                                                                                 ['sortedPayments', 'paymentWithEarliestDueDate']                                                                                 |                                                                  []                                                                  |
|        _accountPreviousDomains         |                                          ['issuanceRate', 'domainStart', 'domainEnd', 'accountedInterest', 'payments', 'sortedPayments', 'paymentWithEarliestDueDate']                                           |                                                                  []                                                                  |
|         _accountToEndOfPayment         |                                                                           ['sortedPayments', 'payments', 'paymentWithEarliestDueDate']                                                                           |                                                                  []                                                                  |
|       _advancePaymentAccounting        |                                          ['issuanceRate', 'domainStart', 'domainEnd', 'accountedInterest', 'payments', 'sortedPayments', 'paymentWithEarliestDueDate']                                           |                                                                  []                                                                  |
|       _disburseLiquidationFunds        |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           _getAccruedAmount            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|       _getPaymentAccruedInterest       |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|          _handleClaimedFunds           |                                                                                                 ['principalOut']                                                                                                 |                                                                  []                                                                  |
|   _handleCollateralizedRepossession    |                                                        ['issuanceRate', 'domainEnd', 'accountedInterest', 'payments', 'paymentIdOf', 'unrealizedLosses']                                                         |                                                                  []                                                                  |
|  _handleUncollateralizedRepossession   |                                       ['issuanceRate', 'domainEnd', 'liquidationInfo', 'accountedInterest', 'payments', 'principalOut', 'paymentIdOf', 'unrealizedLosses']                                       |                                                                  []                                                                  |
|           _queueNextPayment            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           _recognizePayment            |                                                                      ['accountedInterest', 'sortedPayments', 'paymentWithEarliestDueDate']                                                                       |                                                                  []                                                                  |
|         _revertDefaultWarning          |                                                                                    ['accountedInterest', 'unrealizedLosses']                                                                                     |                                                                  []                                                                  |
|         _updateIssuanceParams          |                                                                                ['accountedInterest', 'domainEnd', 'issuanceRate']                                                                                |                                                                  []                                                                  |
|         assetsUnderManagement          |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                factory                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           getAccruedInterest           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|           getExpectedAmount            |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                globals                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                governor                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             implementation             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|          isLiquidationActive           |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|             mapleTreasury              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|              poolDelegate              |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|       _getDefaultInterestAndFees       |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
| _getInterestAndFeesFromLiquidationInfo |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|            _getNetInterest             |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                  _max                  |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                  _min                  |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint24                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint48                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint96                 |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint112                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint120                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|                _uint128                |                                                                                                        []                                                                                                        |                                                                  []                                                                  |
|  slitherConstructorConstantVariables   |                                                                     ['HUNDRED_PERCENT', 'IMPLEMENTATION_SLOT', 'FACTORY_SLOT', 'PRECISION']                                                                      |                                                                  []                                                                  |
+----------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------+

Contract ILoanManager
+-----------------------------+-------------------------+--------------------------+
|           Function          | State variables written | Conditions on msg.sender |
+-----------------------------+-------------------------+--------------------------+
|      accountedInterest      |            []           |            []            |
|      allowedSlippageFor     |            []           |            []            |
|          domainEnd          |            []           |            []            |
|         domainStart         |            []           |            []            |
|          fundsAsset         |            []           |            []            |
|         issuanceRate        |            []           |            []            |
|       liquidationInfo       |            []           |            []            |
|         minRatioFor         |            []           |            []            |
|        paymentCounter       |            []           |            []            |
|         paymentIdOf         |            []           |            []            |
|           payments          |            []           |            []            |
|  paymentWithEarliestDueDate |            []           |            []            |
|             pool            |            []           |            []            |
|         poolManager         |            []           |            []            |
|         principalOut        |            []           |            []            |
|        sortedPayments       |            []           |            []            |
|       unrealizedLosses      |            []           |            []            |
|           upgrade           |            []           |            []            |
|           factory           |            []           |            []            |
|        implementation       |            []           |            []            |
|      setImplementation      |            []           |            []            |
|           migrate           |            []           |            []            |
|        acceptNewTerms       |            []           |            []            |
|            claim            |            []           |            []            |
| finishCollateralLiquidation |            []           |            []            |
|             fund            |            []           |            []            |
|     removeDefaultWarning    |            []           |            []            |
|      setAllowedSlippage     |            []           |            []            |
|         setMinRatio         |            []           |            []            |
|    triggerDefaultWarning    |            []           |            []            |
|        triggerDefault       |            []           |            []            |
|          PRECISION          |            []           |            []            |
|       HUNDRED_PERCENT       |            []           |            []            |
|    assetsUnderManagement    |            []           |            []            |
|      getAccruedInterest     |            []           |            []            |
|      getExpectedAmount      |            []           |            []            |
|           globals           |            []           |            []            |
|           governor          |            []           |            []            |
|     isLiquidationActive     |            []           |            []            |
|         poolDelegate        |            []           |            []            |
|        mapleTreasury        |            []           |            []            |
+-----------------------------+-------------------------+--------------------------+

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

Contract Liquidator
+-------------------------------------+---------------------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               Function              |                       State variables written                       |                                                                                                        Conditions on msg.sender                                                                                                       |
+-------------------------------------+---------------------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|           collateralAsset           |                                  []                                 |                                                                                                                   []                                                                                                                  |
|              auctioneer             |                                  []                                 |                                                                                                                   []                                                                                                                  |
|              fundsAsset             |                                  []                                 |                                                                                                                   []                                                                                                                  |
|               globals               |                                  []                                 |                                                                                                                   []                                                                                                                  |
|                owner                |                                  []                                 |                                                                                                                   []                                                                                                                  |
|            setAuctioneer            |                                  []                                 |                                                                                                                   []                                                                                                                  |
|              pullFunds              |                                  []                                 |                                                                                                                   []                                                                                                                  |
|          getExpectedAmount          |                                  []                                 |                                                                                                                   []                                                                                                                  |
|           liquidatePortion          |                                  []                                 |                                                                                                                   []                                                                                                                  |
|             constructor             | ['fundsAsset', 'globals', 'owner', 'auctioneer', 'collateralAsset'] |                                                                                                                   []                                                                                                                  |
|            setAuctioneer            |                            ['auctioneer']                           |                                                                                     ['require(bool,string)(msg.sender == owner,LIQ:SA:NOT_OWNER)']                                                                                    |
|              pullFunds              |                                  []                                 |                                                                                     ['require(bool,string)(msg.sender == owner,LIQ:PF:NOT_OWNER)']                                                                                    |
|          getExpectedAmount          |                                  []                                 |                                                                                                                   []                                                                                                                  |
|           liquidatePortion          |                             ['_locked']                             | ['require(bool,string)(ERC20Helper.transfer(collateralAsset,msg.sender,collateralAmount_),LIQ:LP:TRANSFER)', 'require(bool,string)(ERC20Helper.transferFrom(fundsAsset,msg.sender,address(this),returnAmount),LIQ:LP:TRANSFER_FROM)'] |
| slitherConstructorConstantVariables |                       ['LOCKED', 'NOT_LOCKED']                      |                                                                                                                   []                                                                                                                  |
+-------------------------------------+---------------------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Contract ILiquidator
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|  collateralAsset  |            []           |            []            |
|     auctioneer    |            []           |            []            |
|     fundsAsset    |            []           |            []            |
|      globals      |            []           |            []            |
|       owner       |            []           |            []            |
|   setAuctioneer   |            []           |            []            |
|     pullFunds     |            []           |            []            |
| getExpectedAmount |            []           |            []            |
|  liquidatePortion |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IAuctioneerLike
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
| getExpectedAmount |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
| allowance |            []           |            []            |
|  approve  |            []           |            []            |
| balanceOf |            []           |            []            |
|  decimals |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract ILiquidatorLike
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
| getExpectedAmount |            []           |            []            |
|  liquidatePortion |            []           |            []            |
+-------------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+----------------+-------------------------+--------------------------+
|    Function    | State variables written | Conditions on msg.sender |
+----------------+-------------------------+--------------------------+
| getLatestPrice |            []           |            []            |
| protocolPaused |            []           |            []            |
+----------------+-------------------------+--------------------------+

Contract IOracleLike
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| latestRoundData |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract IUniswapRouterLike
+--------------------------+-------------------------+--------------------------+
|         Function         | State variables written | Conditions on msg.sender |
+--------------------------+-------------------------+--------------------------+
| swapExactTokensForTokens |            []           |            []            |
| swapTokensForExactTokens |            []           |            []            |
+--------------------------+-------------------------+--------------------------+

Contract DSTest
+-------------------------------------+-------------------------+--------------------------+
|               Function              | State variables written | Conditions on msg.sender |
+-------------------------------------+-------------------------+--------------------------+
|                 fail                |        ['failed']       |            []            |
|              assertTrue             |        ['failed']       |            []            |
|              assertTrue             |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|              assertEq32             |        ['failed']       |            []            |
|              assertEq32             |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|           assertEqDecimal           |        ['failed']       |            []            |
|           assertEqDecimal           |        ['failed']       |            []            |
|           assertEqDecimal           |        ['failed']       |            []            |
|           assertEqDecimal           |        ['failed']       |            []            |
|               assertGt              |        ['failed']       |            []            |
|               assertGt              |        ['failed']       |            []            |
|               assertGt              |        ['failed']       |            []            |
|               assertGt              |        ['failed']       |            []            |
|           assertGtDecimal           |        ['failed']       |            []            |
|           assertGtDecimal           |        ['failed']       |            []            |
|           assertGtDecimal           |        ['failed']       |            []            |
|           assertGtDecimal           |        ['failed']       |            []            |
|               assertGe              |        ['failed']       |            []            |
|               assertGe              |        ['failed']       |            []            |
|               assertGe              |        ['failed']       |            []            |
|               assertGe              |        ['failed']       |            []            |
|           assertGeDecimal           |        ['failed']       |            []            |
|           assertGeDecimal           |        ['failed']       |            []            |
|           assertGeDecimal           |        ['failed']       |            []            |
|           assertGeDecimal           |        ['failed']       |            []            |
|               assertLt              |        ['failed']       |            []            |
|               assertLt              |        ['failed']       |            []            |
|               assertLt              |        ['failed']       |            []            |
|               assertLt              |        ['failed']       |            []            |
|           assertLtDecimal           |        ['failed']       |            []            |
|           assertLtDecimal           |        ['failed']       |            []            |
|           assertLtDecimal           |        ['failed']       |            []            |
|           assertLtDecimal           |        ['failed']       |            []            |
|               assertLe              |        ['failed']       |            []            |
|               assertLe              |        ['failed']       |            []            |
|               assertLe              |        ['failed']       |            []            |
|               assertLe              |        ['failed']       |            []            |
|           assertLeDecimal           |        ['failed']       |            []            |
|           assertLeDecimal           |        ['failed']       |            []            |
|           assertLeDecimal           |        ['failed']       |            []            |
|           assertLeDecimal           |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               assertEq              |        ['failed']       |            []            |
|               checkEq0              |            []           |            []            |
|              assertEq0              |        ['failed']       |            []            |
|              assertEq0              |        ['failed']       |            []            |
|     slitherConstructorVariables     |       ['IS_TEST']       |            []            |
| slitherConstructorConstantVariables |     ['HEVM_ADDRESS']    |            []            |
+-------------------------------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
| balanceOf |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract Vm
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|       warp       |            []           |            []            |
|       roll       |            []           |            []            |
|       fee        |            []           |            []            |
|       load       |            []           |            []            |
|      store       |            []           |            []            |
|       sign       |            []           |            []            |
|       addr       |            []           |            []            |
|       ffi        |            []           |            []            |
|      prank       |            []           |            []            |
|    startPrank    |            []           |            []            |
|      prank       |            []           |            []            |
|    startPrank    |            []           |            []            |
|    stopPrank     |            []           |            []            |
|       deal       |            []           |            []            |
|       etch       |            []           |            []            |
|   expectRevert   |            []           |            []            |
|   expectRevert   |            []           |            []            |
|      record      |            []           |            []            |
|     accesses     |            []           |            []            |
|    expectEmit    |            []           |            []            |
|     mockCall     |            []           |            []            |
| clearMockedCalls |            []           |            []            |
|    expectCall    |            []           |            []            |
|     getCode      |            []           |            []            |
|      label       |            []           |            []            |
|      assume      |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract console
+-------------------------------------+-------------------------+--------------------------+
|               Function              | State variables written | Conditions on msg.sender |
+-------------------------------------+-------------------------+--------------------------+
|           _sendLogPayload           |            []           |            []            |
|                 log                 |            []           |            []            |
|                logInt               |            []           |            []            |
|               logUint               |            []           |            []            |
|              logString              |            []           |            []            |
|               logBool               |            []           |            []            |
|              logAddress             |            []           |            []            |
|               logBytes              |            []           |            []            |
|              logBytes1              |            []           |            []            |
|              logBytes2              |            []           |            []            |
|              logBytes3              |            []           |            []            |
|              logBytes4              |            []           |            []            |
|              logBytes5              |            []           |            []            |
|              logBytes6              |            []           |            []            |
|              logBytes7              |            []           |            []            |
|              logBytes8              |            []           |            []            |
|              logBytes9              |            []           |            []            |
|              logBytes10             |            []           |            []            |
|              logBytes11             |            []           |            []            |
|              logBytes12             |            []           |            []            |
|              logBytes13             |            []           |            []            |
|              logBytes14             |            []           |            []            |
|              logBytes15             |            []           |            []            |
|              logBytes16             |            []           |            []            |
|              logBytes17             |            []           |            []            |
|              logBytes18             |            []           |            []            |
|              logBytes19             |            []           |            []            |
|              logBytes20             |            []           |            []            |
|              logBytes21             |            []           |            []            |
|              logBytes22             |            []           |            []            |
|              logBytes23             |            []           |            []            |
|              logBytes24             |            []           |            []            |
|              logBytes25             |            []           |            []            |
|              logBytes26             |            []           |            []            |
|              logBytes27             |            []           |            []            |
|              logBytes28             |            []           |            []            |
|              logBytes29             |            []           |            []            |
|              logBytes30             |            []           |            []            |
|              logBytes31             |            []           |            []            |
|              logBytes32             |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
|                 log                 |            []           |            []            |
| slitherConstructorConstantVariables |   ['CONSOLE_ADDRESS']   |            []            |
+-------------------------------------+-------------------------+--------------------------+

Contract Address
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
+----------+-------------------------+--------------------------+

Contract TestUtils
+-------------------------------------+--------------------------------------------------------------+--------------------------+
|               Function              |                   State variables written                    | Conditions on msg.sender |
+-------------------------------------+--------------------------------------------------------------+--------------------------+
|                 fail                |                          ['failed']                          |            []            |
|              assertTrue             |                          ['failed']                          |            []            |
|              assertTrue             |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|              assertEq32             |                          ['failed']                          |            []            |
|              assertEq32             |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|           assertEqDecimal           |                          ['failed']                          |            []            |
|           assertEqDecimal           |                          ['failed']                          |            []            |
|           assertEqDecimal           |                          ['failed']                          |            []            |
|           assertEqDecimal           |                          ['failed']                          |            []            |
|               assertGt              |                          ['failed']                          |            []            |
|               assertGt              |                          ['failed']                          |            []            |
|               assertGt              |                          ['failed']                          |            []            |
|               assertGt              |                          ['failed']                          |            []            |
|           assertGtDecimal           |                          ['failed']                          |            []            |
|           assertGtDecimal           |                          ['failed']                          |            []            |
|           assertGtDecimal           |                          ['failed']                          |            []            |
|           assertGtDecimal           |                          ['failed']                          |            []            |
|               assertGe              |                          ['failed']                          |            []            |
|               assertGe              |                          ['failed']                          |            []            |
|               assertGe              |                          ['failed']                          |            []            |
|               assertGe              |                          ['failed']                          |            []            |
|           assertGeDecimal           |                          ['failed']                          |            []            |
|           assertGeDecimal           |                          ['failed']                          |            []            |
|           assertGeDecimal           |                          ['failed']                          |            []            |
|           assertGeDecimal           |                          ['failed']                          |            []            |
|               assertLt              |                          ['failed']                          |            []            |
|               assertLt              |                          ['failed']                          |            []            |
|               assertLt              |                          ['failed']                          |            []            |
|               assertLt              |                          ['failed']                          |            []            |
|           assertLtDecimal           |                          ['failed']                          |            []            |
|           assertLtDecimal           |                          ['failed']                          |            []            |
|           assertLtDecimal           |                          ['failed']                          |            []            |
|           assertLtDecimal           |                          ['failed']                          |            []            |
|               assertLe              |                          ['failed']                          |            []            |
|               assertLe              |                          ['failed']                          |            []            |
|               assertLe              |                          ['failed']                          |            []            |
|               assertLe              |                          ['failed']                          |            []            |
|           assertLeDecimal           |                          ['failed']                          |            []            |
|           assertLeDecimal           |                          ['failed']                          |            []            |
|           assertLeDecimal           |                          ['failed']                          |            []            |
|           assertLeDecimal           |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               assertEq              |                          ['failed']                          |            []            |
|               checkEq0              |                              []                              |            []            |
|              assertEq0              |                          ['failed']                          |            []            |
|              assertEq0              |                          ['failed']                          |            []            |
|               getDiff               |                              []                              |            []            |
|        assertIgnoringDecimals       |                          ['failed']                          |            []            |
|        assertWithinPrecision        |                          ['failed']                          |            []            |
|        assertWithinPercentage       |                          ['failed']                          |            []            |
|           assertWithinDiff          |                          ['failed']                          |            []            |
|           constrictToRange          |                              []                              |            []            |
|              erc20_mint             |                              []                              |            []            |
|         convertUintToString         |                              []                              |            []            |
|     slitherConstructorVariables     |                      ['vm', 'IS_TEST']                       |            []            |
| slitherConstructorConstantVariables | ['HEVM_ADDRESS', 'ZERO_DIVISION', 'RAY', 'ARITHMETIC_ERROR'] |            []            |
+-------------------------------------+--------------------------------------------------------------+--------------------------+

Contract InvariantTest
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
| addTargetContract |   ['_targetContracts']  |            []            |
|  targetContracts  |            []           |            []            |
|  excludeContract  |  ['_excludedContracts'] |            []            |
|  excludeContracts |            []           |            []            |
+-------------------+-------------------------+--------------------------+

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

modules/pool-v2/contracts/LoanManager.sol analyzed (43 contracts)
