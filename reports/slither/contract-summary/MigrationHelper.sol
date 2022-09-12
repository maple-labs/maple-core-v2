
+ Contract MigrationHelper (Most derived contract)
  - From MigrationHelper
    - setPendingLender(address[],address) (external)

+ Contract IDebtLockerLike (Most derived contract)
  - From IDebtLockerLike
    - poolDelegate() (external)
    - setPendingLender(address) (external)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - approve(address,uint256) (external)
    - balanceOf(address) (external)
    - transfer(address,uint256) (external)

+ Contract IGlobalsLike (Most derived contract)
  - From IGlobalsLike
    - platformManagementFeeRate(address) (external)

+ Contract IMapleLoanLike (Most derived contract)
  - From IMapleLoanLike
    - borrower() (external)
    - claimableFunds() (external)
    - closeLoan(uint256) (external)
    - drawableFunds() (external)
    - getClosingPaymentBreakdown() (external)
    - getNextPaymentBreakdown() (external)
    - implementation() (external)
    - lender() (external)
    - makePayment(uint256) (external)
    - nextPaymentDueDate() (external)
    - paymentInterval() (external)
    - pendingLender() (external)
    - principal() (external)
    - upgrade(uint256,bytes) (external)

+ Contract IPoolManagerLike (Most derived contract)
  - From IPoolManagerLike
    - asset() (external)
    - delegateManagementFeeRate() (external)
    - pool() (external)
    - totalAssets() (external)

modules/migration-helpers/contracts/MigrationHelper.sol analyzed (6 contracts)
