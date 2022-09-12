
Contract MapleLoanInternals
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|               Function              |                                                                                                                                 State variables written                                                                                                                                  | Conditions on msg.sender |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|               _migrate              |                                                                                                                                            []                                                                                                                                            |            []            |
|             _setFactory             |                                                                                                                                            []                                                                                                                                            |            []            |
|          _setImplementation         |                                                                                                                                            []                                                                                                                                            |            []            |
|               _factory              |                                                                                                                                            []                                                                                                                                            |            []            |
|           _implementation           |                                                                                                                                            []                                                                                                                                            |            []            |
|        _getReferenceTypeSlot        |                                                                                                                                            []                                                                                                                                            |            []            |
|            _getSlotValue            |                                                                                                                                            []                                                                                                                                            |            []            |
|            _setSlotValue            |                                                                                                                                            []                                                                                                                                            |            []            |
|         _clearLoanAccounting        |                              ['_lateInterestPremium', '_gracePeriod', '_paymentInterval', '_nextPaymentDueDate', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_treasuryFee', '_earlyFeeRate', '_principal', '_lateFeeRate']                               |            []            |
|             _initialize             |  ['_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval', '_principalRequested', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_treasuryFee', '_earlyFeeRate', '_collateralAsset', '_lateFeeRate', '_fundsAsset']  |            []            |
|              _closeLoan             | ['_lateInterestPremium', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_nextPaymentDueDate', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_treasuryFee', '_earlyFeeRate', '_principal', '_drawableFunds', '_lateFeeRate', '_claimableFunds'] |            []            |
|            _drawdownFunds           |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|             _makePayment            | ['_lateInterestPremium', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_nextPaymentDueDate', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_treasuryFee', '_earlyFeeRate', '_principal', '_drawableFunds', '_lateFeeRate', '_claimableFunds'] |            []            |
|           _postCollateral           |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|           _proposeNewTerms          |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|          _removeCollateral          |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|             _returnFunds            |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|           _acceptNewTerms           |                                                                                          ['_refinanceInterest', '_nextPaymentDueDate', '_delegateFee', '_treasuryFee', '_refinanceCommitment']                                                                                           |            []            |
|             _claimFunds             |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|              _fundLoan              |                                                                                                            ['_lender', '_drawableFunds', '_nextPaymentDueDate', '_principal']                                                                                                            |            []            |
|      _processEstablishmentFees      |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|           _rejectNewTerms           |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|               _sendFee              |                                                                                                                                            []                                                                                                                                            |            []            |
|        _setEstablishmentFees        |                                                                                                                             ['_treasuryFee', '_delegateFee']                                                                                                                             |            []            |
|              _repossess             |    ['_lateInterestPremium', '_gracePeriod', '_collateral', '_paymentInterval', '_nextPaymentDueDate', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_treasuryFee', '_earlyFeeRate', '_principal', '_drawableFunds', '_lateFeeRate', '_claimableFunds']     |            []            |
|       _isCollateralMaintained       |                                                                                                                                            []                                                                                                                                            |            []            |
|      _getEarlyPaymentBreakdown      |                                                                                                                                            []                                                                                                                                            |            []            |
|       _getNextPaymentBreakdown      |                                                                                                                                            []                                                                                                                                            |            []            |
|        _getUnaccountedAmount        |                                                                                                                                            []                                                                                                                                            |            []            |
|            _mapleGlobals            |                                                                                                                                            []                                                                                                                                            |            []            |
|      _getCollateralRequiredFor      |                                                                                                                                            []                                                                                                                                            |            []            |
|           _getInstallment           |                                                                                                                                            []                                                                                                                                            |            []            |
|             _getInterest            |                                                                                                                                            []                                                                                                                                            |            []            |
|         _getPaymentBreakdown        |                                                                                                                                            []                                                                                                                                            |            []            |
|     _getRefinanceInterestParams     |                                                                                                                                            []                                                                                                                                            |            []            |
|           _getLateInterest          |                                                                                                                                            []                                                                                                                                            |            []            |
|       _getPeriodicInterestRate      |                                                                                                                                            []                                                                                                                                            |            []            |
|       _getRefinanceCommitment       |                                                                                                                                            []                                                                                                                                            |            []            |
|           _scaledExponent           |                                                                                                                                            []                                                                                                                                            |            []            |
| slitherConstructorConstantVariables |                                                                                                                  ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT', 'SCALED_ONE']                                                                                                                   |            []            |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+

Contract IMapleLoanFactory
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
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
|    migratorForPath     |            []           |            []            |
|       versionOf        |            []           |            []            |
| defaultImplementation  |            []           |            []            |
|         isLoan         |            []           |            []            |
+------------------------+-------------------------+--------------------------+

Contract ILenderLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| poolDelegate |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+----------------+-------------------------+--------------------------+
|    Function    | State variables written | Conditions on msg.sender |
+----------------+-------------------------+--------------------------+
|  globalAdmin   |            []           |            []            |
|    governor    |            []           |            []            |
|  investorFee   |            []           |            []            |
| mapleTreasury  |            []           |            []            |
| protocolPaused |            []           |            []            |
|  treasuryFee   |            []           |            []            |
+----------------+-------------------------+--------------------------+

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
| slitherConstructorConstantVariables | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

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
| slitherConstructorConstantVariables | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |            []            |
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

modules/loan-v301/contracts/MapleLoanInternals.sol analyzed (12 contracts)
