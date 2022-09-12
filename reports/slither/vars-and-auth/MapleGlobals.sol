
Contract MapleGlobals
+-------------------------------------+----------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
|               Function              |                 State variables written                  |                                                    Conditions on msg.sender                                                    |
+-------------------------------------+----------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
|                admin                |                            []                            |                                                               []                                                               |
|            implementation           |                            []                            |                                                               []                                                               |
|             _getAddress             |                            []                            |                                                               []                                                               |
|                admin                |                            []                            |                                                               []                                                               |
|            implementation           |                            []                            |                                                               []                                                               |
|      defaultTimelockParameters      |                            []                            |                                                               []                                                               |
|              isBorrower             |                            []                            |                                                               []                                                               |
|              isFactory              |                            []                            |                                                               []                                                               |
|             isPoolAsset             |                            []                            |                                                               []                                                               |
|            isPoolDelegate           |                            []                            |                                                               []                                                               |
|            isPoolDeployer           |                            []                            |                                                               []                                                               |
|            getLatestPrice           |                            []                            |                                                               []                                                               |
|               governor              |                            []                            |                                                               []                                                               |
|         manualOverridePrice         |                            []                            |                                                               []                                                               |
|            mapleTreasury            |                            []                            |                                                               []                                                               |
|      maxCoverLiquidationPercent     |                            []                            |                                                               []                                                               |
|            migrationAdmin           |                            []                            |                                                               []                                                               |
|            minCoverAmount           |                            []                            |                                                               []                                                               |
|              oracleFor              |                            []                            |                                                               []                                                               |
|           ownedPoolManager          |                            []                            |                                                               []                                                               |
|           pendingGovernor           |                            []                            |                                                               []                                                               |
|      platformManagementFeeRate      |                            []                            |                                                               []                                                               |
|      platformOriginationFeeRate     |                            []                            |                                                               []                                                               |
|        platformServiceFeeRate       |                            []                            |                                                               []                                                               |
|            poolDelegates            |                            []                            |                                                               []                                                               |
|            protocolPaused           |                            []                            |                                                               []                                                               |
|            scheduledCalls           |                            []                            |                                                               []                                                               |
|            securityAdmin            |                            []                            |                                                               []                                                               |
|         timelockParametersOf        |                            []                            |                                                               []                                                               |
|         activatePoolManager         |                            []                            |                                                               []                                                               |
|           setMapleTreasury          |                            []                            |                                                               []                                                               |
|          setMigrationAdmin          |                            []                            |                                                               []                                                               |
|            setPriceOracle           |                            []                            |                                                               []                                                               |
|           setSecurityAdmin          |                            []                            |                                                               []                                                               |
|     setDefaultTimelockParameters    |                            []                            |                                                               []                                                               |
|           setProtocolPause          |                            []                            |                                                               []                                                               |
|           setValidBorrower          |                            []                            |                                                               []                                                               |
|           setValidFactory           |                            []                            |                                                               []                                                               |
|          setValidPoolAsset          |                            []                            |                                                               []                                                               |
|         setValidPoolDelegate        |                            []                            |                                                               []                                                               |
|         setValidPoolDeployer        |                            []                            |                                                               []                                                               |
|        setManualOverridePrice       |                            []                            |                                                               []                                                               |
|    setMaxCoverLiquidationPercent    |                            []                            |                                                               []                                                               |
|          setMinCoverAmount          |                            []                            |                                                               []                                                               |
|     setPlatformManagementFeeRate    |                            []                            |                                                               []                                                               |
|    setPlatformOriginationFeeRate    |                            []                            |                                                               []                                                               |
|      setPlatformServiceFeeRate      |                            []                            |                                                               []                                                               |
|          setTimelockWindow          |                            []                            |                                                               []                                                               |
|          setTimelockWindows         |                            []                            |                                                               []                                                               |
|       transferOwnedPoolManager      |                            []                            |                                                               []                                                               |
|             scheduleCall            |                            []                            |                                                               []                                                               |
|            unscheduleCall           |                            []                            |                                                               []                                                               |
|            unscheduleCall           |                            []                            |                                                               []                                                               |
|         isValidScheduledCall        |                            []                            |                                                               []                                                               |
|             constructor             |              ['defaultTimelockParameters']               |                                                               []                                                               |
|            acceptGovernor           |                   ['pendingGovernor']                    |                        ['require(bool,string)(msg.sender == pendingGovernor,MG:NOT_PENDING_GOVERNOR)']                         |
|          setPendingGovernor         |                   ['pendingGovernor']                    | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|         activatePoolManager         |                    ['poolDelegates']                     | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|           setMapleTreasury          |                    ['mapleTreasury']                     | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|          setMigrationAdmin          |                    ['migrationAdmin']                    | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|            setPriceOracle           |                      ['oracleFor']                       | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|           setSecurityAdmin          |                    ['securityAdmin']                     | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|     setDefaultTimelockParameters    |              ['defaultTimelockParameters']               | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|           setProtocolPause          |                    ['protocolPaused']                    |                        ['require(bool,string)(msg.sender == securityAdmin,MG:SPP:NOT_SECURITY_ADMIN)']                         |
|           setValidBorrower          |                      ['isBorrower']                      | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|           setValidFactory           |                      ['isFactory']                       | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|          setValidPoolAsset          |                     ['isPoolAsset']                      | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|         setValidPoolDelegate        |                    ['poolDelegates']                     | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|         setValidPoolDeployer        |                    ['isPoolDeployer']                    | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|        setManualOverridePrice       |                 ['manualOverridePrice']                  | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|          setMinCoverAmount          |                    ['minCoverAmount']                    | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|    setMaxCoverLiquidationPercent    |              ['maxCoverLiquidationPercent']              | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|     setPlatformManagementFeeRate    |              ['platformManagementFeeRate']               | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|    setPlatformOriginationFeeRate    |              ['platformOriginationFeeRate']              | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|      setPlatformServiceFeeRate      |                ['platformServiceFeeRate']                | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|          setTimelockWindow          |                 ['timelockParametersOf']                 | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|          setTimelockWindows         |                 ['timelockParametersOf']                 | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|       transferOwnedPoolManager      |                    ['poolDelegates']                     |                 ['require(bool,string)(fromDelegate_.ownedPoolManager == msg.sender,MG:TOPM:NOT_AUTHORIZED)']                  |
|             scheduleCall            |                    ['scheduledCalls']                    |                                                               []                                                               |
|            unscheduleCall           |                    ['scheduledCalls']                    |                                                               []                                                               |
|            unscheduleCall           |                    ['scheduledCalls']                    | ['require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)', 'require(bool,string)(msg.sender == admin(),MG:NOT_GOVERNOR)'] |
|         isValidScheduledCall        |                            []                            |                                                               []                                                               |
|            getLatestPrice           |                            []                            |                                                               []                                                               |
|               governor              |                            []                            |                                                               []                                                               |
|            isPoolDelegate           |                            []                            |                                                               []                                                               |
|           ownedPoolManager          |                            []                            |                                                               []                                                               |
|             _setAddress             |                            []                            |                                                               []                                                               |
| slitherConstructorConstantVariables | ['HUNDRED_PERCENT', 'IMPLEMENTATION_SLOT', 'ADMIN_SLOT'] |                                                               []                                                               |
+-------------------------------------+----------------------------------------------------------+--------------------------------------------------------------------------------------------------------------------------------+

