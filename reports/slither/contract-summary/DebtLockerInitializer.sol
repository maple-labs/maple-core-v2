
+ Contract DebtLockerInitializer (Most derived contract)
  - From DebtLockerInitializer
    - decodeArguments(bytes) (public)
    - encodeArguments(address,address) (external)
    - fallback() (external)

+ Contract DebtLockerStorage

+ Contract IDebtLockerInitializer
  - From IDebtLockerInitializer
    - decodeArguments(bytes) (external)
    - encodeArguments(address,address) (external)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - balanceOf(address) (external)
    - decimals() (external)

+ Contract ILiquidatorLike (Most derived contract)
  - From ILiquidatorLike
    - auctioneer() (external)

+ Contract IMapleGlobalsLike (Most derived contract)
  - From IMapleGlobalsLike
    - defaultUniswapPath(address,address) (external)
    - getLatestPrice(address) (external)
    - investorFee() (external)
    - isValidCollateralAsset(address) (external)
    - isValidLiquidityAsset(address) (external)
    - mapleTreasury() (external)
    - protocolPaused() (external)
    - treasuryFee() (external)

+ Contract IMapleLoanLike (Most derived contract)
  - From IMapleLoanLike
    - acceptNewTerms(address,uint256,bytes[],uint256) (external)
    - claimFunds(uint256,address) (external)
    - claimableFunds() (external)
    - collateralAsset() (external)
    - fundsAsset() (external)
    - lender() (external)
    - principal() (external)
    - principalRequested() (external)
    - refinanceCommitment() (external)
    - rejectNewTerms(address,uint256,bytes[]) (external)
    - repossess(address) (external)
    - setPendingLender(address) (external)

+ Contract IPoolLike (Most derived contract)
  - From IPoolLike
    - poolDelegate() (external)
    - superFactory() (external)

+ Contract IPoolFactoryLike (Most derived contract)
  - From IPoolFactoryLike
    - globals() (external)

+ Contract IUniswapRouterLike (Most derived contract)
  - From IUniswapRouterLike
    - swapExactTokensForTokens(uint256,uint256,address[],address,uint256) (external)

modules/debt-locker-v4/contracts/DebtLockerInitializer.sol analyzed (10 contracts)
