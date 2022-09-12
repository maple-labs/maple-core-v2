
Contract MigrationHelper
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
| setPendingLender |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IDebtLockerLike
+------------------+-------------------------+--------------------------+
|     Function     | State variables written | Conditions on msg.sender |
+------------------+-------------------------+--------------------------+
|   poolDelegate   |            []           |            []            |
| setPendingLender |            []           |            []            |
+------------------+-------------------------+--------------------------+

Contract IERC20Like
+-----------+-------------------------+--------------------------+
|  Function | State variables written | Conditions on msg.sender |
+-----------+-------------------------+--------------------------+
|  approve  |            []           |            []            |
| balanceOf |            []           |            []            |
|  transfer |            []           |            []            |
+-----------+-------------------------+--------------------------+

Contract IGlobalsLike
+---------------------------+-------------------------+--------------------------+
|          Function         | State variables written | Conditions on msg.sender |
+---------------------------+-------------------------+--------------------------+
| platformManagementFeeRate |            []           |            []            |
+---------------------------+-------------------------+--------------------------+

Contract IMapleLoanLike
+----------------------------+-------------------------+--------------------------+
|          Function          | State variables written | Conditions on msg.sender |
+----------------------------+-------------------------+--------------------------+
|          borrower          |            []           |            []            |
|       claimableFunds       |            []           |            []            |
|         closeLoan          |            []           |            []            |
|       drawableFunds        |            []           |            []            |
| getClosingPaymentBreakdown |            []           |            []            |
|  getNextPaymentBreakdown   |            []           |            []            |
|       implementation       |            []           |            []            |
|           lender           |            []           |            []            |
|        makePayment         |            []           |            []            |
|     nextPaymentDueDate     |            []           |            []            |
|      paymentInterval       |            []           |            []            |
|       pendingLender        |            []           |            []            |
|         principal          |            []           |            []            |
|          upgrade           |            []           |            []            |
+----------------------------+-------------------------+--------------------------+

Contract IPoolManagerLike
+---------------------------+-------------------------+--------------------------+
|          Function         | State variables written | Conditions on msg.sender |
+---------------------------+-------------------------+--------------------------+
|           asset           |            []           |            []            |
| delegateManagementFeeRate |            []           |            []            |
|            pool           |            []           |            []            |
|        totalAssets        |            []           |            []            |
+---------------------------+-------------------------+--------------------------+

modules/migration-helpers/contracts/MigrationHelper.sol analyzed (6 contracts)
