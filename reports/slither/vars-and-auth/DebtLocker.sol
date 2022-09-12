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
+-------------------------------------+-----------------------------------------------------------------------+-----------------------------------------------------------------------------------+
|               Function              |                        State variables written                        |                              Conditions on msg.sender                             |
+-------------------------------------+-----------------------------------------------------------------------+-----------------------------------------------------------------------------------+
|               _migrate              |                                   []                                  |                                         []                                        |
|             _setFactory             |                                   []                                  |                                         []                                        |
|          _setImplementation         |                                   []                                  |                                         []                                        |
|               _factory              |                                   []                                  |                                         []                                        |
|           _implementation           |                                   []                                  |                                         []                                        |
|        _getReferenceTypeSlot        |                                   []                                  |                                         []                                        |
|            _getSlotValue            |                                   []                                  |                                         []                                        |
|            _setSlotValue            |                                   []                                  |                                         []                                        |
|            acceptNewTerms           |                                   []                                  |                                         []                                        |
|                claim                |                                   []                                  |                                         []                                        |
|       pullFundsFromLiquidator       |                                   []                                  |                                         []                                        |
|             poolDelegate            |                                   []                                  |                                         []                                        |
|            triggerDefault           |                                   []                                  |                                         []                                        |
|            rejectNewTerms           |                                   []                                  |                                         []                                        |
|          setAllowedSlippage         |                                   []                                  |                                         []                                        |
|            setAuctioneer            |                                   []                                  |                                         []                                        |
|             setMinRatio             |                                   []                                  |                                         []                                        |
|          getExpectedAmount          |                                   []                                  |                                         []                                        |
|          setFundsToCapture          |                                   []                                  |                                         []                                        |
|           setPendingLender          |                                   []                                  |                                         []                                        |
|           stopLiquidation           |                                   []                                  |                                         []                                        |
|                 loan                |                                   []                                  |                                         []                                        |
|             loanMigrator            |                                   []                                  |                                         []                                        |
|              liquidator             |                                   []                                  |                                         []                                        |
|                 pool                |                                   []                                  |                                         []                                        |
|           allowedSlippage           |                                   []                                  |                                         []                                        |
|           amountRecovered           |                                   []                                  |                                         []                                        |
|               minRatio              |                                   []                                  |                                         []                                        |
|    principalRemainingAtLastClaim    |                                   []                                  |                                         []                                        |
|             repossessed             |                                   []                                  |                                         []                                        |
|            fundsToCapture           |                                   []                                  |                                         []                                        |
|               upgrade               |                                   []                                  |                                         []                                        |
|               factory               |                                   []                                  |                                         []                                        |
|            implementation           |                                   []                                  |                                         []                                        |
|          setImplementation          |                                   []                                  |                                         []                                        |
|               migrate               |                                   []                                  |                                         []                                        |
|               migrate               |                                   []                                  |        ['require(bool,string)(msg.sender == _factory(),DL:M:NOT_FACTORY)']        |
|          setImplementation          |                                   []                                  |        ['require(bool,string)(msg.sender == _factory(),DL:SI:NOT_FACTORY)']       |
|               upgrade               |                                   []                                  | ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:U:NOT_POOL_DELEGATE)'] |
|            acceptNewTerms           |                   ['_principalRemainingAtLastClaim']                  |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:ANT:NOT_PD)']     |
|                claim                | ['_repossessed', '_fundsToCapture', '_principalRemainingAtLastClaim'] |            ['require(bool,string)(msg.sender == _pool,DL:C:NOT_POOL)']            |
|       pullFundsFromLiquidator       |                                   []                                  |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SA:NOT_PD)']      |
|            rejectNewTerms           |                                   []                                  |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:ANT:NOT_PD)']     |
|          setAllowedSlippage         |                          ['_allowedSlippage']                         |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SAS:NOT_PD)']     |
|            setAuctioneer            |                                   []                                  |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SA:NOT_PD)']      |
|          setFundsToCapture          |                          ['_fundsToCapture']                          |     ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SFTC:NOT_PD)']     |
|           setPendingLender          |                                   []                                  |     ['require(bool,string)(msg.sender == _loanMigrator,DL:SPL:NOT_MIGRATOR)']     |
|             setMinRatio             |                             ['_minRatio']                             |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SMR:NOT_PD)']     |
|           stopLiquidation           |                            ['_liquidator']                            |      ['require(bool,string)(msg.sender == _getPoolDelegate(),DL:SL:NOT_PD)']      |
|            triggerDefault           |                    ['_repossessed', '_liquidator']                    |            ['require(bool,string)(msg.sender == _pool,DL:TD:NOT_POOL)']           |
|             _handleClaim            |         ['_fundsToCapture', '_principalRemainingAtLastClaim']         |                                         []                                        |
|      _handleClaimOfRepossessed      |                  ['_repossessed', '_fundsToCapture']                  |                                         []                                        |
|           allowedSlippage           |                                   []                                  |                                         []                                        |
|           amountRecovered           |                                   []                                  |                                         []                                        |
|               factory               |                                   []                                  |                                         []                                        |
|            fundsToCapture           |                                   []                                  |                                         []                                        |
|          getExpectedAmount          |                                   []                                  |                                         []                                        |
|            implementation           |                                   []                                  |                                         []                                        |
|              liquidator             |                                   []                                  |                                         []                                        |
|                 loan                |                                   []                                  |                                         []                                        |
|             loanMigrator            |                                   []                                  |                                         []                                        |
|               minRatio              |                                   []                                  |                                         []                                        |
|                 pool                |                                   []                                  |                                         []                                        |
|             poolDelegate            |                                   []                                  |                                         []                                        |
|    principalRemainingAtLastClaim    |                                   []                                  |                                         []                                        |
|             repossessed             |                                   []                                  |                                         []                                        |
|             _getGlobals             |                                   []                                  |                                         []                                        |
|           _getPoolDelegate          |                                   []                                  |                                         []                                        |
|         _isLiquidationActive        |                                   []                                  |                                         []                                        |
| slitherConstructorConstantVariables |                ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT']                |                                         []                                        |
+-------------------------------------+-----------------------------------------------------------------------+-----------------------------------------------------------------------------------+