Contract IMapleGlobals
+-------------------------------+-------------------------+--------------------------+
|            Function           | State variables written | Conditions on msg.sender |
+-------------------------------+-------------------------+--------------------------+
|   defaultTimelockParameters   |            []           |            []            |
|           isBorrower          |            []           |            []            |
|           isFactory           |            []           |            []            |
|          isPoolAsset          |            []           |            []            |
|         isPoolDelegate        |            []           |            []            |
|         isPoolDeployer        |            []           |            []            |
|         getLatestPrice        |            []           |            []            |
|            governor           |            []           |            []            |
|      manualOverridePrice      |            []           |            []            |
|         mapleTreasury         |            []           |            []            |
|   maxCoverLiquidationPercent  |            []           |            []            |
|         migrationAdmin        |            []           |            []            |
|         minCoverAmount        |            []           |            []            |
|           oracleFor           |            []           |            []            |
|        ownedPoolManager       |            []           |            []            |
|        pendingGovernor        |            []           |            []            |
|   platformManagementFeeRate   |            []           |            []            |
|   platformOriginationFeeRate  |            []           |            []            |
|     platformServiceFeeRate    |            []           |            []            |
|         poolDelegates         |            []           |            []            |
|         protocolPaused        |            []           |            []            |
|         scheduledCalls        |            []           |            []            |
|         securityAdmin         |            []           |            []            |
|      timelockParametersOf     |            []           |            []            |
|      activatePoolManager      |            []           |            []            |
|        setMapleTreasury       |            []           |            []            |
|       setMigrationAdmin       |            []           |            []            |
|         setPriceOracle        |            []           |            []            |
|        setSecurityAdmin       |            []           |            []            |
|  setDefaultTimelockParameters |            []           |            []            |
|        setProtocolPause       |            []           |            []            |
|        setValidBorrower       |            []           |            []            |
|        setValidFactory        |            []           |            []            |
|       setValidPoolAsset       |            []           |            []            |
|      setValidPoolDelegate     |            []           |            []            |
|      setValidPoolDeployer     |            []           |            []            |
|     setManualOverridePrice    |            []           |            []            |
| setMaxCoverLiquidationPercent |            []           |            []            |
|       setMinCoverAmount       |            []           |            []            |
|  setPlatformManagementFeeRate |            []           |            []            |
| setPlatformOriginationFeeRate |            []           |            []            |
|   setPlatformServiceFeeRate   |            []           |            []            |
|       setTimelockWindow       |            []           |            []            |
|       setTimelockWindows      |            []           |            []            |
|    transferOwnedPoolManager   |            []           |            []            |
|          scheduleCall         |            []           |            []            |
|         unscheduleCall        |            []           |            []            |
|         unscheduleCall        |            []           |            []            |
|      isValidScheduledCall     |            []           |            []            |
+-------------------------------+-------------------------+--------------------------+

