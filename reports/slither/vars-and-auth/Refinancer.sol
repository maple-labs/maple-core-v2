
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
|         _clearLoanAccounting        |                              ['_lateInterestPremium', '_gracePeriod', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_lateFeeRate']                               |            []            |
|             _initialize             |  ['_fundsAsset', '_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval', '_treasuryFee', '_principalRequested', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_collateralAsset', '_lateFeeRate']  |            []            |
|              _closeLoan             | ['_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_drawableFunds', '_lateFeeRate'] |            []            |
|            _drawdownFunds           |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|             _makePayment            | ['_lateFeeRate', '_earlyFeeRate', '_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_treasuryFee', '_delegateFee', '_nextPaymentDueDate', '_interestRate', '_endingPrincipal', '_paymentsRemaining', '_drawableFunds', '_principal'] |            []            |
|           _postCollateral           |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|           _proposeNewTerms          |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|          _removeCollateral          |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|             _returnFunds            |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|           _acceptNewTerms           |                                                                                          ['_refinanceCommitment', '_refinanceInterest', '_delegateFee', '_nextPaymentDueDate', '_treasuryFee']                                                                                           |            []            |
|             _claimFunds             |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|              _fundLoan              |                                                                                                            ['_nextPaymentDueDate', '_lender', '_drawableFunds', '_principal']                                                                                                            |            []            |
|      _processEstablishmentFees      |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|           _rejectNewTerms           |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|               _sendFee              |                                                                                                                                            []                                                                                                                                            |            []            |
|        _setEstablishmentFees        |                                                                                                                             ['_delegateFee', '_treasuryFee']                                                                                                                             |            []            |
|              _repossess             |    ['_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_collateral', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_drawableFunds', '_lateFeeRate']     |            []            |
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
| slitherConstructorConstantVariables |                                                                                                                  ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT', 'SCALED_ONE']                                                                                                                   |            []            |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+

Contract Refinancer
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|               Function              |                                                                                                                                 State variables written                                                                                                                                  | Conditions on msg.sender |
+-------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------------------+
|         _clearLoanAccounting        |                              ['_lateInterestPremium', '_gracePeriod', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_lateFeeRate']                               |            []            |
|             _initialize             |  ['_fundsAsset', '_lateInterestPremium', '_borrower', '_gracePeriod', '_collateralRequired', '_paymentInterval', '_treasuryFee', '_principalRequested', '_delegateFee', '_interestRate', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_collateralAsset', '_lateFeeRate']  |            []            |
|              _closeLoan             | ['_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_drawableFunds', '_lateFeeRate'] |            []            |
|            _drawdownFunds           |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|             _makePayment            | ['_lateFeeRate', '_earlyFeeRate', '_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_refinanceInterest', '_paymentInterval', '_treasuryFee', '_delegateFee', '_nextPaymentDueDate', '_interestRate', '_endingPrincipal', '_paymentsRemaining', '_drawableFunds', '_principal'] |            []            |
|           _postCollateral           |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|           _proposeNewTerms          |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|          _removeCollateral          |                                                                                                                                     ['_collateral']                                                                                                                                      |            []            |
|             _returnFunds            |                                                                                                                                    ['_drawableFunds']                                                                                                                                    |            []            |
|           _acceptNewTerms           |                                                                                          ['_refinanceCommitment', '_refinanceInterest', '_delegateFee', '_nextPaymentDueDate', '_treasuryFee']                                                                                           |            []            |
|             _claimFunds             |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|              _fundLoan              |                                                                                                            ['_nextPaymentDueDate', '_lender', '_drawableFunds', '_principal']                                                                                                            |            []            |
|      _processEstablishmentFees      |                                                                                                                                   ['_claimableFunds']                                                                                                                                    |            []            |
|           _rejectNewTerms           |                                                                                                                                 ['_refinanceCommitment']                                                                                                                                 |            []            |
|               _sendFee              |                                                                                                                                            []                                                                                                                                            |            []            |
|        _setEstablishmentFees        |                                                                                                                             ['_delegateFee', '_treasuryFee']                                                                                                                             |            []            |
|              _repossess             |    ['_lateInterestPremium', '_claimableFunds', '_gracePeriod', '_collateral', '_paymentInterval', '_treasuryFee', '_delegateFee', '_interestRate', '_nextPaymentDueDate', '_principal', '_paymentsRemaining', '_endingPrincipal', '_earlyFeeRate', '_drawableFunds', '_lateFeeRate']     |            []            |
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
|          increasePrincipal          |                                                                                                                                            []                                                                                                                                            |            []            |
|        setCollateralRequired        |                                                                                                                                            []                                                                                                                                            |            []            |
|           setEarlyFeeRate           |                                                                                                                                            []                                                                                                                                            |            []            |
|          setEndingPrincipal         |                                                                                                                                            []                                                                                                                                            |            []            |
|            setGracePeriod           |                                                                                                                                            []                                                                                                                                            |            []            |
|           setInterestRate           |                                                                                                                                            []                                                                                                                                            |            []            |
|            setLateFeeRate           |                                                                                                                                            []                                                                                                                                            |            []            |
|        setLateInterestPremium       |                                                                                                                                            []                                                                                                                                            |            []            |
|          setPaymentInterval         |                                                                                                                                            []                                                                                                                                            |            []            |
|         setPaymentsRemaining        |                                                                                                                                            []                                                                                                                                            |            []            |
|          increasePrincipal          |                                                                                                                 ['_principalRequested', '_drawableFunds', '_principal']                                                                                                                  |            []            |
|        setCollateralRequired        |                                                                                                                                 ['_collateralRequired']                                                                                                                                  |            []            |
|           setEarlyFeeRate           |                                                                                                                                    ['_earlyFeeRate']                                                                                                                                     |            []            |
|          setEndingPrincipal         |                                                                                                                                   ['_endingPrincipal']                                                                                                                                   |            []            |
|            setGracePeriod           |                                                                                                                                     ['_gracePeriod']                                                                                                                                     |            []            |
|           setInterestRate           |                                                                                                                                    ['_interestRate']                                                                                                                                     |            []            |
|            setLateFeeRate           |                                                                                                                                     ['_lateFeeRate']                                                                                                                                     |            []            |
|        setLateInterestPremium       |                                                                                                                                 ['_lateInterestPremium']                                                                                                                                 |            []            |
|          setPaymentInterval         |                                                                                                                                   ['_paymentInterval']                                                                                                                                   |            []            |
|         setPaymentsRemaining        |                                                                                                                                  ['_paymentsRemaining']                                                                                                                                  |            []            |
| slitherConstructorConstantVariables |                                                                                                                  ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT', 'SCALED_ONE']                                                                                                                   |            []            |
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

Contract IRefinancer
+------------------------+-------------------------+--------------------------+
|        Function        | State variables written | Conditions on msg.sender |
+------------------------+-------------------------+--------------------------+
|   increasePrincipal    |            []           |            []            |
| setCollateralRequired  |            []           |            []            |
|    setEarlyFeeRate     |            []           |            []            |
|   setEndingPrincipal   |            []           |            []            |
|     setGracePeriod     |            []           |            []            |
|    setInterestRate     |            []           |            []            |
|     setLateFeeRate     |            []           |            []            |
| setLateInterestPremium |            []           |            []            |
|   setPaymentInterval   |            []           |            []            |
|  setPaymentsRemaining  |            []           |            []            |
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

modules/loan-v301/contracts/Refinancer.sol analyzed (14 contracts)
