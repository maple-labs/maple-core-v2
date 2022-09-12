
TransitionLoanManager:
+-----------------------------------------------+--------------------------------------------------------+------+--------+
|                      Name                     |                          Type                          | Slot | Offset |
+-----------------------------------------------+--------------------------------------------------------+------+--------+
|           LoanManagerStorage._locked          |                        uint256                         |  0   |   0    |
|       LoanManagerStorage.paymentCounter       |                         uint24                         |  1   |   0    |
| LoanManagerStorage.paymentWithEarliestDueDate |                         uint24                         |  1   |   3    |
|         LoanManagerStorage.domainStart        |                         uint48                         |  1   |   6    |
|          LoanManagerStorage.domainEnd         |                         uint48                         |  1   |   12   |
|      LoanManagerStorage.accountedInterest     |                        uint112                         |  1   |   18   |
|        LoanManagerStorage.principalOut        |                        uint128                         |  2   |   0    |
|      LoanManagerStorage.unrealizedLosses      |                        uint128                         |  2   |   16   |
|        LoanManagerStorage.issuanceRate        |                        uint256                         |  3   |   0    |
|         LoanManagerStorage.fundsAsset         |                        address                         |  4   |   0    |
|            LoanManagerStorage.pool            |                        address                         |  5   |   0    |
|         LoanManagerStorage.poolManager        |                        address                         |  6   |   0    |
|         LoanManagerStorage.paymentIdOf        |               mapping(address => uint24)               |  7   |   0    |
|     LoanManagerStorage.allowedSlippageFor     |              mapping(address => uint256)               |  8   |   0    |
|         LoanManagerStorage.minRatioFor        |              mapping(address => uint256)               |  9   |   0    |
|       LoanManagerStorage.liquidationInfo      | mapping(address => LoanManagerStorage.LiquidationInfo) |  10  |   0    |
|          LoanManagerStorage.payments          |   mapping(uint256 => LoanManagerStorage.PaymentInfo)   |  11  |   0    |
|       LoanManagerStorage.sortedPayments       |  mapping(uint256 => LoanManagerStorage.SortedPayment)  |  12  |   0    |
+-----------------------------------------------+--------------------------------------------------------+------+--------+

ILoanManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanManagerInitializerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILiquidatorLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanV3Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILoanLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleLoanFeeManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleProxyFactoryLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolDelegateCoverLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IPoolManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IWithdrawalManagerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleProxyFactory:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

modules/pool-v2/contracts/TransitionLoanManager.sol analyzed (24 contracts)
