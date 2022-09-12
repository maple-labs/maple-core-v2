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
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT', '_locked', 'paymentCounter', 'paymentWithEarliestDueDate', 'domainStart', 'domainEnd', 'accountedInterest', 'principalOut', 'unrealizedLosses', 'issuanceRate', 'fundsAsset', 'pool', 'poolManager', 'paymentIdOf', 'allowedSlippageFor', 'minRatioFor', 'liquidationInfo', 'payments', 'sortedPayments', 'PRECISION', 'HUNDRED_PERCENT']
Inheritance:: ['LoanManagerStorage', 'MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'ILoanManager', 'ILoanManagerStorage', 'IMapleProxied', 'IProxied']
 
+----------------------------------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+--------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                               Function                               | Visibility |    Modifiers     |                       Read                       |                      Write                       |                           Internal Calls                           |                                                                          External Calls                                                                          |
+----------------------------------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+--------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                         accountedInterest()                          |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                     allowedSlippageFor(address)                      |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                             domainEnd()                              |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            domainStart()                             |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                             fundsAsset()                             |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            issuanceRate()                            |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                       liquidationInfo(address)                       |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                         minRatioFor(address)                         |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                           paymentCounter()                           |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                         paymentIdOf(address)                         |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                          payments(uint256)                           |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                     paymentWithEarliestDueDate()                     |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                                pool()                                |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            poolManager()                             |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            principalOut()                            |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                       sortedPayments(uint256)                        |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                          unrealizedLosses()                          |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                       _migrate(address,bytes)                        |  internal  |        []        |                        []                        |                        []                        |                                 []                                 |                                                              ['migrator_.delegatecall(arguments_)']                                                              |
|                         _setFactory(address)                         |  internal  |        []        |                 ['FACTORY_SLOT']                 |                        []                        |                         ['_setSlotValue']                          |                                                                                []                                                                                |
|                     _setImplementation(address)                      |  internal  |        []        |             ['IMPLEMENTATION_SLOT']              |                        []                        |                         ['_setSlotValue']                          |                                                                                []                                                                                |
|                              _factory()                              |  internal  |        []        |                 ['FACTORY_SLOT']                 |                        []                        |                         ['_getSlotValue']                          |                                                                                []                                                                                |
|                          _implementation()                           |  internal  |        []        |             ['IMPLEMENTATION_SLOT']              |                        []                        |                         ['_getSlotValue']                          |                                                                                []                                                                                |
|                _getReferenceTypeSlot(bytes32,bytes32)                |  internal  |        []        |                        []                        |                        []                        |             ['keccak256(bytes)', 'abi.encodePacked()']             |                                                                 ['abi.encodePacked(key_,slot_)']                                                                 |
|                        _getSlotValue(bytes32)                        |  internal  |        []        |                        []                        |                        []                        |                         ['sload(uint256)']                         |                                                                                []                                                                                |
|                    _setSlotValue(bytes32,bytes32)                    |  internal  |        []        |                        []                        |                        []                        |                    ['sstore(uint256,uint256)']                     |                                                                                []                                                                                |
|           acceptNewTerms(address,address,uint256,bytes[])            |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                claim(uint256,uint256,uint256,uint256)                |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                 finishCollateralLiquidation(address)                 |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            fund(address)                             |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                  removeDefaultWarning(address,bool)                  |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                 setAllowedSlippage(address,uint256)                  |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                     setMinRatio(address,uint256)                     |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                 triggerDefaultWarning(address,bool)                  |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                       triggerDefault(address)                        |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                             PRECISION()                              |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                          HUNDRED_PERCENT()                           |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                       assetsUnderManagement()                        |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                         getAccruedInterest()                         |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                  getExpectedAmount(address,uint256)                  |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                              globals()                               |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                              governor()                              |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                     isLiquidationActive(address)                     |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            poolDelegate()                            |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                           mapleTreasury()                            |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                        upgrade(uint256,bytes)                        |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                              factory()                               |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                           implementation()                           |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                      setImplementation(address)                      |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                        migrate(address,bytes)                        |  external  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                        migrate(address,bytes)                        |  external  |        []        |                  ['msg.sender']                  |                        []                        |                ['require(bool,string)', '_migrate']                |                                                                                []                                                                                |
|                                                                      |            |                  |                                                  |                                                  |                            ['_factory']                            |                                                                                                                                                                  |
|                      setImplementation(address)                      |  external  |        []        |                  ['msg.sender']                  |                        []                        |           ['require(bool,string)', '_setImplementation']           |                                                                                []                                                                                |
|                                                                      |            |                  |                                                  |                                                  |                            ['_factory']                            |                                                                                                                                                                  |
|                        upgrade(uint256,bytes)                        |  external  |        []        |          ['poolManager', 'msg.sender']           |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                 setAllowedSlippage(address,uint256)                  |  external  |        []        |    ['HUNDRED_PERCENT', 'allowedSlippageFor']     |              ['allowedSlippageFor']              |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                                                                      |            |                  |          ['poolManager', 'msg.sender']           |                                                  |                                                                    |                                                                                                                                                                  |
|                     setMinRatio(address,uint256)                     |  external  |        []        |          ['minRatioFor', 'poolManager']          |                 ['minRatioFor']                  |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                                                                      |            |                  |                  ['msg.sender']                  |                                                  |                                                                    |                                                                                                                                                                  |
|           acceptNewTerms(address,address,uint256,bytes[])            |  external  | ['nonReentrant'] |      ['accountedInterest', 'issuanceRate']       |           ['paymentIdOf', 'payments']            |               ['_updateIssuanceParams', '_uint128']                |                                ['ILoanLike(loan_).principal()', 'ILoanLike(loan_).acceptNewTerms(refinancer_,deadline_,calls_)']                                 |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                 ['principalOut']                 |               ['nonReentrant', '_queueNextPayment']                |                                            ['ILoanLike(loan_).principal()', 'ILoanLike(loan_).nextPaymentDueDate()']                                             |
|                                                                      |            |                  |         ['poolManager', 'principalOut']          |                                                  |       ['_advancePaymentAccounting', 'require(bool,string)']        |                                                                                                                                                                  |
|                                                                      |            |                  |        ['block.timestamp', 'msg.sender']         |                                                  |                       ['_recognizePayment']                        |                                                                                                                                                                  |
|                claim(uint256,uint256,uint256,uint256)                |  external  | ['nonReentrant'] |        ['PRECISION', 'accountedInterest']        |        ['liquidationInfo', 'paymentIdOf']        |               ['_uint112', '_updateIssuanceParams']                |                                                                                []                                                                                |
|                                                                      |            |                  |       ['issuanceRate', 'liquidationInfo']        |                   ['payments']                   |               ['nonReentrant', '_queueNextPayment']                |                                                                                                                                                                  |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                                                  |       ['_advancePaymentAccounting', 'require(bool,string)']        |                                                                                                                                                                  |
|                                                                      |            |                  |        ['block.timestamp', 'msg.sender']         |                                                  |          ['_revertDefaultWarning', '_handleClaimedFunds']          |                                                                                                                                                                  |
|                                                                      |            |                  |                                                  |                                                  |                 ['_min', '_accountToEndOfPayment']                 |                                                                                                                                                                  |
|                                                                      |            |                  |                                                  |                                                  |                       ['_recognizePayment']                        |                                                                                                                                                                  |
|                            fund(address)                             |  external  | ['nonReentrant'] |      ['accountedInterest', 'issuanceRate']       |                 ['principalOut']                 |               ['_updateIssuanceParams', '_uint128']                |                                    ['ILoanLike(loanAddress_).principal()', 'ILoanLike(loanAddress_).fundLoan(address(this))']                                    |
|                                                                      |            |                  |         ['poolManager', 'principalOut']          |                                                  |               ['nonReentrant', '_queueNextPayment']                |                                                         ['ILoanLike(loanAddress_).nextPaymentDueDate()']                                                         |
|                                                                      |            |                  |        ['block.timestamp', 'msg.sender']         |                                                  |       ['_advancePaymentAccounting', 'require(bool,string)']        |                                                                                                                                                                  |
|                                                                      |            |                  |                     ['this']                     |                                                  |                                                                    |                                                                                                                                                                  |
|                 finishCollateralLiquidation(address)                 |  external  | ['nonReentrant'] |       ['accountedInterest', 'fundsAsset']        |       ['liquidationInfo', 'principalOut']        |                                 []                                 |                                                                                []                                                                                |
|                                                                      |            |                  |       ['issuanceRate', 'liquidationInfo']        |               ['unrealizedLosses']               |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |         ['poolManager', 'principalOut']          |                                                  |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |        ['unrealizedLosses', 'msg.sender']        |                                                  |                                                                    |                                                                                                                                                                  |
|                  removeDefaultWarning(address,bool)                  |  external  | ['nonReentrant'] |       ['accountedInterest', 'domainStart']       |        ['liquidationInfo', 'paymentIdOf']        |             ['_uint112', '_getPaymentAccruedInterest']             |                                                           ['ILoanLike(loan_).removeDefaultWarning()']                                                            |
|                                                                      |            |                  |       ['issuanceRate', 'liquidationInfo']        |                   ['payments']                   |           ['_addPaymentToList', '_updateIssuanceParams']           |                                                                                                                                                                  |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                                                  |           ['nonReentrant', '_advancePaymentAccounting']            |                                                                                                                                                                  |
|                                                                      |            |                  |       ['poolManager', 'unrealizedLosses']        |                                                  |         ['require(bool,string)', '_revertDefaultWarning']          |                                                                                                                                                                  |
|                                                                      |            |                  |                  ['msg.sender']                  |                                                  |                                                                    |                                                                                                                                                                  |
|                       triggerDefault(address)                        |  external  |        []        |        ['liquidationInfo', 'paymentIdOf']        |               ['liquidationInfo']                |       ['_getInterestAndFeesFromLiquidationInfo', '_uint128']       |                                            ['ILoanLike(loan_).isInDefaultWarning()', 'ILoanLike(loan_).collateral()']                                            |
|                                                                      |            |                  |           ['payments', 'poolManager']            |                                                  | ['_handleCollateralizedRepossession', '_advancePaymentAccounting'] |                                                                                                                                                                  |
|                                                                      |            |                  |                  ['msg.sender']                  |                                                  |       ['_getDefaultInterestAndFees', 'require(bool,string)']       |                                                                                                                                                                  |
|                                                                      |            |                  |                                                  |                                                  |                      ['_uint96', '_uint120']                       |                                                                                                                                                                  |
|                                                                      |            |                  |                                                  |                                                  |              ['_handleUncollateralizedRepossession']               |                                                                                                                                                                  |
|                 triggerDefaultWarning(address,bool)                  |  external  |        []        |      ['accountedInterest', 'issuanceRate']       |     ['liquidationInfo', 'unrealizedLosses']      |               ['_updateIssuanceParams', '_uint128']                |                                           ['ILoanLike(loan_).principal()', 'ILoanLike(loan_).triggerDefaultWarning()']                                           |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                                                  |    ['_advancePaymentAccounting', '_getDefaultInterestAndFees']     |                                                                                                                                                                  |
|                                                                      |            |                  |       ['poolManager', 'unrealizedLosses']        |                                                  |                ['require(bool,string)', '_uint96']                 |                                                                                                                                                                  |
|                                                                      |            |                  |                  ['msg.sender']                  |                                                  |               ['_uint120', '_removePaymentFromList']               |                                                                                                                                                                  |
|                      _addPaymentToList(uint48)                       |  internal  |        []        | ['paymentCounter', 'paymentWithEarliestDueDate'] | ['paymentCounter', 'paymentWithEarliestDueDate'] |                                 []                                 |                                                                                []                                                                                |
|                                                                      |            |                  |                ['sortedPayments']                |                ['sortedPayments']                |                                                                    |                                                                                                                                                                  |
|                   _removePaymentFromList(uint256)                    |  internal  |        []        | ['paymentWithEarliestDueDate', 'sortedPayments'] | ['paymentWithEarliestDueDate', 'sortedPayments'] |                                 []                                 |                                                                                []                                                                                |
|                      _accountPreviousDomains()                       |  internal  |        []        |        ['accountedInterest', 'domainEnd']        |        ['accountedInterest', 'domainEnd']        |                      ['_uint48', '_uint112']                       |                                                                                []                                                                                |
|                                                                      |            |                  |         ['domainStart', 'issuanceRate']          |         ['domainStart', 'issuanceRate']          |                     ['_accountToEndOfPayment']                     |                                                                                                                                                                  |
|                                                                      |            |                  |    ['paymentWithEarliestDueDate', 'payments']    |                                                  |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |      ['sortedPayments', 'block.timestamp']       |                                                  |                                                                    |                                                                                                                                                                  |
|       _accountToEndOfPayment(uint256,uint256,uint256,uint256)        |  internal  |        []        |            ['PRECISION', 'payments']             |                   ['payments']                   |                     ['_removePaymentFromList']                     |                                                                                []                                                                                |
|                     _advancePaymentAccounting()                      |  internal  |        []        |     ['accountedInterest', 'block.timestamp']     |       ['accountedInterest', 'domainStart']       |               ['_uint48', '_accountPreviousDomains']               |                                                                                []                                                                                |
|                                                                      |            |                  |                                                  |                                                  |                 ['_uint112', 'getAccruedInterest']                 |                                                                                                                                                                  |
|      _disburseLiquidationFunds(address,uint256,uint256,uint256)      |  internal  |        []        |              ['fundsAsset', 'pool']              |                        []                        |             ['require(bool,string)', 'mapleTreasury']              |                       ['ERC20Helper.transfer(fundsAsset_,mapleTreasury(),toTreasury_)', 'ERC20Helper.transfer(fundsAsset_,pool,toPool_)']                        |
|                                                                      |            |                  |                                                  |                                                  |                              ['_min']                              |                         ['ILoanLike(loan_).borrower()', 'ERC20Helper.transfer(fundsAsset_,ILoanLike(loan_).borrower(),recoveredFunds_)']                         |
|          _getAccruedAmount(uint256,uint256,uint256,uint256)          |  internal  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|     _getPaymentAccruedInterest(uint256,uint256,uint256,uint256)      |  internal  |        []        |                  ['PRECISION']                   |                        []                        |                                 []                                 |                                                                                []                                                                                |
|             _handleClaimedFunds(address,uint256,uint256)             |  internal  |        []        |        ['HUNDRED_PERCENT', 'fundsAsset']         |                 ['principalOut']                 |                ['_uint128', 'require(bool,string)']                | ['ERC20Helper.transfer(fundsAsset,pool,principal_ + interest_ - platformFee_ - delegateFee_)', 'ERC20Helper.transfer(fundsAsset,mapleTreasury(),platformFee_)']  |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                                                  |                 ['mapleTreasury', 'poolDelegate']                  |                      ['ERC20Helper.transfer(fundsAsset,poolDelegate(),delegateFee_)', 'IPoolManagerLike(poolManager).hasSufficientCover()']                      |
|                                                                      |            |                  |             ['pool', 'poolManager']              |                                                  |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |                 ['principalOut']                 |                                                  |                                                                    |                                                                                                                                                                  |
|      _handleCollateralizedRepossession(address,uint256,uint256)      |  internal  |        []        |       ['accountedInterest', 'fundsAsset']        |           ['paymentIdOf', 'payments']            |                      ['_uint128', 'globals']                       | ['new Liquidator(address(this),ILoanLike(loan_).collateralAsset(),fundsAsset,address(this),address(this),globals())', 'ILoanLike(loan_).repossess(liquidator_)'] |
|                                                                      |            |                  |         ['issuanceRate', 'paymentIdOf']          |               ['unrealizedLosses']               |                     ['_updateIssuanceParams']                      |                                            ['ILoanLike(loan_).principal()', 'ILoanLike(loan_).isInDefaultWarning()']                                             |
|                                                                      |            |                  |         ['payments', 'unrealizedLosses']         |                                                  |                                                                    |                                                              ['ILoanLike(loan_).collateralAsset()']                                                              |
|                                                                      |            |                  |                     ['this']                     |                                                  |                                                                    |                                                                                                                                                                  |
| _handleUncollateralizedRepossession(address,uint256,uint256,uint256) |  internal  |        []        |      ['accountedInterest', 'issuanceRate']       |        ['liquidationInfo', 'paymentIdOf']        |             ['_uint128', '_disburseLiquidationFunds']              |                                      ['ILoanLike(loan_).repossess(address(this))', 'ILoanLike(loan_).isInDefaultWarning()']                                      |
|                                                                      |            |                  |        ['liquidationInfo', 'paymentIdOf']        |           ['payments', 'principalOut']           |               ['_uint112', '_updateIssuanceParams']                |                                                                 ['ILoanLike(loan_).principal()']                                                                 |
|                                                                      |            |                  |           ['payments', 'principalOut']           |               ['unrealizedLosses']               |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |           ['unrealizedLosses', 'this']           |                                                  |                                                                    |                                                                                                                                                                  |
|              _queueNextPayment(address,uint256,uint256)              |  internal  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                      _recognizePayment(address)                      |  internal  |        []        |        ['PRECISION', 'accountedInterest']        |              ['accountedInterest']               |               ['_removePaymentFromList', '_uint112']               |                                                                                []                                                                                |
|                                                                      |            |                  |           ['paymentIdOf', 'payments']            |                                                  |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |               ['block.timestamp']                |                                                  |                                                                    |                                                                                                                                                                  |
|      _revertDefaultWarning(LoanManagerStorage.LiquidationInfo)       |  internal  |        []        |    ['accountedInterest', 'unrealizedLosses']     |    ['accountedInterest', 'unrealizedLosses']     |                      ['_uint128', '_uint112']                      |                                                                                []                                                                                |
|                _updateIssuanceParams(uint256,uint112)                |  internal  |        []        |        ['accountedInterest', 'domainEnd']        |        ['accountedInterest', 'domainEnd']        |                            ['_uint48']                             |                                                                                []                                                                                |
|                                                                      |            |                  |  ['issuanceRate', 'paymentWithEarliestDueDate']  |                 ['issuanceRate']                 |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |         ['payments', 'block.timestamp']          |                                                  |                                                                    |                                                                                                                                                                  |
|                       assetsUnderManagement()                        |   public   |        []        |      ['accountedInterest', 'principalOut']       |                        []                        |                       ['getAccruedInterest']                       |                                                                                []                                                                                |
|                              factory()                               |  external  |        []        |                        []                        |                        []                        |                            ['_factory']                            |                                                                                []                                                                                |
|                         getAccruedInterest()                         |   public   |        []        |            ['PRECISION', 'domainEnd']            |                        []                        |                              ['_min']                              |                                                                                []                                                                                |
|                                                                      |            |                  |         ['domainStart', 'issuanceRate']          |                                                  |                                                                    |                                                                                                                                                                  |
|                                                                      |            |                  |               ['block.timestamp']                |                                                  |                                                                    |                                                                                                                                                                  |
|                  getExpectedAmount(address,uint256)                  |   public   |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                              globals()                               |   public   |        []        |                 ['poolManager']                  |                        []                        |                                 []                                 |                                                           ['IPoolManagerLike(poolManager).globals()']                                                            |
|                              governor()                              |   public   |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                           implementation()                           |  external  |        []        |                        []                        |                        []                        |                        ['_implementation']                         |                                                                                []                                                                                |
|                     isLiquidationActive(address)                     |   public   |        []        |               ['liquidationInfo']                |                        []                        |                                 []                                 |                      ['ILoanLike(loan_).collateralAsset()', 'IERC20Like(ILoanLike(loan_).collateralAsset()).balanceOf(liquidatorAddress_)']                      |
|                           mapleTreasury()                            |   public   |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                            poolDelegate()                            |   public   |        []        |                 ['poolManager']                  |                        []                        |                                 []                                 |                                                         ['IPoolManagerLike(poolManager).poolDelegate()']                                                         |
|  _getDefaultInterestAndFees(address,LoanManagerStorage.PaymentInfo)  |  internal  |        []        |      ['HUNDRED_PERCENT', 'block.timestamp']      |                        []                        |              ['_getNetInterest', '_getAccruedAmount']              |                                                      ['ILoanLike(loan_).getNextPaymentDetailedBreakdown()']                                                      |
|                                                                      |            |                  |                                                  |                                                  |               ['_min', '_getPaymentAccruedInterest']               |                                                                                                                                                                  |
|           _getInterestAndFeesFromLiquidationInfo(address)            |  internal  |        []        |               ['liquidationInfo']                |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                   _getNetInterest(uint256,uint256)                   |  internal  |        []        |               ['HUNDRED_PERCENT']                |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                        _max(uint256,uint256)                         |  internal  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                        _min(uint256,uint256)                         |  internal  |        []        |                        []                        |                        []                        |                                 []                                 |                                                                                []                                                                                |
|                           _uint24(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                           _uint48(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                           _uint96(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                          _uint112(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                          _uint120(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                          _uint128(uint256)                           |  internal  |        []        |                        []                        |                        []                        |                      ['require(bool,string)']                      |                                                                                []                                                                                |
|                slitherConstructorConstantVariables()                 |  internal  |        []        |                        []                        |       ['FACTORY_SLOT', 'HUNDRED_PERCENT']        |                                 []                                 |                                                                                []                                                                                |
|                                                                      |            |                  |                                                  |       ['IMPLEMENTATION_SLOT', 'PRECISION']       |                                                                    |                                                                                                                                                                  |
+----------------------------------------------------------------------+------------+------------------+--------------------------------------------------+--------------------------------------------------+--------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+----------------+------------+-------------+-------------+--------------------------+----------------+
|   Modifiers    | Visibility |     Read    |    Write    |      Internal Calls      | External Calls |
+----------------+------------+-------------+-------------+--------------------------+----------------+
| nonReentrant() |  internal  | ['_locked'] | ['_locked'] | ['require(bool,string)'] |       []       |
+----------------+------------+-------------+-------------+--------------------------+----------------+


Contract ILoanManager
Contract vars: []
Inheritance:: ['ILoanManagerStorage', 'IMapleProxied', 'IProxied']
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               accountedInterest()               |  external  |     []    |  []  |   []  |       []       |       []       |
|           allowedSlippageFor(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                   domainEnd()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                  domainStart()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                   fundsAsset()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                  issuanceRate()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|             liquidationInfo(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|               minRatioFor(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                 paymentCounter()                |  external  |     []    |  []  |   []  |       []       |       []       |
|               paymentIdOf(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                payments(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|           paymentWithEarliestDueDate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|                      pool()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                  poolManager()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                  principalOut()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|             sortedPayments(uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                unrealizedLosses()               |  external  |     []    |  []  |   []  |       []       |       []       |
|              upgrade(uint256,bytes)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                    factory()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                 implementation()                |  external  |     []    |  []  |   []  |       []       |       []       |
|            setImplementation(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|              migrate(address,bytes)             |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|      claim(uint256,uint256,uint256,uint256)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       finishCollateralLiquidation(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  fund(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|        removeDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       setAllowedSlippage(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|           setMinRatio(address,uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|       triggerDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|             triggerDefault(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                   PRECISION()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                HUNDRED_PERCENT()                |  external  |     []    |  []  |   []  |       []       |       []       |
|             assetsUnderManagement()             |  external  |     []    |  []  |   []  |       []       |       []       |
|               getAccruedInterest()              |  external  |     []    |  []  |   []  |       []       |       []       |
|        getExpectedAmount(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|                    globals()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                    governor()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|           isLiquidationActive(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|                  poolDelegate()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                 mapleTreasury()                 |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerStorage
Contract vars: []
Inheritance:: []
 
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|     accountedInterest()      |  external  |     []    |  []  |   []  |       []       |       []       |
| allowedSlippageFor(address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|         domainEnd()          |  external  |     []    |  []  |   []  |       []       |       []       |
|        domainStart()         |  external  |     []    |  []  |   []  |       []       |       []       |
|         fundsAsset()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        issuanceRate()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   liquidationInfo(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|     minRatioFor(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       paymentCounter()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     paymentIdOf(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|      payments(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| paymentWithEarliestDueDate() |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolManager()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        principalOut()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   sortedPayments(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|      unrealizedLosses()      |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+--------------------+------------+-----------+------+-------+----------------+----------------+
|      Function      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------+------------+-----------+------+-------+----------------+----------------+
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|     decimals()     |  external  |     []    |  []  |   []  |       []       |       []       |
|   totalSupply()    |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| acceptNewTerms(address,address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|             assetsUnderManagement()             |  external  |     []    |  []  |   []  |       []       |       []       |
|               claim(address,bool)               |  external  |     []    |  []  |   []  |       []       |       []       |
|       finishCollateralLiquidation(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  fund(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|        removeDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       triggerDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|             triggerDefault(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                unrealizedLosses()               |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerInitializerLike
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


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
| liquidatePortion(uint256,uint256,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|    pullFunds(address,address,uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanV3Like
Contract vars: []
Inheritance:: []
 
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------+------------+-----------+------+-------+----------------+----------------+
| getNextPaymentBreakdown() |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              acceptLender()             |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|   batchClaimFunds(uint256[],address[])  |  external  |     []    |  []  |   []  |       []       |       []       |
|                borrower()               |  external  |     []    |  []  |   []  |       []       |       []       |
|       claimFunds(uint256,address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|               collateral()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            collateralAsset()            |  external  |     []    |  []  |   []  |       []       |       []       |
|               feeManager()              |  external  |     []    |  []  |   []  |       []       |       []       |
|               fundsAsset()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            fundLoan(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|       getClosingPaymentBreakdown()      |  external  |     []    |  []  |   []  |       []       |       []       |
|    getNextPaymentDetailedBreakdown()    |  external  |     []    |  []  |   []  |       []       |       []       |
|        getNextPaymentBreakdown()        |  external  |     []    |  []  |   []  |       []       |       []       |
|              gracePeriod()              |  external  |     []    |  []  |   []  |       []       |       []       |
|              interestRate()             |  external  |     []    |  []  |   []  |       []       |       []       |
|           isInDefaultWarning()          |  external  |     []    |  []  |   []  |       []       |       []       |
|              lateFeeRate()              |  external  |     []    |  []  |   []  |       []       |       []       |
|           nextPaymentDueDate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|            paymentInterval()            |  external  |     []    |  []  |   []  |       []       |       []       |
|           paymentsRemaining()           |  external  |     []    |  []  |   []  |       []       |       []       |
|               principal()               |  external  |     []    |  []  |   []  |       []       |       []       |
|           principalRequested()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           refinanceInterest()           |  external  |     []    |  []  |   []  |       []       |       []       |
|          removeDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|            repossess(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|        setPendingLender(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         triggerDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        prewarningPaymentDueDate()       |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                       Function                      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               getLatestPrice(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      governor()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isBorrower(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|              isFactory(bytes32,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isPoolAsset(address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDelegate(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDeployer(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
| isValidScheduledCall(address,address,bytes32,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|          platformManagementFeeRate(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxCoverLiquidationPercent(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|                   migrationAdmin()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|               minCoverAmount(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                   mapleTreasury()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|              ownedPoolManager(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   protocolPaused()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|      transferOwnedPoolManager(address,address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|        unscheduleCall(address,bytes32,bytes)        |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanFeeManagerLike
Contract vars: []
Inheritance:: []
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
| platformServiceFee(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

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


Contract IPoolDelegateCoverLike
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
| moveFunds(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: ['IERC20Like']
 
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                   Function                   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              balanceOf(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                  decimals()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                totalSupply()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                   asset()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|           convertToAssets(uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|         convertToExitShares(uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|           deposit(uint256,address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                  manager()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             previewMint(uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
| processExit(uint256,uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|       redeem(uint256,address,address)        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function             | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|     addLoanManager(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|  canCall(bytes32,address,bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
|   convertToExitShares(uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          claim(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|   delegateManagementFeeRate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|  fund(uint256,address,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
| getEscrowParams(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|            globals()             |  external  |     []    |  []  |   []  |       []       |       []       |
|       hasSufficientCover()       |  external  |     []    |  []  |   []  |       []       |       []       |
|          loanManager()           |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxDeposit(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxMint(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|        maxRedeem(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxWithdraw(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|  previewRedeem(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| previewWithdraw(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
| processWithdraw(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|          poolDelegate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolDelegateCover()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    removeLoanManager(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|  removeShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|  requestRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|  setWithdrawalManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          totalAssets()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        unrealizedLosses()        |  external  |     []    |  []  |   []  |       []       |       []       |
|       withdrawalManager()        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IWithdrawalManagerLike
Contract vars: []
Inheritance:: []
 
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|            Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|   addShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isInExitWindow(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       lockedLiquidity()        |  external  |     []    |  []  |   []  |       []       |       []       |
|     lockedShares(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
| previewRedeem(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processExit(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| removeShares(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract LoanManagerStorage
Contract vars: ['_locked', 'paymentCounter', 'paymentWithEarliestDueDate', 'domainStart', 'domainEnd', 'accountedInterest', 'principalOut', 'unrealizedLosses', 'issuanceRate', 'fundsAsset', 'pool', 'poolManager', 'paymentIdOf', 'allowedSlippageFor', 'minRatioFor', 'liquidationInfo', 'payments', 'sortedPayments']
Inheritance:: ['ILoanManagerStorage']
 
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------------------+------------+-----------+------+-------+----------------+----------------+
|     accountedInterest()      |  external  |     []    |  []  |   []  |       []       |       []       |
| allowedSlippageFor(address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|         domainEnd()          |  external  |     []    |  []  |   []  |       []       |       []       |
|        domainStart()         |  external  |     []    |  []  |   []  |       []       |       []       |
|         fundsAsset()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        issuanceRate()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   liquidationInfo(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|     minRatioFor(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       paymentCounter()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     paymentIdOf(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|      payments(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| paymentWithEarliestDueDate() |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolManager()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        principalOut()        |  external  |     []    |  []  |   []  |       []       |       []       |
|   sortedPayments(uint256)    |  external  |     []    |  []  |   []  |       []       |       []       |
|      unrealizedLosses()      |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['code(address)', 'abi.decode()']   |                                               ['abi.decode(returnData,(bool))', 'token_.call(data_)']                                               |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                Function               | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|        approve(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       transfer(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| transferFrom(address,address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract Liquidator
Contract vars: ['NOT_LOCKED', 'LOCKED', '_locked', 'collateralAsset', 'fundsAsset', 'globals', 'owner', 'auctioneer']
Inheritance:: ['ILiquidator']
 
+--------------------------------------------------------------+------------+-----------------------------------+-----------------------------------+-----------------------------------+-----------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
|                           Function                           | Visibility |             Modifiers             |                Read               |               Write               |                 Internal Calls                |                                                                  External Calls                                                                 |
+--------------------------------------------------------------+------------+-----------------------------------+-----------------------------------+-----------------------------------+-----------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
|                      collateralAsset()                       |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                         auctioneer()                         |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                         fundsAsset()                         |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                          globals()                           |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                           owner()                            |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                    setAuctioneer(address)                    |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|              pullFunds(address,address,uint256)              |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|                  getExpectedAmount(uint256)                  |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
|           liquidatePortion(uint256,uint256,bytes)            |  external  |                 []                |                 []                |                 []                |                       []                      |                                                                        []                                                                       |
| constructor(address,address,address,address,address,address) |   public   |                 []                |        ['globals', 'owner']       | ['auctioneer', 'collateralAsset'] |            ['require(bool,string)']           | ['ERC20Helper.approve(fundsAsset_,destination_,type()(uint256).max)', 'ERC20Helper.approve(collateralAsset_,destination_,type()(uint256).max)'] |
|                                                              |            |                                   |                                   |     ['fundsAsset', 'globals']     |                                               |                                                                                                                                                 |
|                                                              |            |                                   |                                   |             ['owner']             |                                               |                                                                                                                                                 |
|                    setAuctioneer(address)                    |  external  |                 []                |      ['auctioneer', 'owner']      |           ['auctioneer']          |            ['require(bool,string)']           |                                                                        []                                                                       |
|                                                              |            |                                   |           ['msg.sender']          |                                   |                                               |                                                                                                                                                 |
|              pullFunds(address,address,uint256)              |  external  |                 []                |      ['owner', 'msg.sender']      |                 []                |            ['require(bool,string)']           |                                              ['ERC20Helper.transfer(token_,destination_,amount_)']                                              |
|                  getExpectedAmount(uint256)                  |   public   |                 []                | ['auctioneer', 'collateralAsset'] |                 []                |                       []                      |                                  ['IAuctioneerLike(auctioneer).getExpectedAmount(collateralAsset,swapAmount_)']                                 |
|           liquidatePortion(uint256,uint256,bytes)            |  external  | ['whenProtocolNotPaused', 'lock'] | ['collateralAsset', 'fundsAsset'] |                 []                | ['require(bool,string)', 'getExpectedAmount'] |                     ['msg.sender.call(data_)', 'ERC20Helper.transferFrom(fundsAsset,msg.sender,address(this),returnAmount)']                    |
|                                                              |            |                                   |       ['msg.sender', 'this']      |                                   |       ['lock', 'whenProtocolNotPaused']       |                                      ['ERC20Helper.transfer(collateralAsset,msg.sender,collateralAmount_)']                                     |
|            slitherConstructorConstantVariables()             |  internal  |                 []                |                 []                |      ['LOCKED', 'NOT_LOCKED']     |                       []                      |                                                                        []                                                                       |
+--------------------------------------------------------------+------------+-----------------------------------+-----------------------------------+-----------------------------------+-----------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+

+-------------------------+------------+--------------------------+-------------+--------------------------+-------------------------------------------------+
|        Modifiers        | Visibility |           Read           |    Write    |      Internal Calls      |                  External Calls                 |
+-------------------------+------------+--------------------------+-------------+--------------------------+-------------------------------------------------+
| whenProtocolNotPaused() |  internal  |       ['globals']        |      []     | ['require(bool,string)'] | ['IMapleGlobalsLike(globals).protocolPaused()'] |
|          lock()         |  internal  | ['LOCKED', 'NOT_LOCKED'] | ['_locked'] | ['require(bool,string)'] |                        []                       |
|                         |            |       ['_locked']        |             |                          |                                                 |
+-------------------------+------------+--------------------------+-------------+--------------------------+-------------------------------------------------+


Contract ILiquidator
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|            collateralAsset()            |  external  |     []    |  []  |   []  |       []       |       []       |
|               auctioneer()              |  external  |     []    |  []  |   []  |       []       |       []       |
|               fundsAsset()              |  external  |     []    |  []  |   []  |       []       |       []       |
|                globals()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                 owner()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|          setAuctioneer(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|    pullFunds(address,address,uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|        getExpectedAmount(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| liquidatePortion(uint256,uint256,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IAuctioneerLike
Contract vars: []
Inheritance:: []
 
+------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              Function              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+------------------------------------+------------+-----------+------+-------+----------------+----------------+
| getExpectedAmount(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
| allowance(address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|  approve(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
|     balanceOf(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|         decimals()         |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|        getExpectedAmount(uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| liquidatePortion(uint256,uint256,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-------------------------+------------+-----------+------+-------+----------------+----------------+
|         Function        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------+------------+-----------+------+-------+----------------+----------------+
| getLatestPrice(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|     protocolPaused()    |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IOracleLike
Contract vars: []
Inheritance:: []
 
+-------------------+------------+-----------+------+-------+----------------+----------------+
|      Function     | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------+------------+-----------+------+-------+----------------+----------------+
| latestRoundData() |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IUniswapRouterLike
Contract vars: []
Inheritance:: []
 
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                               Function                              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| swapExactTokensForTokens(uint256,uint256,address[],address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
| swapTokensForExactTokens(uint256,uint256,address[],address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract DSTest
Contract vars: ['IS_TEST', 'failed', 'HEVM_ADDRESS']
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+------------------+--------------------------------------------+------------------------------------------------+
|                     Function                    | Visibility | Modifiers | Read |      Write       |               Internal Calls               |                 External Calls                 |
+-------------------------------------------------+------------+-----------+------+------------------+--------------------------------------------+------------------------------------------------+
|                      fail()                     |  internal  |     []    |  []  |    ['failed']    |                     []                     |                       []                       |
|                 assertTrue(bool)                |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|             assertTrue(bool,string)             |  internal  |     []    |  []  |        []        |               ['assertTrue']               |                       []                       |
|            assertEq(address,address)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertEq(address,address,string)        |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|            assertEq(bytes32,bytes32)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertEq(bytes32,bytes32,string)        |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|           assertEq32(bytes32,bytes32)           |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|        assertEq32(bytes32,bytes32,string)       |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|             assertEq(int256,int256)             |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|          assertEq(int256,int256,string)         |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|            assertEq(uint256,uint256)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertEq(uint256,uint256,string)        |  internal  |     []    |  []  |        []        |                ['assertEq']                |                       []                       |
|      assertEqDecimal(int256,int256,uint256)     |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|  assertEqDecimal(int256,int256,uint256,string)  |  internal  |     []    |  []  |        []        |            ['assertEqDecimal']             |                       []                       |
|     assertEqDecimal(uint256,uint256,uint256)    |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
| assertEqDecimal(uint256,uint256,uint256,string) |  internal  |     []    |  []  |        []        |            ['assertEqDecimal']             |                       []                       |
|            assertGt(uint256,uint256)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertGt(uint256,uint256,string)        |  internal  |     []    |  []  |        []        |                ['assertGt']                |                       []                       |
|             assertGt(int256,int256)             |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|          assertGt(int256,int256,string)         |  internal  |     []    |  []  |        []        |                ['assertGt']                |                       []                       |
|      assertGtDecimal(int256,int256,uint256)     |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|  assertGtDecimal(int256,int256,uint256,string)  |  internal  |     []    |  []  |        []        |            ['assertGtDecimal']             |                       []                       |
|     assertGtDecimal(uint256,uint256,uint256)    |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
| assertGtDecimal(uint256,uint256,uint256,string) |  internal  |     []    |  []  |        []        |            ['assertGtDecimal']             |                       []                       |
|            assertGe(uint256,uint256)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertGe(uint256,uint256,string)        |  internal  |     []    |  []  |        []        |                ['assertGe']                |                       []                       |
|             assertGe(int256,int256)             |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|          assertGe(int256,int256,string)         |  internal  |     []    |  []  |        []        |                ['assertGe']                |                       []                       |
|      assertGeDecimal(int256,int256,uint256)     |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|  assertGeDecimal(int256,int256,uint256,string)  |  internal  |     []    |  []  |        []        |            ['assertGeDecimal']             |                       []                       |
|     assertGeDecimal(uint256,uint256,uint256)    |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
| assertGeDecimal(uint256,uint256,uint256,string) |  internal  |     []    |  []  |        []        |            ['assertGeDecimal']             |                       []                       |
|            assertLt(uint256,uint256)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertLt(uint256,uint256,string)        |  internal  |     []    |  []  |        []        |                ['assertLt']                |                       []                       |
|             assertLt(int256,int256)             |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|          assertLt(int256,int256,string)         |  internal  |     []    |  []  |        []        |                ['assertLt']                |                       []                       |
|      assertLtDecimal(int256,int256,uint256)     |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|  assertLtDecimal(int256,int256,uint256,string)  |  internal  |     []    |  []  |        []        |            ['assertLtDecimal']             |                       []                       |
|     assertLtDecimal(uint256,uint256,uint256)    |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
| assertLtDecimal(uint256,uint256,uint256,string) |  internal  |     []    |  []  |        []        |            ['assertLtDecimal']             |                       []                       |
|            assertLe(uint256,uint256)            |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|         assertLe(uint256,uint256,string)        |  internal  |     []    |  []  |        []        |                ['assertLe']                |                       []                       |
|             assertLe(int256,int256)             |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|          assertLe(int256,int256,string)         |  internal  |     []    |  []  |        []        |                ['assertLe']                |                       []                       |
|      assertLeDecimal(int256,int256,uint256)     |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
|  assertLeDecimal(int256,int256,uint256,string)  |  internal  |     []    |  []  |        []        |            ['assertLeDecimal']             |                       []                       |
|     assertLeDecimal(uint256,uint256,uint256)    |  internal  |     []    |  []  |        []        |                  ['fail']                  |                       []                       |
| assertLeDecimal(uint256,uint256,uint256,string) |  internal  |     []    |  []  |        []        |            ['assertGeDecimal']             |                       []                       |
|             assertEq(string,string)             |  internal  |     []    |  []  |        []        | ['keccak256(bytes)', 'abi.encodePacked()'] | ['abi.encodePacked(a)', 'abi.encodePacked(b)'] |
|                                                 |            |           |      |                  |                  ['fail']                  |                                                |
|          assertEq(string,string,string)         |  internal  |     []    |  []  |        []        | ['keccak256(bytes)', 'abi.encodePacked()'] | ['abi.encodePacked(b)', 'abi.encodePacked(a)'] |
|                                                 |            |           |      |                  |                ['assertEq']                |                                                |
|              checkEq0(bytes,bytes)              |  internal  |     []    |  []  |        []        |                     []                     |                       []                       |
|              assertEq0(bytes,bytes)             |  internal  |     []    |  []  |        []        |            ['checkEq0', 'fail']            |                       []                       |
|          assertEq0(bytes,bytes,string)          |  internal  |     []    |  []  |        []        |         ['assertEq0', 'checkEq0']          |                       []                       |
|          slitherConstructorVariables()          |  internal  |     []    |  []  |   ['IS_TEST']    |                     []                     |                       []                       |
|      slitherConstructorConstantVariables()      |  internal  |     []    |  []  | ['HEVM_ADDRESS'] |            ['keccak256(bytes)']            |                       []                       |
+-------------------------------------------------+------------+-----------+------+------------------+--------------------------------------------+------------------------------------------------+

+------------------+------------+------+-------+----------------+----------------+
|    Modifiers     | Visibility | Read | Write | Internal Calls | External Calls |
+------------------+------------+------+-------+----------------+----------------+
|   mayRevert()    |  internal  |  []  |   []  |       []       |       []       |
| testopts(string) |  internal  |  []  |   []  |       []       |       []       |
|    logs_gas()    |  internal  |  []  |   []  | ['gasleft()']  |       []       |
+------------------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+--------------------+------------+-----------+------+-------+----------------+----------------+
|      Function      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------+------------+-----------+------+-------+----------------+----------------+
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract Vm
Contract vars: []
Inheritance:: []
 
+---------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------+------------+-----------+------+-------+----------------+----------------+
|          warp(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|          roll(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|           fee(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|      load(address,bytes32)      |  external  |     []    |  []  |   []  |       []       |       []       |
|  store(address,bytes32,bytes32) |  external  |     []    |  []  |   []  |       []       |       []       |
|      sign(uint256,bytes32)      |  external  |     []    |  []  |   []  |       []       |       []       |
|          addr(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|          ffi(string[])          |  external  |     []    |  []  |   []  |       []       |       []       |
|          prank(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|       startPrank(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|      prank(address,address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|   startPrank(address,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|           stopPrank()           |  external  |     []    |  []  |   []  |       []       |       []       |
|      deal(address,uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|       etch(address,bytes)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       expectRevert(bytes)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       expectRevert(bytes4)      |  external  |     []    |  []  |   []  |       []       |       []       |
|             record()            |  external  |     []    |  []  |   []  |       []       |       []       |
|        accesses(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
| expectEmit(bool,bool,bool,bool) |  external  |     []    |  []  |   []  |       []       |       []       |
|  mockCall(address,bytes,bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
|        clearMockedCalls()       |  external  |     []    |  []  |   []  |       []       |       []       |
|    expectCall(address,bytes)    |  external  |     []    |  []  |   []  |       []       |       []       |
|         getCode(string)         |  external  |     []    |  []  |   []  |       []       |       []       |
|      label(address,string)      |  external  |     []    |  []  |   []  |       []       |       []       |
|           assume(bool)          |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract console
Contract vars: ['CONSOLE_ADDRESS']
Inheritance:: []
 
+---------------------------------------+------------+-----------+---------------------+---------------------+--------------------------------------------------------------------------+-------------------------------------------------------------------------------+
|                Function               | Visibility | Modifiers |         Read        |        Write        |                              Internal Calls                              |                                 External Calls                                |
+---------------------------------------+------------+-----------+---------------------+---------------------+--------------------------------------------------------------------------+-------------------------------------------------------------------------------+
|         _sendLogPayload(bytes)        |  private   |     []    | ['CONSOLE_ADDRESS'] |          []         | ['staticcall(uint256,uint256,uint256,uint256,uint256,uint256)', 'gas()'] |                                       []                                      |
|                 log()                 |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                       ['abi.encodeWithSignature(log())']                      |
|             logInt(int256)            |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                    ['abi.encodeWithSignature(log(int),p0)']                   |
|            logUint(uint256)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                   ['abi.encodeWithSignature(log(uint),p0)']                   |
|           logString(string)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(string),p0)']                  |
|             logBool(bool)             |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                   ['abi.encodeWithSignature(log(bool),p0)']                   |
|          logAddress(address)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(address),p0)']                 |
|            logBytes(bytes)            |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                   ['abi.encodeWithSignature(log(bytes),p0)']                  |
|           logBytes1(bytes1)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes1),p0)']                  |
|           logBytes2(bytes2)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes2),p0)']                  |
|           logBytes3(bytes3)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes3),p0)']                  |
|           logBytes4(bytes4)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes4),p0)']                  |
|           logBytes5(bytes5)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes5),p0)']                  |
|           logBytes6(bytes6)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes6),p0)']                  |
|           logBytes7(bytes7)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes7),p0)']                  |
|           logBytes8(bytes8)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes8),p0)']                  |
|           logBytes9(bytes9)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes9),p0)']                  |
|          logBytes10(bytes10)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes10),p0)']                 |
|          logBytes11(bytes11)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes11),p0)']                 |
|          logBytes12(bytes12)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes12),p0)']                 |
|          logBytes13(bytes13)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes13),p0)']                 |
|          logBytes14(bytes14)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes14),p0)']                 |
|          logBytes15(bytes15)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes15),p0)']                 |
|          logBytes16(bytes16)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes16),p0)']                 |
|          logBytes17(bytes17)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes17),p0)']                 |
|          logBytes18(bytes18)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes18),p0)']                 |
|          logBytes19(bytes19)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes19),p0)']                 |
|          logBytes20(bytes20)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes20),p0)']                 |
|          logBytes21(bytes21)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes21),p0)']                 |
|          logBytes22(bytes22)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes22),p0)']                 |
|          logBytes23(bytes23)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes23),p0)']                 |
|          logBytes24(bytes24)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes24),p0)']                 |
|          logBytes25(bytes25)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes25),p0)']                 |
|          logBytes26(bytes26)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes26),p0)']                 |
|          logBytes27(bytes27)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes27),p0)']                 |
|          logBytes28(bytes28)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes28),p0)']                 |
|          logBytes29(bytes29)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes29),p0)']                 |
|          logBytes30(bytes30)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes30),p0)']                 |
|          logBytes31(bytes31)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes31),p0)']                 |
|          logBytes32(bytes32)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(bytes32),p0)']                 |
|              log(uint256)             |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                   ['abi.encodeWithSignature(log(uint),p0)']                   |
|              log(string)              |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(string),p0)']                  |
|               log(bool)               |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                   ['abi.encodeWithSignature(log(bool),p0)']                   |
|              log(address)             |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |                  ['abi.encodeWithSignature(log(address),p0)']                 |
|          log(uint256,uint256)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |               ['abi.encodeWithSignature(log(uint,uint),p0,p1)']               |
|          log(uint256,string)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(uint,string),p0,p1)']              |
|           log(uint256,bool)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |               ['abi.encodeWithSignature(log(uint,bool),p0,p1)']               |
|          log(uint256,address)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(uint,address),p0,p1)']             |
|          log(string,uint256)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(string,uint),p0,p1)']              |
|           log(string,string)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |             ['abi.encodeWithSignature(log(string,string),p0,p1)']             |
|            log(string,bool)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(string,bool),p0,p1)']              |
|          log(string,address)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |             ['abi.encodeWithSignature(log(string,address),p0,p1)']            |
|           log(bool,uint256)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |               ['abi.encodeWithSignature(log(bool,uint),p0,p1)']               |
|            log(bool,string)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(bool,string),p0,p1)']              |
|             log(bool,bool)            |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |               ['abi.encodeWithSignature(log(bool,bool),p0,p1)']               |
|           log(bool,address)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(bool,address),p0,p1)']             |
|          log(address,uint256)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(address,uint),p0,p1)']             |
|          log(address,string)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |             ['abi.encodeWithSignature(log(address,string),p0,p1)']            |
|           log(address,bool)           |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |              ['abi.encodeWithSignature(log(address,bool),p0,p1)']             |
|          log(address,address)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |            ['abi.encodeWithSignature(log(address,address),p0,p1)']            |
|      log(uint256,uint256,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(uint,uint,uint),p0,p1,p2)']           |
|      log(uint256,uint256,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,uint,string),p0,p1,p2)']          |
|       log(uint256,uint256,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(uint,uint,bool),p0,p1,p2)']           |
|      log(uint256,uint256,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,uint,address),p0,p1,p2)']         |
|      log(uint256,string,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,string,uint),p0,p1,p2)']          |
|       log(uint256,string,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(uint,string,string),p0,p1,p2)']         |
|        log(uint256,string,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,string,bool),p0,p1,p2)']          |
|      log(uint256,string,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(uint,string,address),p0,p1,p2)']        |
|       log(uint256,bool,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(uint,bool,uint),p0,p1,p2)']           |
|        log(uint256,bool,string)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,bool,string),p0,p1,p2)']          |
|         log(uint256,bool,bool)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(uint,bool,bool),p0,p1,p2)']           |
|       log(uint256,bool,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,bool,address),p0,p1,p2)']         |
|      log(uint256,address,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,address,uint),p0,p1,p2)']         |
|      log(uint256,address,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(uint,address,string),p0,p1,p2)']        |
|       log(uint256,address,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(uint,address,bool),p0,p1,p2)']         |
|      log(uint256,address,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(uint,address,address),p0,p1,p2)']        |
|      log(string,uint256,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(string,uint,uint),p0,p1,p2)']          |
|       log(string,uint256,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,uint,string),p0,p1,p2)']         |
|        log(string,uint256,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(string,uint,bool),p0,p1,p2)']          |
|      log(string,uint256,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,uint,address),p0,p1,p2)']        |
|       log(string,string,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,string,uint),p0,p1,p2)']         |
|       log(string,string,string)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(string,string,string),p0,p1,p2)']        |
|        log(string,string,bool)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,string,bool),p0,p1,p2)']         |
|       log(string,string,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(string,string,address),p0,p1,p2)']       |
|        log(string,bool,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(string,bool,uint),p0,p1,p2)']          |
|        log(string,bool,string)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,bool,string),p0,p1,p2)']         |
|         log(string,bool,bool)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(string,bool,bool),p0,p1,p2)']          |
|        log(string,bool,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,bool,address),p0,p1,p2)']        |
|      log(string,address,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,address,uint),p0,p1,p2)']        |
|       log(string,address,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(string,address,string),p0,p1,p2)']       |
|        log(string,address,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(string,address,bool),p0,p1,p2)']        |
|      log(string,address,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(string,address,address),p0,p1,p2)']       |
|       log(bool,uint256,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(bool,uint,uint),p0,p1,p2)']           |
|        log(bool,uint256,string)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,uint,string),p0,p1,p2)']          |
|         log(bool,uint256,bool)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(bool,uint,bool),p0,p1,p2)']           |
|       log(bool,uint256,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,uint,address),p0,p1,p2)']         |
|        log(bool,string,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,string,uint),p0,p1,p2)']          |
|        log(bool,string,string)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(bool,string,string),p0,p1,p2)']         |
|         log(bool,string,bool)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,string,bool),p0,p1,p2)']          |
|        log(bool,string,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(bool,string,address),p0,p1,p2)']        |
|         log(bool,bool,uint256)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(bool,bool,uint),p0,p1,p2)']           |
|         log(bool,bool,string)         |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,bool,string),p0,p1,p2)']          |
|          log(bool,bool,bool)          |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |           ['abi.encodeWithSignature(log(bool,bool,bool),p0,p1,p2)']           |
|         log(bool,bool,address)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,bool,address),p0,p1,p2)']         |
|       log(bool,address,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,address,uint),p0,p1,p2)']         |
|        log(bool,address,string)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(bool,address,string),p0,p1,p2)']        |
|         log(bool,address,bool)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(bool,address,bool),p0,p1,p2)']         |
|       log(bool,address,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(bool,address,address),p0,p1,p2)']        |
|      log(address,uint256,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(address,uint,uint),p0,p1,p2)']         |
|      log(address,uint256,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(address,uint,string),p0,p1,p2)']        |
|       log(address,uint256,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(address,uint,bool),p0,p1,p2)']         |
|      log(address,uint256,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(address,uint,address),p0,p1,p2)']        |
|      log(address,string,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(address,string,uint),p0,p1,p2)']        |
|       log(address,string,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(address,string,string),p0,p1,p2)']       |
|        log(address,string,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(address,string,bool),p0,p1,p2)']        |
|      log(address,string,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(address,string,address),p0,p1,p2)']       |
|       log(address,bool,uint256)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(address,bool,uint),p0,p1,p2)']         |
|        log(address,bool,string)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |         ['abi.encodeWithSignature(log(address,bool,string),p0,p1,p2)']        |
|         log(address,bool,bool)        |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |          ['abi.encodeWithSignature(log(address,bool,bool),p0,p1,p2)']         |
|       log(address,bool,address)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(address,bool,address),p0,p1,p2)']        |
|      log(address,address,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(address,address,uint),p0,p1,p2)']        |
|      log(address,address,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(address,address,string),p0,p1,p2)']       |
|       log(address,address,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |        ['abi.encodeWithSignature(log(address,address,bool),p0,p1,p2)']        |
|      log(address,address,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(address,address,address),p0,p1,p2)']      |
|  log(uint256,uint256,uint256,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,uint,uint,uint),p0,p1,p2,p3)']       |
|  log(uint256,uint256,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,uint,string),p0,p1,p2,p3)']      |
|   log(uint256,uint256,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,uint,uint,bool),p0,p1,p2,p3)']       |
|  log(uint256,uint256,uint256,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,uint,address),p0,p1,p2,p3)']     |
|  log(uint256,uint256,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,string,uint),p0,p1,p2,p3)']      |
|   log(uint256,uint256,string,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,uint,string,string),p0,p1,p2,p3)']     |
|    log(uint256,uint256,string,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,string,bool),p0,p1,p2,p3)']      |
|  log(uint256,uint256,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,uint,string,address),p0,p1,p2,p3)']    |
|   log(uint256,uint256,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,uint,bool,uint),p0,p1,p2,p3)']       |
|    log(uint256,uint256,bool,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,bool,string),p0,p1,p2,p3)']      |
|     log(uint256,uint256,bool,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,uint,bool,bool),p0,p1,p2,p3)']       |
|   log(uint256,uint256,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,bool,address),p0,p1,p2,p3)']     |
|  log(uint256,uint256,address,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,address,uint),p0,p1,p2,p3)']     |
|  log(uint256,uint256,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,uint,address,string),p0,p1,p2,p3)']    |
|   log(uint256,uint256,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,uint,address,bool),p0,p1,p2,p3)']     |
|  log(uint256,uint256,address,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,uint,address,address),p0,p1,p2,p3)']    |
|  log(uint256,string,uint256,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,string,uint,uint),p0,p1,p2,p3)']      |
|   log(uint256,string,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,uint,string),p0,p1,p2,p3)']     |
|    log(uint256,string,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,string,uint,bool),p0,p1,p2,p3)']      |
|  log(uint256,string,uint256,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,uint,address),p0,p1,p2,p3)']    |
|   log(uint256,string,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,string,uint),p0,p1,p2,p3)']     |
|   log(uint256,string,string,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,string,string,string),p0,p1,p2,p3)']    |
|    log(uint256,string,string,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,string,bool),p0,p1,p2,p3)']     |
|   log(uint256,string,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,string,string,address),p0,p1,p2,p3)']   |
|    log(uint256,string,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,string,bool,uint),p0,p1,p2,p3)']      |
|    log(uint256,string,bool,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,bool,string),p0,p1,p2,p3)']     |
|     log(uint256,string,bool,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,string,bool,bool),p0,p1,p2,p3)']      |
|    log(uint256,string,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,bool,address),p0,p1,p2,p3)']    |
|  log(uint256,string,address,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,address,uint),p0,p1,p2,p3)']    |
|   log(uint256,string,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,string,address,string),p0,p1,p2,p3)']   |
|    log(uint256,string,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,string,address,bool),p0,p1,p2,p3)']    |
|  log(uint256,string,address,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(uint,string,address,address),p0,p1,p2,p3)']   |
|   log(uint256,bool,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,bool,uint,uint),p0,p1,p2,p3)']       |
|    log(uint256,bool,uint256,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,uint,string),p0,p1,p2,p3)']      |
|     log(uint256,bool,uint256,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,bool,uint,bool),p0,p1,p2,p3)']       |
|   log(uint256,bool,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,uint,address),p0,p1,p2,p3)']     |
|    log(uint256,bool,string,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,string,uint),p0,p1,p2,p3)']      |
|    log(uint256,bool,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,bool,string,string),p0,p1,p2,p3)']     |
|     log(uint256,bool,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,string,bool),p0,p1,p2,p3)']      |
|    log(uint256,bool,string,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,bool,string,address),p0,p1,p2,p3)']    |
|     log(uint256,bool,bool,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,bool,bool,uint),p0,p1,p2,p3)']       |
|     log(uint256,bool,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,bool,string),p0,p1,p2,p3)']      |
|      log(uint256,bool,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(uint,bool,bool,bool),p0,p1,p2,p3)']       |
|     log(uint256,bool,bool,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,bool,address),p0,p1,p2,p3)']     |
|   log(uint256,bool,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,address,uint),p0,p1,p2,p3)']     |
|    log(uint256,bool,address,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,bool,address,string),p0,p1,p2,p3)']    |
|     log(uint256,bool,address,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,bool,address,bool),p0,p1,p2,p3)']     |
|   log(uint256,bool,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,bool,address,address),p0,p1,p2,p3)']    |
|  log(uint256,address,uint256,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,address,uint,uint),p0,p1,p2,p3)']     |
|  log(uint256,address,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,address,uint,string),p0,p1,p2,p3)']    |
|   log(uint256,address,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,address,uint,bool),p0,p1,p2,p3)']     |
|  log(uint256,address,uint256,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,address,uint,address),p0,p1,p2,p3)']    |
|  log(uint256,address,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,address,string,uint),p0,p1,p2,p3)']    |
|   log(uint256,address,string,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,address,string,string),p0,p1,p2,p3)']   |
|    log(uint256,address,string,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,address,string,bool),p0,p1,p2,p3)']    |
|  log(uint256,address,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(uint,address,string,address),p0,p1,p2,p3)']   |
|   log(uint256,address,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,address,bool,uint),p0,p1,p2,p3)']     |
|    log(uint256,address,bool,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(uint,address,bool,string),p0,p1,p2,p3)']    |
|     log(uint256,address,bool,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(uint,address,bool,bool),p0,p1,p2,p3)']     |
|   log(uint256,address,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,address,bool,address),p0,p1,p2,p3)']    |
|  log(uint256,address,address,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,address,address,uint),p0,p1,p2,p3)']    |
|  log(uint256,address,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(uint,address,address,string),p0,p1,p2,p3)']   |
|   log(uint256,address,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(uint,address,address,bool),p0,p1,p2,p3)']    |
|  log(uint256,address,address,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(uint,address,address,address),p0,p1,p2,p3)']  |
|  log(string,uint256,uint256,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,uint,uint,uint),p0,p1,p2,p3)']      |
|   log(string,uint256,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,uint,string),p0,p1,p2,p3)']     |
|    log(string,uint256,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,uint,uint,bool),p0,p1,p2,p3)']      |
|  log(string,uint256,uint256,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,uint,address),p0,p1,p2,p3)']    |
|   log(string,uint256,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,string,uint),p0,p1,p2,p3)']     |
|   log(string,uint256,string,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,uint,string,string),p0,p1,p2,p3)']    |
|    log(string,uint256,string,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,string,bool),p0,p1,p2,p3)']     |
|   log(string,uint256,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,uint,string,address),p0,p1,p2,p3)']   |
|    log(string,uint256,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,uint,bool,uint),p0,p1,p2,p3)']      |
|    log(string,uint256,bool,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,bool,string),p0,p1,p2,p3)']     |
|     log(string,uint256,bool,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,uint,bool,bool),p0,p1,p2,p3)']      |
|    log(string,uint256,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,bool,address),p0,p1,p2,p3)']    |
|  log(string,uint256,address,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,address,uint),p0,p1,p2,p3)']    |
|   log(string,uint256,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,uint,address,string),p0,p1,p2,p3)']   |
|    log(string,uint256,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,uint,address,bool),p0,p1,p2,p3)']    |
|  log(string,uint256,address,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,uint,address,address),p0,p1,p2,p3)']   |
|   log(string,string,uint256,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,string,uint,uint),p0,p1,p2,p3)']     |
|   log(string,string,uint256,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,uint,string),p0,p1,p2,p3)']    |
|    log(string,string,uint256,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,string,uint,bool),p0,p1,p2,p3)']     |
|   log(string,string,uint256,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,uint,address),p0,p1,p2,p3)']   |
|   log(string,string,string,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,string,uint),p0,p1,p2,p3)']    |
|    log(string,string,string,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,string,string,string),p0,p1,p2,p3)']   |
|     log(string,string,string,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,string,bool),p0,p1,p2,p3)']    |
|   log(string,string,string,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,string,string,address),p0,p1,p2,p3)']  |
|    log(string,string,bool,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,string,bool,uint),p0,p1,p2,p3)']     |
|     log(string,string,bool,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,bool,string),p0,p1,p2,p3)']    |
|      log(string,string,bool,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,string,bool,bool),p0,p1,p2,p3)']     |
|    log(string,string,bool,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,bool,address),p0,p1,p2,p3)']   |
|   log(string,string,address,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,address,uint),p0,p1,p2,p3)']   |
|   log(string,string,address,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,string,address,string),p0,p1,p2,p3)']  |
|    log(string,string,address,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,string,address,bool),p0,p1,p2,p3)']   |
|   log(string,string,address,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(string,string,address,address),p0,p1,p2,p3)']  |
|    log(string,bool,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,bool,uint,uint),p0,p1,p2,p3)']      |
|    log(string,bool,uint256,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,uint,string),p0,p1,p2,p3)']     |
|     log(string,bool,uint256,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,bool,uint,bool),p0,p1,p2,p3)']      |
|    log(string,bool,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,uint,address),p0,p1,p2,p3)']    |
|    log(string,bool,string,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,string,uint),p0,p1,p2,p3)']     |
|     log(string,bool,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,bool,string,string),p0,p1,p2,p3)']    |
|      log(string,bool,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,string,bool),p0,p1,p2,p3)']     |
|    log(string,bool,string,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,bool,string,address),p0,p1,p2,p3)']   |
|     log(string,bool,bool,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,bool,bool,uint),p0,p1,p2,p3)']      |
|      log(string,bool,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,bool,string),p0,p1,p2,p3)']     |
|       log(string,bool,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(string,bool,bool,bool),p0,p1,p2,p3)']      |
|     log(string,bool,bool,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,bool,address),p0,p1,p2,p3)']    |
|    log(string,bool,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,address,uint),p0,p1,p2,p3)']    |
|    log(string,bool,address,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,bool,address,string),p0,p1,p2,p3)']   |
|     log(string,bool,address,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,bool,address,bool),p0,p1,p2,p3)']    |
|    log(string,bool,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,bool,address,address),p0,p1,p2,p3)']   |
|  log(string,address,uint256,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,address,uint,uint),p0,p1,p2,p3)']    |
|   log(string,address,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,address,uint,string),p0,p1,p2,p3)']   |
|    log(string,address,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,address,uint,bool),p0,p1,p2,p3)']    |
|  log(string,address,uint256,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,address,uint,address),p0,p1,p2,p3)']   |
|   log(string,address,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,address,string,uint),p0,p1,p2,p3)']   |
|   log(string,address,string,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,address,string,string),p0,p1,p2,p3)']  |
|    log(string,address,string,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,address,string,bool),p0,p1,p2,p3)']   |
|   log(string,address,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(string,address,string,address),p0,p1,p2,p3)']  |
|    log(string,address,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,address,bool,uint),p0,p1,p2,p3)']    |
|    log(string,address,bool,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(string,address,bool,string),p0,p1,p2,p3)']   |
|     log(string,address,bool,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(string,address,bool,bool),p0,p1,p2,p3)']    |
|    log(string,address,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,address,bool,address),p0,p1,p2,p3)']   |
|  log(string,address,address,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,address,address,uint),p0,p1,p2,p3)']   |
|   log(string,address,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(string,address,address,string),p0,p1,p2,p3)']  |
|    log(string,address,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(string,address,address,bool),p0,p1,p2,p3)']   |
|  log(string,address,address,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(string,address,address,address),p0,p1,p2,p3)'] |
|   log(bool,uint256,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,uint,uint,uint),p0,p1,p2,p3)']       |
|    log(bool,uint256,uint256,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,uint,string),p0,p1,p2,p3)']      |
|     log(bool,uint256,uint256,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,uint,uint,bool),p0,p1,p2,p3)']       |
|   log(bool,uint256,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,uint,address),p0,p1,p2,p3)']     |
|    log(bool,uint256,string,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,string,uint),p0,p1,p2,p3)']      |
|    log(bool,uint256,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,uint,string,string),p0,p1,p2,p3)']     |
|     log(bool,uint256,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,string,bool),p0,p1,p2,p3)']      |
|    log(bool,uint256,string,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,uint,string,address),p0,p1,p2,p3)']    |
|     log(bool,uint256,bool,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,uint,bool,uint),p0,p1,p2,p3)']       |
|     log(bool,uint256,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,bool,string),p0,p1,p2,p3)']      |
|      log(bool,uint256,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,uint,bool,bool),p0,p1,p2,p3)']       |
|     log(bool,uint256,bool,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,bool,address),p0,p1,p2,p3)']     |
|   log(bool,uint256,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,address,uint),p0,p1,p2,p3)']     |
|    log(bool,uint256,address,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,uint,address,string),p0,p1,p2,p3)']    |
|     log(bool,uint256,address,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,uint,address,bool),p0,p1,p2,p3)']     |
|   log(bool,uint256,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,uint,address,address),p0,p1,p2,p3)']    |
|    log(bool,string,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,string,uint,uint),p0,p1,p2,p3)']      |
|    log(bool,string,uint256,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,uint,string),p0,p1,p2,p3)']     |
|     log(bool,string,uint256,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,string,uint,bool),p0,p1,p2,p3)']      |
|    log(bool,string,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,uint,address),p0,p1,p2,p3)']    |
|    log(bool,string,string,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,string,uint),p0,p1,p2,p3)']     |
|     log(bool,string,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,string,string,string),p0,p1,p2,p3)']    |
|      log(bool,string,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,string,bool),p0,p1,p2,p3)']     |
|    log(bool,string,string,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,string,string,address),p0,p1,p2,p3)']   |
|     log(bool,string,bool,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,string,bool,uint),p0,p1,p2,p3)']      |
|      log(bool,string,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,bool,string),p0,p1,p2,p3)']     |
|       log(bool,string,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,string,bool,bool),p0,p1,p2,p3)']      |
|     log(bool,string,bool,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,bool,address),p0,p1,p2,p3)']    |
|    log(bool,string,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,address,uint),p0,p1,p2,p3)']    |
|    log(bool,string,address,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,string,address,string),p0,p1,p2,p3)']   |
|     log(bool,string,address,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,string,address,bool),p0,p1,p2,p3)']    |
|    log(bool,string,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(bool,string,address,address),p0,p1,p2,p3)']   |
|     log(bool,bool,uint256,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,bool,uint,uint),p0,p1,p2,p3)']       |
|     log(bool,bool,uint256,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,uint,string),p0,p1,p2,p3)']      |
|      log(bool,bool,uint256,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,bool,uint,bool),p0,p1,p2,p3)']       |
|     log(bool,bool,uint256,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,uint,address),p0,p1,p2,p3)']     |
|     log(bool,bool,string,uint256)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,string,uint),p0,p1,p2,p3)']      |
|      log(bool,bool,string,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,bool,string,string),p0,p1,p2,p3)']     |
|       log(bool,bool,string,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,string,bool),p0,p1,p2,p3)']      |
|     log(bool,bool,string,address)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,bool,string,address),p0,p1,p2,p3)']    |
|      log(bool,bool,bool,uint256)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,bool,bool,uint),p0,p1,p2,p3)']       |
|       log(bool,bool,bool,string)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,bool,string),p0,p1,p2,p3)']      |
|        log(bool,bool,bool,bool)       |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |       ['abi.encodeWithSignature(log(bool,bool,bool,bool),p0,p1,p2,p3)']       |
|      log(bool,bool,bool,address)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,bool,address),p0,p1,p2,p3)']     |
|     log(bool,bool,address,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,address,uint),p0,p1,p2,p3)']     |
|     log(bool,bool,address,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,bool,address,string),p0,p1,p2,p3)']    |
|      log(bool,bool,address,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,bool,address,bool),p0,p1,p2,p3)']     |
|     log(bool,bool,address,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,bool,address,address),p0,p1,p2,p3)']    |
|   log(bool,address,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,address,uint,uint),p0,p1,p2,p3)']     |
|    log(bool,address,uint256,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,address,uint,string),p0,p1,p2,p3)']    |
|     log(bool,address,uint256,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,address,uint,bool),p0,p1,p2,p3)']     |
|   log(bool,address,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,address,uint,address),p0,p1,p2,p3)']    |
|    log(bool,address,string,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,address,string,uint),p0,p1,p2,p3)']    |
|    log(bool,address,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,address,string,string),p0,p1,p2,p3)']   |
|     log(bool,address,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,address,string,bool),p0,p1,p2,p3)']    |
|    log(bool,address,string,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(bool,address,string,address),p0,p1,p2,p3)']   |
|     log(bool,address,bool,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,address,bool,uint),p0,p1,p2,p3)']     |
|     log(bool,address,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(bool,address,bool,string),p0,p1,p2,p3)']    |
|      log(bool,address,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(bool,address,bool,bool),p0,p1,p2,p3)']     |
|     log(bool,address,bool,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,address,bool,address),p0,p1,p2,p3)']    |
|   log(bool,address,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,address,address,uint),p0,p1,p2,p3)']    |
|    log(bool,address,address,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(bool,address,address,string),p0,p1,p2,p3)']   |
|     log(bool,address,address,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(bool,address,address,bool),p0,p1,p2,p3)']    |
|   log(bool,address,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(bool,address,address,address),p0,p1,p2,p3)']  |
|  log(address,uint256,uint256,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,uint,uint,uint),p0,p1,p2,p3)']     |
|  log(address,uint256,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,uint,uint,string),p0,p1,p2,p3)']    |
|   log(address,uint256,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,uint,uint,bool),p0,p1,p2,p3)']     |
|  log(address,uint256,uint256,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,uint,uint,address),p0,p1,p2,p3)']    |
|  log(address,uint256,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,uint,string,uint),p0,p1,p2,p3)']    |
|   log(address,uint256,string,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,uint,string,string),p0,p1,p2,p3)']   |
|    log(address,uint256,string,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,uint,string,bool),p0,p1,p2,p3)']    |
|  log(address,uint256,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,uint,string,address),p0,p1,p2,p3)']   |
|   log(address,uint256,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,uint,bool,uint),p0,p1,p2,p3)']     |
|    log(address,uint256,bool,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,uint,bool,string),p0,p1,p2,p3)']    |
|     log(address,uint256,bool,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,uint,bool,bool),p0,p1,p2,p3)']     |
|   log(address,uint256,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,uint,bool,address),p0,p1,p2,p3)']    |
|  log(address,uint256,address,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,uint,address,uint),p0,p1,p2,p3)']    |
|  log(address,uint256,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,uint,address,string),p0,p1,p2,p3)']   |
|   log(address,uint256,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,uint,address,bool),p0,p1,p2,p3)']    |
|  log(address,uint256,address,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,uint,address,address),p0,p1,p2,p3)']  |
|  log(address,string,uint256,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,string,uint,uint),p0,p1,p2,p3)']    |
|   log(address,string,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,string,uint,string),p0,p1,p2,p3)']   |
|    log(address,string,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,string,uint,bool),p0,p1,p2,p3)']    |
|  log(address,string,uint256,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,string,uint,address),p0,p1,p2,p3)']   |
|   log(address,string,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,string,string,uint),p0,p1,p2,p3)']   |
|   log(address,string,string,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,string,string,string),p0,p1,p2,p3)']  |
|    log(address,string,string,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,string,string,bool),p0,p1,p2,p3)']   |
|   log(address,string,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,string,string,address),p0,p1,p2,p3)']  |
|    log(address,string,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,string,bool,uint),p0,p1,p2,p3)']    |
|    log(address,string,bool,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,string,bool,string),p0,p1,p2,p3)']   |
|     log(address,string,bool,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,string,bool,bool),p0,p1,p2,p3)']    |
|    log(address,string,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,string,bool,address),p0,p1,p2,p3)']   |
|  log(address,string,address,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,string,address,uint),p0,p1,p2,p3)']   |
|   log(address,string,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,string,address,string),p0,p1,p2,p3)']  |
|    log(address,string,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,string,address,bool),p0,p1,p2,p3)']   |
|  log(address,string,address,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,string,address,address),p0,p1,p2,p3)'] |
|   log(address,bool,uint256,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,bool,uint,uint),p0,p1,p2,p3)']     |
|    log(address,bool,uint256,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,bool,uint,string),p0,p1,p2,p3)']    |
|     log(address,bool,uint256,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,bool,uint,bool),p0,p1,p2,p3)']     |
|   log(address,bool,uint256,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,bool,uint,address),p0,p1,p2,p3)']    |
|    log(address,bool,string,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,bool,string,uint),p0,p1,p2,p3)']    |
|    log(address,bool,string,string)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,bool,string,string),p0,p1,p2,p3)']   |
|     log(address,bool,string,bool)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,bool,string,bool),p0,p1,p2,p3)']    |
|    log(address,bool,string,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,bool,string,address),p0,p1,p2,p3)']   |
|     log(address,bool,bool,uint256)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,bool,bool,uint),p0,p1,p2,p3)']     |
|     log(address,bool,bool,string)     |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |     ['abi.encodeWithSignature(log(address,bool,bool,string),p0,p1,p2,p3)']    |
|      log(address,bool,bool,bool)      |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |      ['abi.encodeWithSignature(log(address,bool,bool,bool),p0,p1,p2,p3)']     |
|     log(address,bool,bool,address)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,bool,bool,address),p0,p1,p2,p3)']    |
|   log(address,bool,address,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,bool,address,uint),p0,p1,p2,p3)']    |
|    log(address,bool,address,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,bool,address,string),p0,p1,p2,p3)']   |
|     log(address,bool,address,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,bool,address,bool),p0,p1,p2,p3)']    |
|   log(address,bool,address,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,bool,address,address),p0,p1,p2,p3)']  |
|  log(address,address,uint256,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,address,uint,uint),p0,p1,p2,p3)']    |
|  log(address,address,uint256,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,uint,string),p0,p1,p2,p3)']   |
|   log(address,address,uint256,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,address,uint,bool),p0,p1,p2,p3)']    |
|  log(address,address,uint256,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,uint,address),p0,p1,p2,p3)']  |
|  log(address,address,string,uint256)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,string,uint),p0,p1,p2,p3)']   |
|   log(address,address,string,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,address,string,string),p0,p1,p2,p3)']  |
|    log(address,address,string,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,string,bool),p0,p1,p2,p3)']   |
|  log(address,address,string,address)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,address,string,address),p0,p1,p2,p3)'] |
|   log(address,address,bool,uint256)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,address,bool,uint),p0,p1,p2,p3)']    |
|    log(address,address,bool,string)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,bool,string),p0,p1,p2,p3)']   |
|     log(address,address,bool,bool)    |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |    ['abi.encodeWithSignature(log(address,address,bool,bool),p0,p1,p2,p3)']    |
|   log(address,address,bool,address)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,bool,address),p0,p1,p2,p3)']  |
|  log(address,address,address,uint256) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,address,uint),p0,p1,p2,p3)']  |
|  log(address,address,address,string)  |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |  ['abi.encodeWithSignature(log(address,address,address,string),p0,p1,p2,p3)'] |
|   log(address,address,address,bool)   |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             |   ['abi.encodeWithSignature(log(address,address,address,bool),p0,p1,p2,p3)']  |
|  log(address,address,address,address) |  internal  |     []    |          []         |          []         |             ['_sendLogPayload', 'abi.encodeWithSignature()']             | ['abi.encodeWithSignature(log(address,address,address,address),p0,p1,p2,p3)'] |
| slitherConstructorConstantVariables() |  internal  |     []    |          []         | ['CONSOLE_ADDRESS'] |                                    []                                    |                                       []                                      |
+---------------------------------------+------------+-----------+---------------------+---------------------+--------------------------------------------------------------------------+-------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract Address
Contract vars: []
Inheritance:: []
 
