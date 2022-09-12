Compilation warnings/errors on modules/debt-locker-v4/contracts/DebtLocker.sol:
Warning: Return value of low-level calls not used.
  --> modules/debt-locker-v4/modules/liquidations/contracts/Liquidator.sol:83:9:
   |
83 |         msg.sender.call(data_);
   |         ^^^^^^^^^^^^^^^^^^^^^^

Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/debt-locker-v4/contracts/DebtLocker.sol:15:1:
   |
15 | contract DebtLocker is IDebtLocker, DebtLockerStorage, MapleProxiedInternals {
   | ^ (Relevant source part starts here and spans across multiple lines).



Contract DebtLocker
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator', 'FACTORY_SLOT', 'IMPLEMENTATION_SLOT']
Inheritance:: ['MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'DebtLockerStorage', 'IDebtLocker', 'IMapleProxied', 'IProxied']
 
+----------------------------------------------------------+------------+---------------------------+-------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                         Function                         | Visibility |         Modifiers         |                          Read                         |                         Write                         |                   Internal Calls                  |                                                                                                            External Calls                                                                                                            |
+----------------------------------------------------------+------------+---------------------------+-------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 _migrate(address,bytes)                  |  internal  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                ['migrator_.delegatecall(arguments_)']                                                                                                |
|                   _setFactory(address)                   |  internal  |             []            |                    ['FACTORY_SLOT']                   |                           []                          |                 ['_setSlotValue']                 |                                                                                                                  []                                                                                                                  |
|               _setImplementation(address)                |  internal  |             []            |                ['IMPLEMENTATION_SLOT']                |                           []                          |                 ['_setSlotValue']                 |                                                                                                                  []                                                                                                                  |
|                        _factory()                        |  internal  |             []            |                    ['FACTORY_SLOT']                   |                           []                          |                 ['_getSlotValue']                 |                                                                                                                  []                                                                                                                  |
|                    _implementation()                     |  internal  |             []            |                ['IMPLEMENTATION_SLOT']                |                           []                          |                 ['_getSlotValue']                 |                                                                                                                  []                                                                                                                  |
|          _getReferenceTypeSlot(bytes32,bytes32)          |  internal  |             []            |                           []                          |                           []                          |     ['abi.encodePacked()', 'keccak256(bytes)']    |                                                                                                   ['abi.encodePacked(key_,slot_)']                                                                                                   |
|                  _getSlotValue(bytes32)                  |  internal  |             []            |                           []                          |                           []                          |                 ['sload(uint256)']                |                                                                                                                  []                                                                                                                  |
|              _setSlotValue(bytes32,bytes32)              |  internal  |             []            |                           []                          |                           []                          |            ['sstore(uint256,uint256)']            |                                                                                                                  []                                                                                                                  |
|     acceptNewTerms(address,uint256,bytes[],uint256)      |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                         claim()                          |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
| pullFundsFromLiquidator(address,address,address,uint256) |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      poolDelegate()                      |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                     triggerDefault()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|         rejectNewTerms(address,uint256,bytes[])          |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|               setAllowedSlippage(uint256)                |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                  setAuctioneer(address)                  |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                   setMinRatio(uint256)                   |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                getExpectedAmount(uint256)                |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                setFundsToCapture(uint256)                |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                setPendingLender(address)                 |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                    stopLiquidation()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                          loan()                          |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      loanMigrator()                      |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                       liquidator()                       |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                          pool()                          |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                    allowedSlippage()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                    amountRecovered()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                        minRatio()                        |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|             principalRemainingAtLastClaim()              |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      repossessed()                       |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                     fundsToCapture()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                  upgrade(uint256,bytes)                  |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                        factory()                         |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                     implementation()                     |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                setImplementation(address)                |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                  migrate(address,bytes)                  |  external  |             []            |                           []                          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                  migrate(address,bytes)                  |  external  |             []            |                     ['msg.sender']                    |                           []                          |        ['require(bool,string)', '_factory']       |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |                                                       |                                                       |                    ['_migrate']                   |                                                                                                                                                                                                                                      |
|                setImplementation(address)                |  external  |             []            |                     ['msg.sender']                    |                           []                          |   ['require(bool,string)', '_setImplementation']  |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |                                                       |                                                       |                    ['_factory']                   |                                                                                                                                                                                                                                      |
|                  upgrade(uint256,bytes)                  |  external  |             []            |                     ['msg.sender']                    |                           []                          |    ['require(bool,string)', '_getPoolDelegate']   |                                                                              ['IMapleProxyFactory(_factory()).upgradeInstance(toVersion_,arguments_)']                                                                               |
|                                                          |            |                           |                                                       |                                                       |                    ['_factory']                   |                                                                                                                                                                                                                                      |
|     acceptNewTerms(address,uint256,bytes[],uint256)      |  external  | ['whenProtocolNotPaused'] |              ['_fundsToCapture', '_loan']             |           ['_principalRemainingAtLastClaim']          | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                  ['ERC20Helper.transfer(IMapleLoanLike(loanAddress).fundsAsset(),loanAddress,amount_)', 'IMapleLoanLike(loanAddress).principal()']                                                   |
|                                                          |            |                           |    ['_principalRemainingAtLastClaim', 'msg.sender']   |                                                       |                ['_getPoolDelegate']               |                                                  ['IMapleLoanLike(loanAddress).acceptNewTerms(refinancer_,deadline_,calls_,uint256(0))', 'IMapleLoanLike(loanAddress).principal()']                                                  |
|                                                          |            |                           |                                                       |                                                       |                                                   |                                                                     ['IMapleLoanLike(loanAddress).fundsAsset()', 'IMapleLoanLike(loanAddress).claimableFunds()']                                                                     |
|                         claim()                          |  external  | ['whenProtocolNotPaused'] |                   ['_loan', '_pool']                  |                           []                          | ['require(bool,string)', 'whenProtocolNotPaused'] |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |             ['_repossessed', 'msg.sender']            |                                                       |   ['_handleClaim', '_handleClaimOfRepossessed']   |                                                                                                                                                                                                                                      |
| pullFundsFromLiquidator(address,address,address,uint256) |  external  |             []            |                     ['msg.sender']                    |                           []                          |    ['require(bool,string)', '_getPoolDelegate']   |                                                                                  ['Liquidator(liquidator_).pullFunds(token_,destination_,amount_)']                                                                                  |
|         rejectNewTerms(address,uint256,bytes[])          |  external  |             []            |                ['_loan', 'msg.sender']                |                           []                          |    ['require(bool,string)', '_getPoolDelegate']   |                                                                                ['IMapleLoanLike(_loan).rejectNewTerms(refinancer_,deadline_,calls_)']                                                                                |
|               setAllowedSlippage(uint256)                |  external  | ['whenProtocolNotPaused'] |           ['_allowedSlippage', 'msg.sender']          |                  ['_allowedSlippage']                 | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |                                                       |                                                       |                ['_getPoolDelegate']               |                                                                                                                                                                                                                                      |
|                  setAuctioneer(address)                  |  external  | ['whenProtocolNotPaused'] |             ['_liquidator', 'msg.sender']             |                           []                          | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                        ['Liquidator(_liquidator).setAuctioneer(auctioneer_)']                                                                                        |
|                                                          |            |                           |                                                       |                                                       |                ['_getPoolDelegate']               |                                                                                                                                                                                                                                      |
|                setFundsToCapture(uint256)                |  external  | ['whenProtocolNotPaused'] |           ['_fundsToCapture', 'msg.sender']           |                  ['_fundsToCapture']                  | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |                                                       |                                                       |                ['_getPoolDelegate']               |                                                                                                                                                                                                                                      |
|                setPendingLender(address)                 |  external  | ['whenProtocolNotPaused'] |               ['_loan', '_loanMigrator']              |                           []                          | ['require(bool,string)', 'whenProtocolNotPaused'] |                                                                                        ['IMapleLoanLike(_loan).setPendingLender(newLender_)']                                                                                        |
|                                                          |            |                           |                     ['msg.sender']                    |                                                       |                                                   |                                                                                                                                                                                                                                      |
|                   setMinRatio(uint256)                   |  external  | ['whenProtocolNotPaused'] |              ['_minRatio', 'msg.sender']              |                     ['_minRatio']                     | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                  []                                                                                                                  |
|                                                          |            |                           |                                                       |                                                       |                ['_getPoolDelegate']               |                                                                                                                                                                                                                                      |
|                    stopLiquidation()                     |  external  |             []            |                     ['msg.sender']                    |                    ['_liquidator']                    |    ['require(bool,string)', '_getPoolDelegate']   |                                                                                                                  []                                                                                                                  |
|                     triggerDefault()                     |  external  | ['whenProtocolNotPaused'] |                ['_liquidator', '_loan']               |            ['_liquidator', '_repossessed']            |      ['_getGlobals', 'require(bool,string)']      |                                                                    ['IMapleLoanLike(loanAddress).collateralAsset()', 'IMapleLoanLike(loanAddress).fundsAsset()']                                                                     |
|                                                          |            |                           |      ['_pool', '_principalRemainingAtLastClaim']      |                                                       |             ['whenProtocolNotPaused']             | ['ERC20Helper.transfer(collateralAsset,_liquidator = address(new Liquidator(address(this),collateralAsset,fundsAsset,address(this),address(this),_getGlobals())),collateralAssetAmount)', 'IMapleLoanLike(loanAddress).principal()'] |
|                                                          |            |                           |                 ['msg.sender', 'this']                |                                                       |                                                   |                                        ['new Liquidator(address(this),collateralAsset,fundsAsset,address(this),address(this),_getGlobals())', 'IMapleLoanLike(loanAddress).claimableFunds()']                                        |
|                                                          |            |                           |                                                       |                                                       |                                                   |                                                                                       ['IMapleLoanLike(loanAddress).repossess(address(this))']                                                                                       |
|              _handleClaim(address,address)               |  internal  |             []            | ['_fundsToCapture', '_principalRemainingAtLastClaim'] | ['_fundsToCapture', '_principalRemainingAtLastClaim'] |              ['require(bool,string)']             |                                                                   ['IMapleLoanLike(loan_).principal()', 'IMapleLoanLike(loan_).claimFunds(claimableFunds,pool_)']                                                                    |
|                                                          |            |                           |                                                       |                                                       |                                                   |                                                                           ['IMapleLoanLike(loan_).fundsAsset()', 'IMapleLoanLike(loan_).claimableFunds()']                                                                           |
|                                                          |            |                           |                                                       |                                                       |                                                   |                                                                      ['ERC20Helper.transfer(IMapleLoanLike(loan_).fundsAsset(),pool_,amountOfFundsToCapture)']                                                                       |
|        _handleClaimOfRepossessed(address,address)        |  internal  |             []            | ['_fundsToCapture', '_principalRemainingAtLastClaim'] |          ['_fundsToCapture', '_repossessed']          |  ['require(bool,string)', '_isLiquidationActive'] |                                                                    ['IMapleLoanLike(loan_).fundsAsset()', 'ERC20Helper.transfer(fundsAsset,pool_,totalClaimed)']                                                                     |
|                                                          |            |                           |                        ['this']                       |                                                       |                                                   |                                                                                         ['IERC20Like(fundsAsset).balanceOf(address(this))']                                                                                          |
|                    allowedSlippage()                     |  external  |             []            |                  ['_allowedSlippage']                 |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                    amountRecovered()                     |  external  |             []            |                  ['_amountRecovered']                 |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                        factory()                         |  external  |             []            |                           []                          |                           []                          |                    ['_factory']                   |                                                                                                                  []                                                                                                                  |
|                     fundsToCapture()                     |  external  |             []            |                  ['_fundsToCapture']                  |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                getExpectedAmount(uint256)                |  external  | ['whenProtocolNotPaused'] |             ['_allowedSlippage', '_loan']             |                           []                          |      ['_getGlobals', 'whenProtocolNotPaused']     |                                                              ['IMapleGlobalsLike(globals).getLatestPrice(collateralAsset)', 'IMapleLoanLike(loanAddress).fundsAsset()']                                                              |
|                                                          |            |                           |                     ['_minRatio']                     |                                                       |                                                   |                                                                     ['IERC20Like(collateralAsset).decimals()', 'IMapleLoanLike(loanAddress).collateralAsset()']                                                                      |
|                                                          |            |                           |                                                       |                                                       |                                                   |                                                                    ['IERC20Like(fundsAsset).decimals()', 'IMapleGlobalsLike(globals).getLatestPrice(fundsAsset)']                                                                    |
|                     implementation()                     |  external  |             []            |                           []                          |                           []                          |                ['_implementation']                |                                                                                                                  []                                                                                                                  |
|                       liquidator()                       |  external  |             []            |                    ['_liquidator']                    |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                          loan()                          |  external  |             []            |                       ['_loan']                       |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      loanMigrator()                      |  external  |             []            |                   ['_loanMigrator']                   |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                        minRatio()                        |  external  |             []            |                     ['_minRatio']                     |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                          pool()                          |  external  |             []            |                       ['_pool']                       |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      poolDelegate()                      |  external  |             []            |                           []                          |                           []                          |                ['_getPoolDelegate']               |                                                                                                                  []                                                                                                                  |
|             principalRemainingAtLastClaim()              |  external  |             []            |           ['_principalRemainingAtLastClaim']          |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      repossessed()                       |  external  |             []            |                    ['_repossessed']                   |                           []                          |                         []                        |                                                                                                                  []                                                                                                                  |
|                      _getGlobals()                       |  internal  |             []            |                       ['_pool']                       |                           []                          |                         []                        |                                                                  ['IPoolLike(_pool).superFactory()', 'IPoolFactoryLike(IPoolLike(_pool).superFactory()).globals()']                                                                  |
|                    _getPoolDelegate()                    |  internal  |             []            |                       ['_pool']                       |                           []                          |                         []                        |                                                                                                 ['IPoolLike(_pool).poolDelegate()']                                                                                                  |
|                  _isLiquidationActive()                  |  internal  |             []            |                ['_liquidator', '_loan']               |                           []                          |                         []                        |                                                   ['IERC20Like(IMapleLoanLike(_loan).collateralAsset()).balanceOf(liquidatorAddress)', 'IMapleLoanLike(_loan).collateralAsset()']                                                    |
|          slitherConstructorConstantVariables()           |  internal  |             []            |                           []                          |        ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT']        |                         []                        |                                                                                                                  []                                                                                                                  |
+----------------------------------------------------------+------------+---------------------------+-------------------------------------------------------+-------------------------------------------------------+---------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+-------------------------+------------+------+-------+-----------------------------------------+-------------------------------------------------------+
|        Modifiers        | Visibility | Read | Write |              Internal Calls             |                     External Calls                    |
+-------------------------+------------+------+-------+-----------------------------------------+-------------------------------------------------------+
| whenProtocolNotPaused() |  internal  |  []  |   []  | ['_getGlobals', 'require(bool,string)'] | ['IMapleGlobalsLike(_getGlobals()).protocolPaused()'] |
+-------------------------+------------+------+-------+-----------------------------------------+-------------------------------------------------------+


Contract DebtLockerStorage
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator']
Inheritance:: []
 
+----------+------------+-----------+------+-------+----------------+----------------+
| Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------+------------+-----------+------+-------+----------------+----------------+
+----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IDebtLocker
Contract vars: []
Inheritance:: ['IMapleProxied', 'IProxied']
 
+----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         Function                         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                  upgrade(uint256,bytes)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                        factory()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                     implementation()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                setImplementation(address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  migrate(address,bytes)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|     acceptNewTerms(address,uint256,bytes[],uint256)      |  external  |     []    |  []  |   []  |       []       |       []       |
|                         claim()                          |  external  |     []    |  []  |   []  |       []       |       []       |
| pullFundsFromLiquidator(address,address,address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|                      poolDelegate()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                     triggerDefault()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|         rejectNewTerms(address,uint256,bytes[])          |  external  |     []    |  []  |   []  |       []       |       []       |
|               setAllowedSlippage(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  setAuctioneer(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                   setMinRatio(uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                getExpectedAmount(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                setFundsToCapture(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                setPendingLender(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                    stopLiquidation()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                          loan()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                      loanMigrator()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                       liquidator()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                          pool()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                    allowedSlippage()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                    amountRecovered()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                        minRatio()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|             principalRemainingAtLastClaim()              |  external  |     []    |  []  |   []  |       []       |       []       |
|                      repossessed()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                     fundsToCapture()                     |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|     decimals()     |  external  |     []    |  []  |   []  |       []       |       []       |
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+--------------+------------+-----------+------+-------+----------------+----------------+
|   Function   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------+------------+-----------+------+-------+----------------+----------------+
| auctioneer() |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               Function              | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+
| defaultUniswapPath(address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|       getLatestPrice(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|            investorFee()            |  external  |     []    |  []  |   []  |       []       |       []       |
|   isValidCollateralAsset(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidLiquidityAsset(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|           mapleTreasury()           |  external  |     []    |  []  |   []  |       []       |       []       |
|           protocolPaused()          |  external  |     []    |  []  |   []  |       []       |       []       |
|            treasuryFee()            |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| acceptNewTerms(address,uint256,bytes[],uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|                 claimableFunds()                |  external  |     []    |  []  |   []  |       []       |       []       |
|           claimFunds(uint256,address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                collateralAsset()                |  external  |     []    |  []  |   []  |       []       |       []       |
|                   fundsAsset()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                     lender()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                   principal()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|               principalRequested()              |  external  |     []    |  []  |   []  |       []       |       []       |
|                repossess(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|              refinanceCommitment()              |  external  |     []    |  []  |   []  |       []       |       []       |
|     rejectNewTerms(address,uint256,bytes[])     |  external  |     []    |  []  |   []  |       []       |       []       |
|            setPendingLender(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: []
 
+----------------+------------+-----------+------+-------+----------------+----------------+
|    Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------+------------+-----------+------+-------+----------------+----------------+
| poolDelegate() |  external  |     []    |  []  |   []  |       []       |       []       |
| superFactory() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolFactoryLike
Contract vars: []
Inheritance:: []
 
+-----------+------------+-----------+------+-------+----------------+----------------+
|  Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------+------------+-----------+------+-------+----------------+----------------+
| globals() |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------+------------+-----------+------+-------+----------------+----------------+

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
+---------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['abi.decode()', 'code(address)']   |                                               ['token_.call(data_)', 'abi.decode(returnData,(bool))']                                               |
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
Contract vars: ['NOT_LOCKED', 'LOCKED', '_locked', 'collateralAsset', 'destination', 'fundsAsset', 'globals', 'owner', 'auctioneer']
Inheritance:: ['ILiquidator']
 
+--------------------------------------------------------------+------------+-----------------------------------+------------------------------------+-----------------------------------+-----------------------------------------------+--------------------------------------------------------------------------------------------------+
|                           Function                           | Visibility |             Modifiers             |                Read                |               Write               |                 Internal Calls                |                                          External Calls                                          |
+--------------------------------------------------------------+------------+-----------------------------------+------------------------------------+-----------------------------------+-----------------------------------------------+--------------------------------------------------------------------------------------------------+
|                      collateralAsset()                       |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                        destination()                         |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                         auctioneer()                         |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                         fundsAsset()                         |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                          globals()                           |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                           owner()                            |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                    setAuctioneer(address)                    |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|              pullFunds(address,address,uint256)              |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|                  getExpectedAmount(uint256)                  |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
|           liquidatePortion(uint256,uint256,bytes)            |  external  |                 []                |                 []                 |                 []                |                       []                      |                                                []                                                |
| constructor(address,address,address,address,address,address) |   public   |                 []                | ['collateralAsset', 'destination'] | ['auctioneer', 'collateralAsset'] |            ['require(bool,string)']           |                    ['IMapleGlobalsLike(globals = globals_).protocolPaused()']                    |
|                                                              |            |                                   |     ['fundsAsset', 'globals']      |   ['destination', 'fundsAsset']   |                                               |                                                                                                  |
|                                                              |            |                                   |             ['owner']              |        ['globals', 'owner']       |                                               |                                                                                                  |
|                    setAuctioneer(address)                    |  external  |                 []                |      ['auctioneer', 'owner']       |           ['auctioneer']          |            ['require(bool,string)']           |                                                []                                                |
|                                                              |            |                                   |           ['msg.sender']           |                                   |                                               |                                                                                                  |
|              pullFunds(address,address,uint256)              |  external  |                 []                |      ['owner', 'msg.sender']       |                 []                |            ['require(bool,string)']           |                      ['ERC20Helper.transfer(token_,destination_,amount_)']                       |
|                  getExpectedAmount(uint256)                  |   public   |                 []                |           ['auctioneer']           |                 []                |                       []                      |                  ['IAuctioneerLike(auctioneer).getExpectedAmount(swapAmount_)']                  |
|           liquidatePortion(uint256,uint256,bytes)            |  external  | ['whenProtocolNotPaused', 'lock'] | ['collateralAsset', 'destination'] |                 []                | ['getExpectedAmount', 'require(bool,string)'] | ['ERC20Helper.transfer(collateralAsset,msg.sender,collateralAmount_)', 'msg.sender.call(data_)'] |
|                                                              |            |                                   |    ['fundsAsset', 'msg.sender']    |                                   |       ['whenProtocolNotPaused', 'lock']       |           ['ERC20Helper.transferFrom(fundsAsset,msg.sender,destination,returnAmount)']           |
|            slitherConstructorConstantVariables()             |  internal  |                 []                |                 []                 |      ['LOCKED', 'NOT_LOCKED']     |                       []                      |                                                []                                                |
+--------------------------------------------------------------+------------+-----------------------------------+------------------------------------+-----------------------------------+-----------------------------------------------+--------------------------------------------------------------------------------------------------+

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
|              destination()              |  external  |     []    |  []  |   []  |       []       |       []       |
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
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
| getExpectedAmount(uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

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


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['abi.decode()', 'code(address)']   |                                               ['abi.decode(returnData,(bool))', 'token_.call(data_)']                                               |
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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['abi.encodePacked()', 'keccak256(bytes)'] |    ['abi.encodePacked(key_,slot_)']    |
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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |            []           |                    []                   | ['abi.encodePacked()', 'keccak256(bytes)'] |    ['abi.encodePacked(key_,slot_)']    |
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
| _getReferenceTypeSlot(bytes32,bytes32) |  internal  |     []    |  []  |   []  | ['abi.encodePacked()', 'keccak256(bytes)'] | ['abi.encodePacked(key_,slot_)'] |
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

modules/debt-locker-v4/contracts/DebtLocker.sol analyzed (29 contracts)
