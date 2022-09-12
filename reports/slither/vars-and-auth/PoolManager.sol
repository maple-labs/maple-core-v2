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
+-------------------------------------+----------------------------------------------------------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               Function              |                                               State variables written                                                |                                                                                                                        Conditions on msg.sender                                                                                                                        |
+-------------------------------------+----------------------------------------------------------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                active               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|                asset                |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              configured             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            isLoanManager            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            isValidLender            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           loanManagerList           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             loanManagers            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             liquidityCap            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|      delegateManagementFeeRate      |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             openToPublic            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         pendingPoolDelegate         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|                 pool                |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             poolDelegate            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          poolDelegateCover          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          withdrawalManager          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               _migrate              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             _setFactory             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          _setImplementation         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               _factory              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           _implementation           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|        _getReferenceTypeSlot        |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            _getSlotValue            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            _setSlotValue            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|      acceptPendingPoolDelegate      |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|        setPendingPoolDelegate       |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              configure              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            addLoanManager           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          removeLoanManager          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              setActive              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           setAllowedLender          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           setLiquidityCap           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|     setDelegateManagementFeeRate    |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           setOpenToPublic           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         setWithdrawalManager        |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            acceptNewTerms           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|                 fund                |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|     finishCollateralLiquidation     |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         removeDefaultWarning        |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            triggerDefault           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|        triggerDefaultWarning        |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            processRedeem            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             removeShares            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            requestRedeem            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             depositCover            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            withdrawCover            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           getEscrowParams           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         convertToExitShares         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              maxDeposit             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               maxMint               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              maxRedeem              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             maxWithdraw             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            previewRedeem            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           previewWithdraw           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               canCall               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               globals               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               governor              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          hasSufficientCover         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             totalAssets             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           unrealizedLosses          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               upgrade               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               factory               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            implementation           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          setImplementation          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               migrate               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               migrate               |                                                          []                                                          |                                                                                                  ['require(bool,string)(msg.sender == _factory(),PM:M:NOT_FACTORY)']                                                                                                   |
|          setImplementation          |                                                          []                                                          |                                                                                                  ['require(bool,string)(msg.sender == _factory(),PM:SI:NOT_FACTORY)']                                                                                                  |
|               upgrade               |                                                          []                                                          | ['require(bool,string)(msg.sender == poolDelegate_ || msg.sender == governor(),PM:U:NOT_AUTHORIZED)', 'msg.sender == poolDelegate_', 'require(bool,string)(mapleGlobals_.isValidScheduledCall(msg.sender,address(this),PM:UPGRADE,msg.data),PM:U:INVALID_SCHED_CALL)'] |
|      acceptPendingPoolDelegate      |                                       ['pendingPoolDelegate', 'poolDelegate']                                        |                                                                                           ['require(bool,string)(msg.sender == pendingPoolDelegate,PM:APPD:NOT_PENDING_PD)']                                                                                           |
|        setPendingPoolDelegate       |                                               ['pendingPoolDelegate']                                                |                                                                                                  ['require(bool,string)(msg.sender == poolDelegate_,PM:SPA:NOT_PD)']                                                                                                   |
|            addLoanManager           |                                         ['loanManagerList', 'isLoanManager']                                         |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:ALM:NOT_PD)']                                                                                                   |
|              configure              | ['isLoanManager', 'configured', 'loanManagerList', 'liquidityCap', 'delegateManagementFeeRate', 'withdrawalManager'] |                                                                                  ['require(bool,string)(IMapleGlobalsLike(globals()).isPoolDeployer(msg.sender),PM:CO:NOT_DEPLOYER)']                                                                                  |
|          removeLoanManager          |                                         ['loanManagerList', 'isLoanManager']                                         |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:RLM:NOT_PD)']                                                                                                   |
|              setActive              |                                                      ['active']                                                      |                                                                                                  ['require(bool,string)(msg.sender == globals(),PM:SA:NOT_GLOBALS)']                                                                                                   |
|           setAllowedLender          |                                                  ['isValidLender']                                                   |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:SAL:NOT_PD)']                                                                                                   |
|     setDelegateManagementFeeRate    |                                            ['delegateManagementFeeRate']                                             |                                                                                                  ['require(bool,string)(msg.sender == poolDelegate,PM:SDMFR:NOT_PD)']                                                                                                  |
|           setLiquidityCap           |                                                   ['liquidityCap']                                                   |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:SLC:NOT_PD)']                                                                                                   |
|           setOpenToPublic           |                                                   ['openToPublic']                                                   |                                                                                                  ['require(bool,string)(msg.sender == poolDelegate,PM:SOTP:NOT_PD)']                                                                                                   |
|         setWithdrawalManager        |                                                ['withdrawalManager']                                                 |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:SWM:NOT_PD)']                                                                                                   |
|            acceptNewTerms           |                                                     ['_locked']                                                      |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:ANT:NOT_PD)']                                                                                                   |
|                 fund                |                                             ['_locked', 'loanManagers']                                              |                                                                                                    ['require(bool,string)(msg.sender == poolDelegate,PM:F:NOT_PD)']                                                                                                    |
|     finishCollateralLiquidation     |                                                     ['_locked']                                                      |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:FCL:NOT_PD)']                                                                                                   |
|         removeDefaultWarning        |                                                     ['_locked']                                                      |                                                                                       ['require(bool,string)(msg.sender == poolDelegate || isGovernor_,PM:RDW:NOT_AUTHORIZED)']                                                                                        |
|            triggerDefault           |                                                     ['_locked']                                                      |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:TCL:NOT_PD)']                                                                                                   |
|        triggerDefaultWarning        |                                                          []                                                          |                                                                                       ['require(bool,string)(msg.sender == poolDelegate || isGovernor_,PM:TDW:NOT_AUTHORIZED)']                                                                                        |
|            processRedeem            |                                                     ['_locked']                                                      |                                                                                                      ['require(bool,string)(msg.sender == pool,PM:PR:NOT_POOL)']                                                                                                       |
|             removeShares            |                                                     ['_locked']                                                      |                                                                                                      ['require(bool,string)(msg.sender == pool,PM:RS:NOT_POOL)']                                                                                                       |
|            requestRedeem            |                                                     ['_locked']                                                      |                                                                                                      ['require(bool,string)(msg.sender == pool_,PM:RR:NOT_POOL)']                                                                                                      |
|             depositCover            |                                                          []                                                          |                                                                           ['require(bool,string)(ERC20Helper.transferFrom(asset,msg.sender,poolDelegateCover,amount_),PM:DC:TRANSFER_FAIL)']                                                                           |
|            withdrawCover            |                                                          []                                                          |                                                                                                   ['require(bool,string)(msg.sender == poolDelegate,PM:WC:NOT_PD)']                                                                                                    |
|             _handleCover            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               canCall               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               factory               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               globals               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               governor              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|          hasSufficientCover         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            implementation           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             totalAssets             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         convertToExitShares         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           getEscrowParams           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              maxDeposit             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|               maxMint               |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|              maxRedeem              |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             maxWithdraw             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            previewRedeem            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           previewWithdraw           |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|           unrealizedLosses          |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             _canDeposit             |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|             _canTransfer            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         _formatErrorMessage         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|            _getMaxAssets            |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|         _hasSufficientCover         |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
|                 _min                |                                                          []                                                          |                                                                                                                                   []                                                                                                                                   |
| slitherConstructorConstantVariables |                              ['HUNDRED_PERCENT', 'IMPLEMENTATION_SLOT', 'FACTORY_SLOT']                              |                                                                                                                                   []                                                                                                                                   |
+-------------------------------------+----------------------------------------------------------------------------------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Contract IPoolManager
+------------------------------+-------------------------+--------------------------+
|           Function           | State variables written | Conditions on msg.sender |
+------------------------------+-------------------------+--------------------------+
|            active            |            []           |            []            |
|            asset             |            []           |            []            |
|          configured          |            []           |            []            |
|        isLoanManager         |            []           |            []            |
|        isValidLender         |            []           |            []            |
|       loanManagerList        |            []           |            []            |
|         loanManagers         |            []           |            []            |
|         liquidityCap         |            []           |            []            |
|  delegateManagementFeeRate   |            []           |            []            |
|         openToPublic         |            []           |            []            |
|     pendingPoolDelegate      |            []           |            []            |
|             pool             |            []           |            []            |
|         poolDelegate         |            []           |            []            |
|      poolDelegateCover       |            []           |            []            |
|      withdrawalManager       |            []           |            []            |
|           upgrade            |            []           |            []            |
|           factory            |            []           |            []            |
|        implementation        |            []           |            []            |
|      setImplementation       |            []           |            []            |
|           migrate            |            []           |            []            |
|  acceptPendingPoolDelegate   |            []           |            []            |
|    setPendingPoolDelegate    |            []           |            []            |
|          configure           |            []           |            []            |
|        addLoanManager        |            []           |            []            |
|      removeLoanManager       |            []           |            []            |
|          setActive           |            []           |            []            |
|       setAllowedLender       |            []           |            []            |
|       setLiquidityCap        |            []           |            []            |
| setDelegateManagementFeeRate |            []           |            []            |
|       setOpenToPublic        |            []           |            []            |
|     setWithdrawalManager     |            []           |            []            |
|        acceptNewTerms        |            []           |            []            |
|             fund             |            []           |            []            |
| finishCollateralLiquidation  |            []           |            []            |
|     removeDefaultWarning     |            []           |            []            |
|        triggerDefault        |            []           |            []            |
|    triggerDefaultWarning     |            []           |            []            |
|        processRedeem         |            []           |            []            |
|         removeShares         |            []           |            []            |
|        requestRedeem         |            []           |            []            |
|         depositCover         |            []           |            []            |
|        withdrawCover         |            []           |            []            |
|       getEscrowParams        |            []           |            []            |
|     convertToExitShares      |            []           |            []            |
|          maxDeposit          |            []           |            []            |
|           maxMint            |            []           |            []            |
|          maxRedeem           |            []           |            []            |
|         maxWithdraw          |            []           |            []            |
|        previewRedeem         |            []           |            []            |
|       previewWithdraw        |            []           |            []            |
|           canCall            |            []           |            []            |
|           globals            |            []           |            []            |
|           governor           |            []           |            []            |
|      hasSufficientCover      |            []           |            []            |
|         totalAssets          |            []           |            []            |
|       unrealizedLosses       |            []           |            []            |
+------------------------------+-------------------------+--------------------------+

