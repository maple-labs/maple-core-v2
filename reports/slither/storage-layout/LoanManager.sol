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

LoanManager:
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

ERC20Helper:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

Liquidator:
+----------------------------+---------+------+--------+
|            Name            |   Type  | Slot | Offset |
+----------------------------+---------+------+--------+
|     Liquidator._locked     | uint256 |  0   |   0    |
| Liquidator.collateralAsset | address |  1   |   0    |
|   Liquidator.fundsAsset    | address |  2   |   0    |
|     Liquidator.globals     | address |  3   |   0    |
|      Liquidator.owner      | address |  4   |   0    |
|   Liquidator.auctioneer    | address |  5   |   0    |
+----------------------------+---------+------+--------+

IAuctioneerLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILiquidatorLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IOracleLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IUniswapRouterLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

Vm:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

console:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

Address:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

TestUtils:
+----------------+------+------+--------+
|      Name      | Type | Slot | Offset |
+----------------+------+------+--------+
| DSTest.IS_TEST | bool |  0   |   0    |
| DSTest.failed  | bool |  0   |   1    |
|  TestUtils.vm  |  Vm  |  0   |   2    |
+----------------+------+------+--------+

InvariantTest:
+----------------------------------+-----------+------+--------+
|               Name               |    Type   | Slot | Offset |
+----------------------------------+-----------+------+--------+
| InvariantTest._excludedContracts | address[] |  0   |   0    |
|  InvariantTest._targetContracts  | address[] |  1   |   0    |
+----------------------------------+-----------+------+--------+

ERC20Helper:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IERC20Like:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleProxyFactory:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

modules/pool-v2/contracts/LoanManager.sol analyzed (43 contracts)
