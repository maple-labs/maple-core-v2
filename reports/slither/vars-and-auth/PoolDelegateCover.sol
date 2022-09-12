
Contract PoolDelegateCover
+-------------+--------------------------+------------------------------------------------------------------------+
|   Function  | State variables written  |                        Conditions on msg.sender                        |
+-------------+--------------------------+------------------------------------------------------------------------+
|    asset    |            []            |                                   []                                   |
| poolManager |            []            |                                   []                                   |
|  moveFunds  |            []            |                                   []                                   |
| constructor | ['asset', 'poolManager'] |                                   []                                   |
|  moveFunds  |            []            | ['require(bool,string)(msg.sender == poolManager,PDC:MF:NOT_MANAGER)'] |
+-------------+--------------------------+------------------------------------------------------------------------+

Contract IPoolDelegateCover
+-------------+-------------------------+--------------------------+
|   Function  | State variables written | Conditions on msg.sender |
+-------------+-------------------------+--------------------------+
|    asset    |            []           |            []            |
| poolManager |            []           |            []            |
|  moveFunds  |            []           |            []            |
+-------------+-------------------------+--------------------------+

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

modules/pool-v2/contracts/PoolDelegateCover.sol analyzed (4 contracts)