Contract IChainlinkAggregatorV3Like
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
| latestRoundData |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract IPoolLike
+----------+-------------------------+--------------------------+
| Function | State variables written | Conditions on msg.sender |
+----------+-------------------------+--------------------------+
| manager  |            []           |            []            |
+----------+-------------------------+--------------------------+

Contract IPoolManagerLike
+--------------+-------------------------+--------------------------+
|   Function   | State variables written | Conditions on msg.sender |
+--------------+-------------------------+--------------------------+
| poolDelegate |            []           |            []            |
|  setActive   |            []           |            []            |
+--------------+-------------------------+--------------------------+

Contract NonTransparentProxied
+-------------------------------------+---------------------------------------+--------------------------+
|               Function              |        State variables written        | Conditions on msg.sender |
+-------------------------------------+---------------------------------------+--------------------------+
|                admin                |                   []                  |            []            |
|            implementation           |                   []                  |            []            |
|                admin                |                   []                  |            []            |
|            implementation           |                   []                  |            []            |
|             _getAddress             |                   []                  |            []            |
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'ADMIN_SLOT'] |            []            |
+-------------------------------------+---------------------------------------+--------------------------+

Contract INonTransparentProxied
+----------------+-------------------------+--------------------------+
|    Function    | State variables written | Conditions on msg.sender |
+----------------+-------------------------+--------------------------+
|     admin      |            []           |            []            |
| implementation |            []           |            []            |
+----------------+-------------------------+--------------------------+

modules/globals-v2/contracts/MapleGlobals.sol analyzed (7 contracts)
