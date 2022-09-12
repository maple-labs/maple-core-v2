Compilation warnings/errors on modules/pool-v2/contracts/PoolManager.sol:
Warning: Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> modules/pool-v2/contracts/PoolManager.sol:371:43:
    |
371 |  ... ction canCall(bytes32 functionId_, address caller_, bytes memory data_) external view ...
    |                                         ^^^^^^^^^^^^^^^

Warning: Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> modules/pool-v2/contracts/PoolManager.sol:448:30:
    |
448 |     function getEscrowParams(address owner_, uint256 shares_) external view override returns (uint256 escrowShares_, address destination_) {
    |                              ^^^^^^^^^^^^^^

Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/pool-v2/contracts/PoolManager.sol:23:1:
   |
23 | contract PoolManager is IPoolManager, MapleProxiedInternals, PoolManagerStorage {
   | ^ (Relevant source part starts here and spans across multiple lines).



Contract PoolManager
Contract vars: ['FACTORY_SLOT', 'IMPLEMENTATION_SLOT', '_locked', 'poolDelegate', 'pendingPoolDelegate', 'asset', 'pool', 'poolDelegateCover', 'withdrawalManager', 'active', 'configured', 'openToPublic', 'liquidityCap', 'delegateManagementFeeRate', 'loanManagers', 'isLoanManager', 'isValidLender', 'loanManagerList', 'HUNDRED_PERCENT']
Inheritance:: ['PoolManagerStorage', 'MapleProxiedInternals', 'ProxiedInternals', 'SlotManipulatable', 'IPoolManager', 'IPoolManagerStorage', 'IMapleProxied', 'IProxied']
 
+---------------------------------------------------------+------------+-------------------------------------------+--------------------------------------------------+---------------------------------------------+---------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                         Function                        | Visibility |                 Modifiers                 |                       Read                       |                    Write                    |                   Internal Calls                  |                                                                                       External Calls                                                                                      |
+---------------------------------------------------------+------------+-------------------------------------------+--------------------------------------------------+---------------------------------------------+---------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                         active()                        |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                         asset()                         |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                       configured()                      |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  isLoanManager(address)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  isValidLender(address)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                 loanManagerList(uint256)                |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  loanManagers(address)                  |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                      liquidityCap()                     |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|               delegateManagementFeeRate()               |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                      openToPublic()                     |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  pendingPoolDelegate()                  |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                          pool()                         |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                      poolDelegate()                     |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   poolDelegateCover()                   |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   withdrawalManager()                   |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                 _migrate(address,bytes)                 |  internal  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                           ['migrator_.delegatecall(arguments_)']                                                                          |
|                   _setFactory(address)                  |  internal  |                     []                    |                 ['FACTORY_SLOT']                 |                      []                     |                 ['_setSlotValue']                 |                                                                                             []                                                                                            |
|               _setImplementation(address)               |  internal  |                     []                    |             ['IMPLEMENTATION_SLOT']              |                      []                     |                 ['_setSlotValue']                 |                                                                                             []                                                                                            |
|                        _factory()                       |  internal  |                     []                    |                 ['FACTORY_SLOT']                 |                      []                     |                 ['_getSlotValue']                 |                                                                                             []                                                                                            |
|                    _implementation()                    |  internal  |                     []                    |             ['IMPLEMENTATION_SLOT']              |                      []                     |                 ['_getSlotValue']                 |                                                                                             []                                                                                            |
|          _getReferenceTypeSlot(bytes32,bytes32)         |  internal  |                     []                    |                        []                        |                      []                     |     ['abi.encodePacked()', 'keccak256(bytes)']    |                                                                              ['abi.encodePacked(key_,slot_)']                                                                             |
|                  _getSlotValue(bytes32)                 |  internal  |                     []                    |                        []                        |                      []                     |                 ['sload(uint256)']                |                                                                                             []                                                                                            |
|              _setSlotValue(bytes32,bytes32)             |  internal  |                     []                    |                        []                        |                      []                     |            ['sstore(uint256,uint256)']            |                                                                                             []                                                                                            |
|               acceptPendingPoolDelegate()               |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|             setPendingPoolDelegate(address)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|        configure(address,address,uint256,uint256)       |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                 addLoanManager(address)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                removeLoanManager(address)               |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                     setActive(bool)                     |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              setAllowedLender(address,bool)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                 setLiquidityCap(uint256)                |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|          setDelegateManagementFeeRate(uint256)          |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                    setOpenToPublic()                    |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              setWithdrawalManager(address)              |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
| acceptNewTerms(address,address,uint256,bytes[],uint256) |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              fund(uint256,address,address)              |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|           finishCollateralLiquidation(address)          |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              removeDefaultWarning(address)              |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                 triggerDefault(address)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              triggerDefaultWarning(address)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              processRedeem(uint256,address)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              removeShares(uint256,address)              |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              requestRedeem(uint256,address)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  depositCover(uint256)                  |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              withdrawCover(uint256,address)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|             getEscrowParams(address,uint256)            |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|               convertToExitShares(uint256)              |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   maxDeposit(address)                   |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                     maxMint(address)                    |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                    maxRedeem(address)                   |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   maxWithdraw(address)                  |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              previewRedeem(address,uint256)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|             previewWithdraw(address,uint256)            |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|              canCall(bytes32,address,bytes)             |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                        globals()                        |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                        governor()                       |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   hasSufficientCover()                  |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                      totalAssets()                      |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                    unrealizedLosses()                   |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  upgrade(uint256,bytes)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                        factory()                        |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                     implementation()                    |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                setImplementation(address)               |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  migrate(address,bytes)                 |  external  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                  migrate(address,bytes)                 |  external  |                     []                    |                  ['msg.sender']                  |                      []                     |        ['_migrate', 'require(bool,string)']       |                                                                                             []                                                                                            |
|                                                         |            |                                           |                                                  |                                             |                    ['_factory']                   |                                                                                                                                                                                           |
|                setImplementation(address)               |  external  |         ['whenProtocolNotPaused']         |                  ['msg.sender']                  |                      []                     |  ['whenProtocolNotPaused', '_setImplementation']  |                                                                                             []                                                                                            |
|                                                         |            |                                           |                                                  |                                             |        ['require(bool,string)', '_factory']       |                                                                                                                                                                                           |
|                  upgrade(uint256,bytes)                 |  external  |         ['whenProtocolNotPaused']         |           ['poolDelegate', 'msg.data']           |                      []                     |        ['globals', 'whenProtocolNotPaused']       |                          ['IMapleProxyFactory(_factory()).upgradeInstance(version_,arguments_)', 'mapleGlobals_.unscheduleCall(msg.sender,PM:UPGRADE,msg.data)']                          |
|                                                         |            |                                           |              ['msg.sender', 'this']              |                                             |        ['require(bool,string)', '_factory']       |                                                    ['mapleGlobals_.isValidScheduledCall(msg.sender,address(this),PM:UPGRADE,msg.data)']                                                   |
|                                                         |            |                                           |                                                  |                                             |                    ['governor']                   |                                                                                                                                                                                           |
|               acceptPendingPoolDelegate()               |  external  |         ['whenProtocolNotPaused']         |     ['pendingPoolDelegate', 'poolDelegate']      |   ['pendingPoolDelegate', 'poolDelegate']   | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                     ['IMapleGlobalsLike(globals()).transferOwnedPoolManager(poolDelegate,msg.sender)']                                                    |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                    ['globals']                    |                                                                                                                                                                                           |
|             setPendingPoolDelegate(address)             |  external  |         ['whenProtocolNotPaused']         |          ['poolDelegate', 'msg.sender']          |           ['pendingPoolDelegate']           | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                 addLoanManager(address)                 |  external  |         ['whenProtocolNotPaused']         |       ['isLoanManager', 'loanManagerList']       |     ['isLoanManager', 'loanManagerList']    | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                           ['loanManagerList.push(loanManager_)']                                                                          |
|                                                         |            |                                           |          ['poolDelegate', 'msg.sender']          |                                             |                                                   |                                                                                                                                                                                           |
|        configure(address,address,uint256,uint256)       |  external  |                     []                    |        ['HUNDRED_PERCENT', 'configured']         | ['configured', 'delegateManagementFeeRate'] |        ['require(bool,string)', 'globals']        |                                             ['IMapleGlobalsLike(globals()).isPoolDeployer(msg.sender)', 'loanManagerList.push(loanManager_)']                                             |
|                                                         |            |                                           |        ['loanManagerList', 'msg.sender']         |      ['isLoanManager', 'liquidityCap']      |                                                   |                                                                                                                                                                                           |
|                                                         |            |                                           |                                                  |   ['loanManagerList', 'withdrawalManager']  |                                                   |                                                                                                                                                                                           |
|                removeLoanManager(address)               |  external  |         ['whenProtocolNotPaused']         |       ['loanManagerList', 'poolDelegate']        |     ['isLoanManager', 'loanManagerList']    | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                 ['loanManagerList.pop()']                                                                                 |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                                                   |                                                                                                                                                                                           |
|                     setActive(bool)                     |  external  |         ['whenProtocolNotPaused']         |             ['active', 'msg.sender']             |                  ['active']                 | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                                                         |            |                                           |                                                  |                                             |                    ['globals']                    |                                                                                                                                                                                           |
|              setAllowedLender(address,bool)             |  external  |         ['whenProtocolNotPaused']         |        ['isValidLender', 'poolDelegate']         |              ['isValidLender']              | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                                                   |                                                                                                                                                                                           |
|          setDelegateManagementFeeRate(uint256)          |  external  |         ['whenProtocolNotPaused']         | ['HUNDRED_PERCENT', 'delegateManagementFeeRate'] |        ['delegateManagementFeeRate']        | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                                                         |            |                                           |          ['poolDelegate', 'msg.sender']          |                                             |                                                   |                                                                                                                                                                                           |
|                 setLiquidityCap(uint256)                |  external  |         ['whenProtocolNotPaused']         |         ['liquidityCap', 'poolDelegate']         |               ['liquidityCap']              | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                                                   |                                                                                                                                                                                           |
|                    setOpenToPublic()                    |  external  |         ['whenProtocolNotPaused']         |          ['poolDelegate', 'msg.sender']          |               ['openToPublic']              | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|              setWithdrawalManager(address)              |  external  |         ['whenProtocolNotPaused']         |      ['poolDelegate', 'withdrawalManager']       |            ['withdrawalManager']            | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                             []                                                                                            |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                                                   |                                                                                                                                                                                           |
| acceptNewTerms(address,address,uint256,bytes[],uint256) |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |            ['asset', 'isLoanManager']            |                      []                     |        ['globals', 'whenProtocolNotPaused']       |                                           ['IERC20Like(pool_).totalSupply()', 'ERC20Helper.transferFrom(asset_,pool_,loan_,principalIncrease_)']                                          |
|                                                         |            |                                           |             ['loanManagers', 'pool']             |                                             |      ['nonReentrant', 'require(bool,string)']     |                ['IMapleGlobalsLike(globals_).isBorrower(ILoanLike(loan_).borrower())', 'ILoanManagerLike(loanManager_).acceptNewTerms(loan_,refinancer_,deadline_,calls_)']               |
|                                                         |            |                                           |          ['poolDelegate', 'msg.sender']          |                                             |              ['_hasSufficientCover']              |                                                                              ['ILoanLike(loan_).borrower()']                                                                              |
|              fund(uint256,address,address)              |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |            ['asset', 'isLoanManager']            |               ['loanManagers']              |        ['globals', 'whenProtocolNotPaused']       |                                               ['ILoanLike(loan_).borrower()', 'IWithdrawalManagerLike(withdrawalManager).lockedLiquidity()']                                              |
|                                                         |            |                                           |             ['pool', 'poolDelegate']             |                                             |      ['nonReentrant', 'require(bool,string)']     |                                                    ['IERC20Like(asset_).balanceOf(address(pool_))', 'IERC20Like(pool_).totalSupply()']                                                    |
|                                                         |            |                                           |       ['withdrawalManager', 'msg.sender']        |                                             |              ['_hasSufficientCover']              |                                         ['ILoanManagerLike(loanManager_).fund(loan_)', 'ERC20Helper.transferFrom(asset_,pool_,loan_,principal_)']                                         |
|                                                         |            |                                           |                                                  |                                             |                                                   |                                                          ['IMapleGlobalsLike(globals_).isBorrower(ILoanLike(loan_).borrower())']                                                          |
|           finishCollateralLiquidation(address)          |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |         ['loanManagers', 'poolDelegate']         |                      []                     |          ['_handleCover', 'nonReentrant']         |                                                        ['ILoanManagerLike(loanManagers[loan_]).finishCollateralLiquidation(loan_)']                                                       |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                                                                                           |
|              removeDefaultWarning(address)              |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |         ['loanManagers', 'poolDelegate']         |                      []                     |            ['governor', 'nonReentrant']           |                                                     ['ILoanManagerLike(loanManagers[loan_]).removeDefaultWarning(loan_,isGovernor_)']                                                     |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                                                                                           |
|                 triggerDefault(address)                 |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |         ['loanManagers', 'poolDelegate']         |                      []                     |          ['_handleCover', 'nonReentrant']         |                                                              ['ILoanManagerLike(loanManagers[loan_]).triggerDefault(loan_)']                                                              |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                                                                                                                                                           |
|              triggerDefaultWarning(address)             |  external  |                     []                    |         ['loanManagers', 'poolDelegate']         |                      []                     |        ['governor', 'require(bool,string)']       |                                                     ['ILoanManagerLike(loanManagers[loan_]).triggerDefaultWarning(loan_,isGovernor_)']                                                    |
|                                                         |            |                                           |        ['block.timestamp', 'msg.sender']         |                                             |                                                   |                                                                                                                                                                                           |
|              processRedeem(uint256,address)             |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |          ['pool', 'withdrawalManager']           |                      []                     |     ['whenProtocolNotPaused', 'nonReentrant']     |                                                         ['IWithdrawalManagerLike(withdrawalManager).processExit(owner_,shares_)']                                                         |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |              ['require(bool,string)']             |                                                                                                                                                                                           |
|              removeShares(uint256,address)              |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |          ['pool', 'withdrawalManager']           |                      []                     |     ['whenProtocolNotPaused', 'nonReentrant']     |                                                         ['IWithdrawalManagerLike(withdrawalManager).removeShares(shares_,owner_)']                                                        |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |              ['require(bool,string)']             |                                                                                                                                                                                           |
|              requestRedeem(uint256,address)             |  external  | ['whenProtocolNotPaused', 'nonReentrant'] |          ['pool', 'withdrawalManager']           |                      []                     |     ['whenProtocolNotPaused', 'nonReentrant']     |                              ['IWithdrawalManagerLike(withdrawalManager).addShares(shares_,owner_)', 'ERC20Helper.approve(pool_,withdrawalManager,shares_)']                              |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |              ['require(bool,string)']             |                                                                                                                                                                                           |
|                  depositCover(uint256)                  |  external  |         ['whenProtocolNotPaused']         |          ['asset', 'poolDelegateCover']          |                      []                     | ['whenProtocolNotPaused', 'require(bool,string)'] |                                                          ['ERC20Helper.transferFrom(asset,msg.sender,poolDelegateCover,amount_)']                                                         |
|                                                         |            |                                           |                  ['msg.sender']                  |                                             |                                                   |                                                                                                                                                                                           |
|              withdrawCover(uint256,address)             |  external  |         ['whenProtocolNotPaused']         |            ['asset', 'poolDelegate']             |                      []                     | ['whenProtocolNotPaused', 'require(bool,string)'] |                               ['IERC20Like(asset).balanceOf(poolDelegateCover)', 'IPoolDelegateCoverLike(poolDelegateCover).moveFunds(amount_,recipient_)']                               |
|                                                         |            |                                           |       ['poolDelegateCover', 'msg.sender']        |                                             |                    ['globals']                    |                                                               ['IMapleGlobalsLike(globals()).minCoverAmount(address(this))']                                                              |
|                                                         |            |                                           |                     ['this']                     |                                             |                                                   |                                                                                                                                                                                           |
|              _handleCover(uint256,uint256)              |  internal  |                     []                    |           ['HUNDRED_PERCENT', 'asset']           |                      []                     |                ['_min', 'globals']                | ['IMapleGlobalsLike(globals_).maxCoverLiquidationPercent(address(this))', 'IPoolDelegateCoverLike(poolDelegateCover).moveFunds(toTreasury_,IMapleGlobalsLike(globals_).mapleTreasury())'] |
|                                                         |            |                                           |          ['pool', 'poolDelegateCover']           |                                             |                                                   |                                    ['IMapleGlobalsLike(globals_).mapleTreasury()', 'IPoolDelegateCoverLike(poolDelegateCover).moveFunds(toPool_,pool)']                                   |
|                                                         |            |                                           |                     ['this']                     |                                             |                                                   |                                                                     ['IERC20Like(asset).balanceOf(poolDelegateCover)']                                                                    |
|              canCall(bytes32,address,bytes)             |  external  |                     []                    |                     ['pool']                     |                      []                     |          ['abi.decode()', '_canDeposit']          |                                              ['IPoolLike(pool).previewMint(shares__scope_3)', 'abi.decode(data_,(address,address,uint256))']                                              |
|                                                         |            |                                           |                                                  |                                             |            ['_canTransfer', 'globals']            |                                                      ['abi.decode(data_,(uint256,address))', 'IPoolLike(pool).previewMint(shares_)']                                                      |
|                                                         |            |                                           |                                                  |                                             |                                                   |                                        ['abi.decode(data_,(address,uint256))', 'abi.decode(data_,(uint256,address,uint256,uint8,bytes32,bytes32))']                                       |
|                                                         |            |                                           |                                                  |                                             |                                                   |                                                  ['IMapleGlobalsLike(globals()).protocolPaused()', 'abi.decode(data_,(uint256,address))']                                                 |
|                                                         |            |                                           |                                                  |                                             |                                                   |                                                       ['abi.decode(data_,(uint256,address,uint256,uint256,uint8,bytes32,bytes32))']                                                       |
|                        factory()                        |  external  |                     []                    |                        []                        |                      []                     |                    ['_factory']                   |                                                                                             []                                                                                            |
|                        globals()                        |   public   |                     []                    |                        []                        |                      []                     |                    ['_factory']                   |                                                                   ['IMapleProxyFactoryLike(_factory()).mapleGlobals()']                                                                   |
|                        governor()                       |   public   |                     []                    |                        []                        |                      []                     |                    ['globals']                    |                                                                        ['IMapleGlobalsLike(globals()).governor()']                                                                        |
|                   hasSufficientCover()                  |   public   |                     []                    |                    ['asset']                     |                      []                     |         ['globals', '_hasSufficientCover']        |                                                                                             []                                                                                            |
|                     implementation()                    |  external  |                     []                    |                        []                        |                      []                     |                ['_implementation']                |                                                                                             []                                                                                            |
|                      totalAssets()                      |   public   |                     []                    |           ['asset', 'loanManagerList']           |                      []                     |                         []                        |                                           ['ILoanManagerLike(loanManagerList[i_]).assetsUnderManagement()', 'IERC20Like(asset).balanceOf(pool)']                                          |
|                                                         |            |                                           |                     ['pool']                     |                                             |                                                   |                                                                                                                                                                                           |
|               convertToExitShares(uint256)              |   public   |                     []                    |                     ['pool']                     |                      []                     |                         []                        |                                                                      ['IPoolLike(pool).convertToExitShares(assets_)']                                                                     |
|             getEscrowParams(address,uint256)            |  external  |                     []                    |                     ['this']                     |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                   maxDeposit(address)                   |  external  |                     []                    |                        []                        |                      []                     |          ['_getMaxAssets', 'totalAssets']         |                                                                                             []                                                                                            |
|                     maxMint(address)                    |  external  |                     []                    |                     ['pool']                     |                      []                     |          ['_getMaxAssets', 'totalAssets']         |                                                                             ['IPoolLike(pool).totalSupply()']                                                                             |
|                    maxRedeem(address)                   |  external  |                     []                    |              ['withdrawalManager']               |                      []                     |                         []                        |                           ['IWithdrawalManagerLike(withdrawalManager).isInExitWindow(owner_)', 'IWithdrawalManagerLike(withdrawalManager).lockedShares(owner_)']                          |
|                   maxWithdraw(address)                  |  external  |                     []                    |          ['pool', 'withdrawalManager']           |                      []                     |        ['totalAssets', 'unrealizedLosses']        |                           ['IWithdrawalManagerLike(withdrawalManager).lockedShares(owner_)', 'IWithdrawalManagerLike(withdrawalManager).isInExitWindow(owner_)']                          |
|                                                         |            |                                           |                                                  |                                             |                                                   |                                                                             ['IPoolLike(pool).totalSupply()']                                                                             |
|              previewRedeem(address,uint256)             |  external  |                     []                    |              ['withdrawalManager']               |                      []                     |                         []                        |                                                        ['IWithdrawalManagerLike(withdrawalManager).previewRedeem(owner_,shares_)']                                                        |
|             previewWithdraw(address,uint256)            |  external  |                     []                    |              ['withdrawalManager']               |                      []                     |              ['convertToExitShares']              |                                              ['IWithdrawalManagerLike(withdrawalManager).previewRedeem(owner_,convertToExitShares(assets_))']                                             |
|                    unrealizedLosses()                   |   public   |                     []                    |               ['loanManagerList']                |                      []                     |              ['_min', 'totalAssets']              |                                                                ['ILoanManagerLike(loanManagerList[i_]).unrealizedLosses()']                                                               |
|           _canDeposit(uint256,address,string)           |  internal  |                     []                    |           ['active', 'isValidLender']            |                      []                     |       ['_formatErrorMessage', 'totalAssets']      |                                                                                             []                                                                                            |
|                                                         |            |                                           |         ['liquidityCap', 'openToPublic']         |                                             |                                                   |                                                                                                                                                                                           |
|               _canTransfer(address,string)              |  internal  |                     []                    |        ['isValidLender', 'openToPublic']         |                      []                     |              ['_formatErrorMessage']              |                                                                                             []                                                                                            |
|            _formatErrorMessage(string,string)           |  internal  |                     []                    |                        []                        |                      []                     |               ['abi.encodePacked()']              |                                                                      ['abi.encodePacked(errorPrefix_,partialError_)']                                                                     |
|              _getMaxAssets(address,uint256)             |  internal  |                     []                    |        ['isValidLender', 'liquidityCap']         |                      []                     |                         []                        |                                                                                             []                                                                                            |
|                                                         |            |                                           |                 ['openToPublic']                 |                                             |                                                   |                                                                                                                                                                                           |
|           _hasSufficientCover(address,address)          |  internal  |                     []                    |          ['poolDelegateCover', 'this']           |                      []                     |                         []                        |                                      ['IERC20Like(asset_).balanceOf(poolDelegateCover)', 'IMapleGlobalsLike(globals_).minCoverAmount(address(this))']                                     |
|                  _min(uint256,uint256)                  |  internal  |                     []                    |                        []                        |                      []                     |                         []                        |                                                                                             []                                                                                            |
|          slitherConstructorConstantVariables()          |  internal  |                     []                    |                        []                        |     ['FACTORY_SLOT', 'HUNDRED_PERCENT']     |                         []                        |                                                                                             []                                                                                            |
|                                                         |            |                                           |                                                  |           ['IMPLEMENTATION_SLOT']           |                                                   |                                                                                                                                                                                           |
+---------------------------------------------------------+------------+-------------------------------------------+--------------------------------------------------+---------------------------------------------+---------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+-------------------------+------------+-------------+-------------+-------------------------------------+---------------------------------------------------+
|        Modifiers        | Visibility |     Read    |    Write    |            Internal Calls           |                   External Calls                  |
+-------------------------+------------+-------------+-------------+-------------------------------------+---------------------------------------------------+
|      nonReentrant()     |  internal  | ['_locked'] | ['_locked'] |       ['require(bool,string)']      |                         []                        |
| whenProtocolNotPaused() |  internal  |      []     |      []     | ['require(bool,string)', 'globals'] | ['IMapleGlobalsLike(globals()).protocolPaused()'] |
+-------------------------+------------+-------------+-------------+-------------------------------------+---------------------------------------------------+


Contract IPoolManager
Contract vars: []
Inheritance:: ['IPoolManagerStorage', 'IMapleProxied', 'IProxied']
 
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         Function                        | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                         active()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                         asset()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                       configured()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isLoanManager(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                  isValidLender(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                 loanManagerList(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|                  loanManagers(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                      liquidityCap()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|               delegateManagementFeeRate()               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      openToPublic()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                  pendingPoolDelegate()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                          pool()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                      poolDelegate()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                   poolDelegateCover()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                   withdrawalManager()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                  upgrade(uint256,bytes)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                        factory()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                     implementation()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                setImplementation(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                  migrate(address,bytes)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|               acceptPendingPoolDelegate()               |  external  |     []    |  []  |   []  |       []       |       []       |
|             setPendingPoolDelegate(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|        configure(address,address,uint256,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|                 addLoanManager(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                removeLoanManager(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                     setActive(bool)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|              setAllowedLender(address,bool)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 setLiquidityCap(uint256)                |  external  |     []    |  []  |   []  |       []       |       []       |
|          setDelegateManagementFeeRate(uint256)          |  external  |     []    |  []  |   []  |       []       |       []       |
|                    setOpenToPublic()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|              setWithdrawalManager(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,address,uint256,bytes[],uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|              fund(uint256,address,address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|           finishCollateralLiquidation(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|              removeDefaultWarning(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                 triggerDefault(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|              triggerDefaultWarning(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|              processRedeem(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|              removeShares(uint256,address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|              requestRedeem(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                  depositCover(uint256)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|              withdrawCover(uint256,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|             getEscrowParams(address,uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|               convertToExitShares(uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   maxDeposit(address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                     maxMint(address)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                    maxRedeem(address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                   maxWithdraw(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|              previewRedeem(address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|             previewWithdraw(address,uint256)            |  external  |     []    |  []  |   []  |       []       |       []       |
|              canCall(bytes32,address,bytes)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                        globals()                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                        governor()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                   hasSufficientCover()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                      totalAssets()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                    unrealizedLosses()                   |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerStorage
Contract vars: []
Inheritance:: []
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           active()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           asset()           |  external  |     []    |  []  |   []  |       []       |       []       |
|         configured()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    isLoanManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidLender(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|   loanManagerList(uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
|    loanManagers(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|        liquidityCap()       |  external  |     []    |  []  |   []  |       []       |       []       |
| delegateManagementFeeRate() |  external  |     []    |  []  |   []  |       []       |       []       |
|        openToPublic()       |  external  |     []    |  []  |   []  |       []       |       []       |
|    pendingPoolDelegate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolDelegate()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     poolDelegateCover()     |  external  |     []    |  []  |   []  |       []       |       []       |
|     withdrawalManager()     |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

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


Contract PoolManagerStorage
Contract vars: ['_locked', 'poolDelegate', 'pendingPoolDelegate', 'asset', 'pool', 'poolDelegateCover', 'withdrawalManager', 'active', 'configured', 'openToPublic', 'liquidityCap', 'delegateManagementFeeRate', 'loanManagers', 'isLoanManager', 'isValidLender', 'loanManagerList']
Inheritance:: ['IPoolManagerStorage']
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           active()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           asset()           |  external  |     []    |  []  |   []  |       []       |       []       |
|         configured()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    isLoanManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isValidLender(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|   loanManagerList(uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
|    loanManagers(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|        liquidityCap()       |  external  |     []    |  []  |   []  |       []       |       []       |
| delegateManagementFeeRate() |  external  |     []    |  []  |   []  |       []       |       []       |
|        openToPublic()       |  external  |     []    |  []  |   []  |       []       |       []       |
|    pendingPoolDelegate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|            pool()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        poolDelegate()       |  external  |     []    |  []  |   []  |       []       |       []       |
|     poolDelegateCover()     |  external  |     []    |  []  |   []  |       []       |       []       |
|     withdrawalManager()     |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

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

modules/pool-v2/contracts/PoolManager.sol analyzed (26 contracts)
