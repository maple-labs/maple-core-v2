Compilation warnings/errors on modules/loan-v301/contracts/MapleLoan.sol:
Warning: Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon). This contract may not be deployable on mainnet. Consider enabling the optimizer (with a low "runs" value!), turning off revert strings, or using libraries.
  --> modules/loan-v301/contracts/MapleLoan.sol:14:1:
   |
14 | contract MapleLoan is IMapleLoan, MapleLoanInternals {
   | ^ (Relevant source part starts here and spans across multiple lines).



MapleLoan:
+-----------------------------------------+---------+------+--------+
|                   Name                  |   Type  | Slot | Offset |
+-----------------------------------------+---------+------+--------+
|       MapleLoanInternals._borrower      | address |  0   |   0    |
|        MapleLoanInternals._lender       | address |  1   |   0    |
|   MapleLoanInternals._pendingBorrower   | address |  2   |   0    |
|    MapleLoanInternals._pendingLender    | address |  3   |   0    |
|   MapleLoanInternals._collateralAsset   | address |  4   |   0    |
|      MapleLoanInternals._fundsAsset     | address |  5   |   0    |
|     MapleLoanInternals._gracePeriod     | uint256 |  6   |   0    |
|   MapleLoanInternals._paymentInterval   | uint256 |  7   |   0    |
|     MapleLoanInternals._interestRate    | uint256 |  8   |   0    |
|     MapleLoanInternals._earlyFeeRate    | uint256 |  9   |   0    |
|     MapleLoanInternals._lateFeeRate     | uint256 |  10  |   0    |
| MapleLoanInternals._lateInterestPremium | uint256 |  11  |   0    |
|  MapleLoanInternals._collateralRequired | uint256 |  12  |   0    |
|  MapleLoanInternals._principalRequested | uint256 |  13  |   0    |
|   MapleLoanInternals._endingPrincipal   | uint256 |  14  |   0    |
|    MapleLoanInternals._drawableFunds    | uint256 |  15  |   0    |
|    MapleLoanInternals._claimableFunds   | uint256 |  16  |   0    |
|      MapleLoanInternals._collateral     | uint256 |  17  |   0    |
|  MapleLoanInternals._nextPaymentDueDate | uint256 |  18  |   0    |
|  MapleLoanInternals._paymentsRemaining  | uint256 |  19  |   0    |
|      MapleLoanInternals._principal      | uint256 |  20  |   0    |
| MapleLoanInternals._refinanceCommitment | bytes32 |  21  |   0    |
|  MapleLoanInternals._refinanceInterest  | uint256 |  22  |   0    |
|     MapleLoanInternals._delegateFee     | uint256 |  23  |   0    |
|     MapleLoanInternals._treasuryFee     | uint256 |  24  |   0    |
+-----------------------------------------+---------+------+--------+

IMapleLoanFactory:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

ILenderLike:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

IMapleGlobalsLike:
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

IERC20:
+------+------+------+--------+
| Name | Type | Slot | Offset |
+------+------+------+--------+
+------+------+------+--------+

modules/loan-v301/contracts/MapleLoan.sol analyzed (17 contracts)
