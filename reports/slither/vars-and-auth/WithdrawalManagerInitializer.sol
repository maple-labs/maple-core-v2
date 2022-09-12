
Contract WithdrawalManagerInitializer
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
|             cycleConfigs            |                    []                   |            []            |
|             exitCycleId             |                    []                   |            []            |
|            latestConfigId           |                    []                   |            []            |
|             lockedShares            |                    []                   |            []            |
|                 pool                |                    []                   |            []            |
|             poolManager             |                    []                   |            []            |
|           totalCycleShares          |                    []                   |            []            |
|               fallback              | ['pool', 'cycleConfigs', 'poolManager'] |            []            |
| slitherConstructorConstantVariables | ['IMPLEMENTATION_SLOT', 'FACTORY_SLOT'] |            []            |
+-------------------------------------+-----------------------------------------+--------------------------+

Contract WithdrawalManagerStorage
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   cycleConfigs   |            []           |            []            |
|   exitCycleId    |            []           |            []            |
|  latestConfigId  |            []           |            []            |
|   lockedShares   |            []           |            []            |
|       pool       |            []           |            []            |
|   poolManager    |            []           |            []            |
| totalCycleShares |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IWithdrawalManagerStorage
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   cycleConfigs   |            []           |            []            |
|   exitCycleId    |            []           |            []            |
|  latestConfigId  |            []           |            []            |
|   lockedShares   |            []           |            []            |
|       pool       |            []           |            []            |
|   poolManager    |            []           |            []            |
| totalCycleShares |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IMapleGlobalsLike
+----------------------+-------------------------+--------------------------+
|       Function       | State variables written | Conditions on msg.sender |
+----------------------+-------------------------+--------------------------+
|       governor       |            []           |            []            |
|    isPoolDeployer    |            []           |            []            |
| isValidScheduledCall |            []           |            []            |
|    unscheduleCall    |            []           |            []            |
+----------------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
| balanceOf |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract IPoolLike
+-----------------+-------------------------+--------------------------+
|     Function    | State variables written | Conditions on msg.sender |
+-----------------+-------------------------+--------------------------+
|      asset      |            []           |            []            |
| convertToShares |            []           |            []            |
|     manager     |            []           |            []            |
|  previewRedeem  |            []           |            []            |
|      redeem     |            []           |            []            |
|   totalSupply   |            []           |            []            |
|     transfer    |            []           |            []            |
+-----------------+-------------------------+--------------------------+

Contract IPoolManagerLike
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   poolDelegate   |            []           |            []            |
|     globals      |            []           |            []            |
|   totalAssets    |            []           |            []            |
| unrealizedLosses |            []           |            []            |
+------------------+-------------------------+--------------------------+

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

modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol analyzed (10 contracts)