+----------+------------+-----------+------+-------+----------------+----------------+
| Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------+------------+-----------+------+-------+----------------+----------------+
+----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract TestUtils
Contract vars: ['IS_TEST', 'failed', 'HEVM_ADDRESS', 'RAY', 'vm', 'ARITHMETIC_ERROR', 'ZERO_DIVISION']
Inheritance:: ['DSTest']
 
+-------------------------------------------------+------------+-----------+---------+--------------------------------------+---------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
|                     Function                    | Visibility | Modifiers |   Read  |                Write                 |                   Internal Calls                  |                                                          External Calls                                                          |
+-------------------------------------------------+------------+-----------+---------+--------------------------------------+---------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
|                      fail()                     |  internal  |     []    |    []   |              ['failed']              |                         []                        |                                                                []                                                                |
|                 assertTrue(bool)                |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|             assertTrue(bool,string)             |  internal  |     []    |    []   |                  []                  |                   ['assertTrue']                  |                                                                []                                                                |
|            assertEq(address,address)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertEq(address,address,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|            assertEq(bytes32,bytes32)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertEq(bytes32,bytes32,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|           assertEq32(bytes32,bytes32)           |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|        assertEq32(bytes32,bytes32,string)       |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|             assertEq(int256,int256)             |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|          assertEq(int256,int256,string)         |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|            assertEq(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertEq(uint256,uint256,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertEq']                   |                                                                []                                                                |
|      assertEqDecimal(int256,int256,uint256)     |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|  assertEqDecimal(int256,int256,uint256,string)  |  internal  |     []    |    []   |                  []                  |                ['assertEqDecimal']                |                                                                []                                                                |
|     assertEqDecimal(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
| assertEqDecimal(uint256,uint256,uint256,string) |  internal  |     []    |    []   |                  []                  |                ['assertEqDecimal']                |                                                                []                                                                |
|            assertGt(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertGt(uint256,uint256,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertGt']                   |                                                                []                                                                |
|             assertGt(int256,int256)             |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|          assertGt(int256,int256,string)         |  internal  |     []    |    []   |                  []                  |                    ['assertGt']                   |                                                                []                                                                |
|      assertGtDecimal(int256,int256,uint256)     |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|  assertGtDecimal(int256,int256,uint256,string)  |  internal  |     []    |    []   |                  []                  |                ['assertGtDecimal']                |                                                                []                                                                |
|     assertGtDecimal(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
| assertGtDecimal(uint256,uint256,uint256,string) |  internal  |     []    |    []   |                  []                  |                ['assertGtDecimal']                |                                                                []                                                                |
|            assertGe(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertGe(uint256,uint256,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertGe']                   |                                                                []                                                                |
|             assertGe(int256,int256)             |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|          assertGe(int256,int256,string)         |  internal  |     []    |    []   |                  []                  |                    ['assertGe']                   |                                                                []                                                                |
|      assertGeDecimal(int256,int256,uint256)     |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|  assertGeDecimal(int256,int256,uint256,string)  |  internal  |     []    |    []   |                  []                  |                ['assertGeDecimal']                |                                                                []                                                                |
|     assertGeDecimal(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
| assertGeDecimal(uint256,uint256,uint256,string) |  internal  |     []    |    []   |                  []                  |                ['assertGeDecimal']                |                                                                []                                                                |
|            assertLt(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertLt(uint256,uint256,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertLt']                   |                                                                []                                                                |
|             assertLt(int256,int256)             |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|          assertLt(int256,int256,string)         |  internal  |     []    |    []   |                  []                  |                    ['assertLt']                   |                                                                []                                                                |
|      assertLtDecimal(int256,int256,uint256)     |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|  assertLtDecimal(int256,int256,uint256,string)  |  internal  |     []    |    []   |                  []                  |                ['assertLtDecimal']                |                                                                []                                                                |
|     assertLtDecimal(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
| assertLtDecimal(uint256,uint256,uint256,string) |  internal  |     []    |    []   |                  []                  |                ['assertLtDecimal']                |                                                                []                                                                |
|            assertLe(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|         assertLe(uint256,uint256,string)        |  internal  |     []    |    []   |                  []                  |                    ['assertLe']                   |                                                                []                                                                |
|             assertLe(int256,int256)             |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|          assertLe(int256,int256,string)         |  internal  |     []    |    []   |                  []                  |                    ['assertLe']                   |                                                                []                                                                |
|      assertLeDecimal(int256,int256,uint256)     |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
|  assertLeDecimal(int256,int256,uint256,string)  |  internal  |     []    |    []   |                  []                  |                ['assertLeDecimal']                |                                                                []                                                                |
|     assertLeDecimal(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                      ['fail']                     |                                                                []                                                                |
| assertLeDecimal(uint256,uint256,uint256,string) |  internal  |     []    |    []   |                  []                  |                ['assertGeDecimal']                |                                                                []                                                                |
|             assertEq(string,string)             |  internal  |     []    |    []   |                  []                  |     ['keccak256(bytes)', 'abi.encodePacked()']    |                                          ['abi.encodePacked(b)', 'abi.encodePacked(a)']                                          |
|                                                 |            |           |         |                                      |                      ['fail']                     |                                                                                                                                  |
|          assertEq(string,string,string)         |  internal  |     []    |    []   |                  []                  |          ['keccak256(bytes)', 'assertEq']         |                                          ['abi.encodePacked(a)', 'abi.encodePacked(b)']                                          |
|                                                 |            |           |         |                                      |               ['abi.encodePacked()']              |                                                                                                                                  |
|              checkEq0(bytes,bytes)              |  internal  |     []    |    []   |                  []                  |                         []                        |                                                                []                                                                |
|              assertEq0(bytes,bytes)             |  internal  |     []    |    []   |                  []                  |                ['checkEq0', 'fail']               |                                                                []                                                                |
|          assertEq0(bytes,bytes,string)          |  internal  |     []    |    []   |                  []                  |             ['assertEq0', 'checkEq0']             |                                                                []                                                                |
|             getDiff(uint256,uint256)            |  internal  |     []    |    []   |                  []                  |                         []                        |                                                                []                                                                |
| assertIgnoringDecimals(uint256,uint256,uint256) |  internal  |     []    |    []   |                  []                  |              ['assertEq', 'getDiff']              |                                                                []                                                                |
|  assertWithinPrecision(uint256,uint256,uint256) |  internal  |     []    | ['RAY'] |                  []                  |                ['fail', 'getDiff']                |                                                                []                                                                |
| assertWithinPercentage(uint256,uint256,uint256) |  internal  |     []    | ['RAY'] |                  []                  |                ['fail', 'getDiff']                |                                                                []                                                                |
|    assertWithinDiff(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |                ['fail', 'getDiff']                |                                                                []                                                                |
|    constrictToRange(uint256,uint256,uint256)    |  internal  |     []    |    []   |                  []                  |              ['require(bool,string)']             |                                                                []                                                                |
|   erc20_mint(address,uint256,address,uint256)   |  internal  |     []    |  ['vm'] |                  []                  |        ['keccak256(bytes)', 'abi.encode()']       | ['IERC20Like(token).balanceOf(account)', 'vm.store(token,keccak256(bytes)(abi.encode(account,slot)),bytes32(balance + amount))'] |
|                                                 |            |           |         |                                      |                                                   |                                                   ['abi.encode(account,slot)']                                                   |
|           convertUintToString(uint256)          |  internal  |     []    |    []   |                  []                  |                         []                        |                                                      ['new bytes(length)']                                                       |
|          slitherConstructorVariables()          |  internal  |     []    |    []   |          ['IS_TEST', 'vm']           |                         []                        |                                                                []                                                                |
|      slitherConstructorConstantVariables()      |  internal  |     []    |    []   | ['ARITHMETIC_ERROR', 'HEVM_ADDRESS'] | ['keccak256(bytes)', 'abi.encodeWithSignature()'] |                                                                []                                                                |
|                                                 |            |           |         |       ['RAY', 'ZERO_DIVISION']       |                                                   |                                                                                                                                  |
+-------------------------------------------------+------------+-----------+---------+--------------------------------------+---------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------+

+------------------+------------+------+-------+----------------+----------------+
|    Modifiers     | Visibility | Read | Write | Internal Calls | External Calls |
+------------------+------------+------+-------+----------------+----------------+
|   mayRevert()    |  internal  |  []  |   []  |       []       |       []       |
| testopts(string) |  internal  |  []  |   []  |       []       |       []       |
|    logs_gas()    |  internal  |  []  |   []  | ['gasleft()']  |       []       |
+------------------+------------+------+-------+----------------+----------------+


Contract InvariantTest
Contract vars: ['_excludedContracts', '_targetContracts']
Inheritance:: []
 
+----------------------------+------------+-----------+------------------------+------------------------+--------------------------+---------------------------------------------------+
|          Function          | Visibility | Modifiers |          Read          |         Write          |      Internal Calls      |                   External Calls                  |
+----------------------------+------------+-----------+------------------------+------------------------+--------------------------+---------------------------------------------------+
| addTargetContract(address) |  internal  |     []    |  ['_targetContracts']  |  ['_targetContracts']  |            []            |   ['_targetContracts.push(newTargetContract_)']   |
|     targetContracts()      |   public   |     []    |  ['_targetContracts']  |           []           | ['require(bool,string)'] |                         []                        |
|  excludeContract(address)  |  internal  |     []    | ['_excludedContracts'] | ['_excludedContracts'] |            []            | ['_excludedContracts.push(newExcludedContract_)'] |
|     excludeContracts()     |   public   |     []    | ['_excludedContracts'] |           []           | ['require(bool,string)'] |                         []                        |
+----------------------------+------------+-----------+------------------------+------------------------+--------------------------+---------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['abi.encodeWithSelector()', '_call'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['code(address)', 'abi.decode()']   |                                               ['token_.call(data_)', 'abi.decode(returnData,(bool))']                                               |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                Function               | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|        approve(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       transfer(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| transferFrom(address,address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract MapleProxiedInternals
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['ProxiedInternals', 'SlotManipulatable']
 
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|                Function                | Visibility | Modifiers |           Read          |                  Write                  |               Internal Calls               |             External Calls             |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|        _migrate(address,bytes)         |  internal  |     []    |            []           |                    []                   |                     []                     | ['migrator_.delegatecall(arguments_)'] |
|          _setFactory(address)          |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_setSlotValue']              |                   []                   |
|      _setImplementation(address)       |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_setSlotValue']              |                   []                   |
|               _factory()               |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_getSlotValue']              |                   []                   |
|           _implementation()            |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_getSlotValue']              |                   []                   |
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['keccak256(bytes)', 'abi.encodePacked()'] |    ['abi.encodePacked(key_,slot_)']    |
|         _getSlotValue(bytes32)         |  internal  |     []    |            []           |                    []                   |             ['sload(uint256)']             |                   []                   |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |            []           |                    []                   |        ['sstore(uint256,uint256)']         |                   []                   |
| slitherConstructorConstantVariables()  |  internal  |     []    |            []           | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                   []                   |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxied
Contract vars: []
Inheritance:: ['IProxied']
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|         factory()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      implementation()      |  external  |     []    |  []  |   []  |       []       |       []       |
| setImplementation(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|   migrate(address,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
|   upgrade(uint256,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxyFactory
Contract vars: []
Inheritance:: ['IDefaultImplementationBeacon']
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|             defaultImplementation()             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 defaultVersion()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  mapleGlobals()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|      upgradeEnabledForPath(uint256,uint256)     |  external  |     []    |  []  |   []  |       []       |       []       |
|          createInstance(bytes,bytes32)          |  external  |     []    |  []  |   []  |       []       |       []       |
|    enableUpgradePath(uint256,uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|       disableUpgradePath(uint256,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| registerImplementation(uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|            setDefaultVersion(uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|               setGlobals(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|          upgradeInstance(uint256,bytes)         |  external  |     []    |  []  |   []  |       []       |       []       |
|        getInstanceAddress(bytes,bytes32)        |  external  |     []    |  []  |   []  |       []       |       []       |
|            implementationOf(uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|               isInstance(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|         migratorForPath(uint256,uint256)        |  external  |     []    |  []  |   []  |       []       |       []       |
|                versionOf(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ProxiedInternals
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['SlotManipulatable']
 
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
|                Function                | Visibility | Modifiers |           Read          |                  Write                  |               Internal Calls               |             External Calls             |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['keccak256(bytes)', 'abi.encodePacked()'] |    ['abi.encodePacked(key_,slot_)']    |
|         _getSlotValue(bytes32)         |  internal  |     []    |            []           |                    []                   |             ['sload(uint256)']             |                   []                   |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |            []           |                    []                   |        ['sstore(uint256,uint256)']         |                   []                   |
|        _migrate(address,bytes)         |  internal  |     []    |            []           |                    []                   |                     []                     | ['migrator_.delegatecall(arguments_)'] |
|          _setFactory(address)          |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_setSlotValue']              |                   []                   |
|      _setImplementation(address)       |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_setSlotValue']              |                   []                   |
|               _factory()               |  internal  |     []    |     ['FACTORY_SLOT']    |                    []                   |             ['_getSlotValue']              |                   []                   |
|           _implementation()            |  internal  |     []    | ['IMPLEMENTATION_SLOT'] |                    []                   |             ['_getSlotValue']              |                   []                   |
| slitherConstructorConstantVariables()  |  internal  |     []    |            []           | ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT'] |                     []                     |                   []                   |
+----------------------------------------+------------+-----------+-------------------------+-----------------------------------------+--------------------------------------------+----------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract SlotManipulatable
Contract vars: []
Inheritance:: []
 
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+
|                Function                | Visibility | Modifiers | Read | Write |               Internal Calls               |          External Calls          |
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |  []  |   []  | ['keccak256(bytes)', 'abi.encodePacked()'] | ['abi.encodePacked(key_,slot_)'] |
|         _getSlotValue(bytes32)         |  internal  |     []    |  []  |   []  |             ['sload(uint256)']             |                []                |
|     _setSlotValue(bytes32,bytes32)     |  internal  |     []    |  []  |   []  |        ['sstore(uint256,uint256)']         |                []                |
+----------------------------------------+------------+-----------+------+-------+--------------------------------------------+----------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IDefaultImplementationBeacon
Contract vars: []
Inheritance:: []
 
+-------------------------+------------+-----------+------+-------+----------------+----------------+
|         Function        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------+------------+-----------+------+-------+----------------+----------------+
| defaultImplementation() |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IProxied
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|         factory()          |  external  |     []    |  []  |   []  |       []       |       []       |
|      implementation()      |  external  |     []    |  []  |   []  |       []       |       []       |
| setImplementation(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|   migrate(address,bytes)   |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/pool-v2/contracts/LoanManager.sol analyzed (43 contracts)
