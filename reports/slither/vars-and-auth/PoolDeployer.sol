
Contract PoolDeployer
+-------------+-------------------------+--------------------------+
|   Function  | State variables written | Conditions on msg.sender |
+-------------+-------------------------+--------------------------+
|   globals   |            []           |            []            |
|  deployPool |            []           |            []            |
| constructor |       ['globals']       |            []            |
|  deployPool |            []           |            []            |
+-------------+-------------------------+--------------------------+

Contract IPoolDeployer
+------------+-------------------------+--------------------------+
|  Function  | State variables written | Conditions on msg.sender |
+------------+-------------------------+--------------------------+
|  globals   |            []           |            []            |
| deployPool |            []           |            []            |
+------------+-------------------------+--------------------------+

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

Contract IPoolManagerInitializer
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| decodeArguments |            []           |            []            |
| encodeArguments |            []           |            []            |
+-----------------+-------------------------+--------------------------+

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

modules/pool-v2/contracts/PoolDeployer.sol analyzed (24 contracts)