Contract DebtLockerStorage
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
+----------+-------------------------+--------------------------+

Contract IDebtLocker
+-------------------------------+-------------------------+--------------------------+
|            Function           | State variables written | Conditions on msg.sender |
+-------------------------------+-------------------------+--------------------------+
|            upgrade            |            []           |            []            |
|            factory            |            []           |            []            |
|         implementation        |            []           |            []            |
|       setImplementation       |            []           |            []            |
|            migrate            |            []           |            []            |
|         acceptNewTerms        |            []           |            []            |
|             claim             |            []           |            []            |
|    pullFundsFromLiquidator    |            []           |            []            |
|          poolDelegate         |            []           |            []            |
|         triggerDefault        |            []           |            []            |
|         rejectNewTerms        |            []           |            []            |
|       setAllowedSlippage      |            []           |            []            |
|         setAuctioneer         |            []           |            []            |
|          setMinRatio          |            []           |            []            |
|       getExpectedAmount       |            []           |            []            |
|       setFundsToCapture       |            []           |            []            |
|        setPendingLender       |            []           |            []            |
|        stopLiquidation        |            []           |            []            |
|              loan             |            []           |            []            |
|          loanMigrator         |            []           |            []            |
|           liquidator          |            []           |            []            |
|              pool             |            []           |            []            |
|        allowedSlippage        |            []           |            []            |
|        amountRecovered        |            []           |            []            |
|            minRatio           |            []           |            []            |
| principalRemainingAtLastClaim |            []           |            []            |
|          repossessed          |            []           |            []            |
|         fundsToCapture        |            []           |            []            |
+-------------------------------+-------------------------+--------------------------+

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
+-------------------------------------+------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               Function              |                              State variables written                               |                                                                                                       Conditions on msg.sender                                                                                                      |
+-------------------------------------+------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|           collateralAsset           |                                         []                                         |                                                                                                                  []                                                                                                                 |
|             destination             |                                         []                                         |                                                                                                                  []                                                                                                                 |
|              auctioneer             |                                         []                                         |                                                                                                                  []                                                                                                                 |
|              fundsAsset             |                                         []                                         |                                                                                                                  []                                                                                                                 |
|               globals               |                                         []                                         |                                                                                                                  []                                                                                                                 |
|                owner                |                                         []                                         |                                                                                                                  []                                                                                                                 |
|            setAuctioneer            |                                         []                                         |                                                                                                                  []                                                                                                                 |
|              pullFunds              |                                         []                                         |                                                                                                                  []                                                                                                                 |
|          getExpectedAmount          |                                         []                                         |                                                                                                                  []                                                                                                                 |
|           liquidatePortion          |                                         []                                         |                                                                                                                  []                                                                                                                 |
|             constructor             | ['auctioneer', 'collateralAsset', 'destination', 'fundsAsset', 'globals', 'owner'] |                                                                                                                  []                                                                                                                 |
|            setAuctioneer            |                                   ['auctioneer']                                   |                                                                                    ['require(bool,string)(msg.sender == owner,LIQ:SA:NOT_OWNER)']                                                                                   |
|              pullFunds              |                                         []                                         |                                                                                    ['require(bool,string)(msg.sender == owner,LIQ:PF:NOT_OWNER)']                                                                                   |
|          getExpectedAmount          |                                         []                                         |                                                                                                                  []                                                                                                                 |
|           liquidatePortion          |                                    ['_locked']                                     | ['require(bool,string)(ERC20Helper.transfer(collateralAsset,msg.sender,collateralAmount_),LIQ:LP:TRANSFER)', 'require(bool,string)(ERC20Helper.transferFrom(fundsAsset,msg.sender,destination,returnAmount),LIQ:LP:TRANSFER_FROM)'] |
| slitherConstructorConstantVariables |                              ['LOCKED', 'NOT_LOCKED']                              |                                                                                                                  []                                                                                                                 |
+-------------------------------------+------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Contract ILiquidator
+-------------------+-------------------------+--------------------------+
|      Function     | State variables written | Conditions on msg.sender |
+-------------------+-------------------------+--------------------------+
|  collateralAsset  |            []           |            []            |
|    destination    |            []           |            []            |
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

modules/debt-locker-v4/contracts/DebtLocker.sol analyzed (29 contracts)