Contract IPoolManagerStorage
+---------------------------+-------------------------+--------------------------+
|          Function         | State variables written | Conditions on msg.sender |
+---------------------------+-------------------------+--------------------------+
|           active          |            []           |            []            |
|           asset           |            []           |            []            |
|         configured        |            []           |            []            |
|       isLoanManager       |            []           |            []            |
|       isValidLender       |            []           |            []            |
|      loanManagerList      |            []           |            []            |
|        loanManagers       |            []           |            []            |
|        liquidityCap       |            []           |            []            |
| delegateManagementFeeRate |            []           |            []            |
|        openToPublic       |            []           |            []            |
|    pendingPoolDelegate    |            []           |            []            |
|            pool           |            []           |            []            |
|        poolDelegate       |            []           |            []            |
|     poolDelegateCover     |            []           |            []            |
|     withdrawalManager     |            []           |            []            |
+---------------------------+-------------------------+--------------------------+

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

Contract PoolManagerStorage
+---------------------------+-------------------------+--------------------------+
|          Function         | State variables written | Conditions on msg.sender |
+---------------------------+-------------------------+--------------------------+
|           active          |            []           |            []            |
|           asset           |            []           |            []            |
|         configured        |            []           |            []            |
|       isLoanManager       |            []           |            []            |
|       isValidLender       |            []           |            []            |
|      loanManagerList      |            []           |            []            |
|        loanManagers       |            []           |            []            |
|        liquidityCap       |            []           |            []            |
| delegateManagementFeeRate |            []           |            []            |
|        openToPublic       |            []           |            []            |
|    pendingPoolDelegate    |            []           |            []            |
|            pool           |            []           |            []            |
|        poolDelegate       |            []           |            []            |
|     poolDelegateCover     |            []           |            []            |
|     withdrawalManager     |            []           |            []            |
+---------------------------+-------------------------+--------------------------+

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

modules/pool-v2/contracts/PoolManager.sol analyzed (26 contracts)
