
Contract MapleLoanInitializer
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|               Function              |                                                                                                                                 State variables written                                                                                                                                  | Conditions on msg.sender |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|         _clearLoanAccounting        |                              ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_earlyFeeRate', '_paymentsRemaining', '_endingPrincipal', '_lateFeeRate', '_principal', '_lateInterestPremium', '_gracePeriod', '_paymentInterval']                               |            []            |
|             _initialize             |  ['_delegateFee', '_interestRate', '_principalRequested', '_treasuryFee', '_earlyFeeRate', '_paymentsRemaining', '_endingPrincipal', '_collateralAsset', '_lateFeeRate', '_fundsAsset', '_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval']  |            []            |
|              _closeLoan             | ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_earlyFeeRate', '_gracePeriod', '_endingPrincipal', '_paymentsRemaining', '_lateFeeRate', '_principal', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_refinanceInterest', '_paymentInterval'] |            []            |
|            _drawdownFunds           |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|             _makePayment            | ['_delegateFee', '_nextPaymentDueDate', '_interestRate', '_treasuryFee', '_paymentsRemaining', '_earlyFeeRate', '_endingPrincipal', '_gracePeriod', '_principal', '_lateFeeRate', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_refinanceInterest', '_paymentInterval'] |            []            |
|           _postCollateral           |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|           _proposeNewTerms          |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|          _removeCollateral          |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|             _returnFunds            |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|           _acceptNewTerms           |                                                                                          ['_delegateFee', '_nextPaymentDueDate', '_treasuryFee', '_refinanceCommitment', '_refinanceInterest']                                                                                           |            []            |
|             _claimFunds             |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|              _fundLoan              |                                                                                                            ['_principal', '_drawableFunds', '_nextPaymentDueDate', '_lender']                                                                                                            |            []            |
|      _processEstablishmentFees      |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|           _rejectNewTerms           |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|               _sendFee              |                                                                                                                                            []                                                                                                                                            |            []            |
|        _setEstablishmentFees        |                                                                                                                             ['_treasuryFee', '_delegateFee']                                                                                                                             |            []            |
|              _repossess             |    ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_paymentInterval', '_earlyFeeRate', '_gracePeriod', '_endingPrincipal', '_paymentsRemaining', '_lateFeeRate', '_principal', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_collateral']     |            []            |
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
|               _migrate              |                                                                                                                                            []                                                                                                                                            |            []            |
|             _setFactory             |                                                                                                                                            []                                                                                                                                            |            []            |
|          _setImplementation         |                                                                                                                                            []                                                                                                                                            |            []            |
|               _factory              |                                                                                                                                            []                                                                                                                                            |            []            |
|           _implementation           |                                                                                                                                            []                                                                                                                                            |            []            |
|        _getReferenceTypeSlot        |                                                                                                                                            []                                                                                                                                            |            []            |
|            _getSlotValue            |                                                                                                                                            []                                                                                                                                            |            []            |
|            _setSlotValue            |                                                                                                                                            []                                                                                                                                            |            []            |
|           encodeArguments           |                                                                                                                                            []                                                                                                                                            |            []            |
|           decodeArguments           |                                                                                                                                            []                                                                                                                                            |            []            |
|           encodeArguments           |                                                                                                                                            []                                                                                                                                            |            []            |
|           decodeArguments           |                                                                                                                                            []                                                                                                                                            |            []            |
|               fallback              |  ['_delegateFee', '_interestRate', '_principalRequested', '_treasuryFee', '_earlyFeeRate', '_paymentsRemaining', '_endingPrincipal', '_collateralAsset', '_lateFeeRate', '_fundsAsset', '_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval']  |            []            |
| slitherConstructorConstantVariables |                                                                                                                  ['SCALED_ONE', 'IMPLEMENTATION_SLOT', 'FACTORY_SLOT']                                                                                                                   |            []            |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+

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
|         _clearLoanAccounting        |                              ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_earlyFeeRate', '_paymentsRemaining', '_endingPrincipal', '_lateFeeRate', '_principal', '_lateInterestPremium', '_gracePeriod', '_paymentInterval']                               |            []            |
|             _initialize             |  ['_delegateFee', '_interestRate', '_principalRequested', '_treasuryFee', '_earlyFeeRate', '_paymentsRemaining', '_endingPrincipal', '_collateralAsset', '_lateFeeRate', '_fundsAsset', '_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval']  |            []            |
|              _closeLoan             | ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_earlyFeeRate', '_gracePeriod', '_endingPrincipal', '_paymentsRemaining', '_lateFeeRate', '_principal', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_refinanceInterest', '_paymentInterval'] |            []            |
|            _drawdownFunds           |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|             _makePayment            | ['_delegateFee', '_nextPaymentDueDate', '_interestRate', '_treasuryFee', '_paymentsRemaining', '_earlyFeeRate', '_endingPrincipal', '_gracePeriod', '_principal', '_lateFeeRate', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_refinanceInterest', '_paymentInterval'] |            []            |
|           _postCollateral           |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|           _proposeNewTerms          |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|          _removeCollateral          |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|             _returnFunds            |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|           _acceptNewTerms           |                                                                                          ['_delegateFee', '_nextPaymentDueDate', '_treasuryFee', '_refinanceCommitment', '_refinanceInterest']                                                                                           |            []            |
|             _claimFunds             |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|              _fundLoan              |                                                                                                            ['_principal', '_drawableFunds', '_nextPaymentDueDate', '_lender']                                                                                                            |            []            |
|      _processEstablishmentFees      |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|           _rejectNewTerms           |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|               _sendFee              |                                                                                                                                            []                                                                                                                                            |            []            |
|        _setEstablishmentFees        |                                                                                                                             ['_treasuryFee', '_delegateFee']                                                                                                                             |            []            |
|              _repossess             |    ['_delegateFee', '_interestRate', '_nextPaymentDueDate', '_treasuryFee', '_paymentInterval', '_earlyFeeRate', '_gracePeriod', '_endingPrincipal', '_paymentsRemaining', '_lateFeeRate', '_principal', '_drawableFunds', '_lateInterestPremium', '_claimableFunds', '_collateral']     |            []            |
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
| slitherConstructorConstantVariables |                                                                                                                  ['SCALED_ONE', 'IMPLEMENTATION_SLOT', 'FACTORY_SLOT']                                                                                                                   |            []            |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+

Contract IMapleLoanEvents
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
+----------+-------------------------+--------------------------+

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

Contract IMapleLoanInitializer
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| encodeArguments |            []           |            []            |
| decodeArguments |            []           |            []            |
+-----------------+-------------------------+--------------------------+

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
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT'] |            []            |
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

modules/loan-v301/contracts/MapleLoanInitializer.sol analyzed (15 contracts)
