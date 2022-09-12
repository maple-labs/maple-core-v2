
+ Contract MapleLoanStorage

+ Contract MapleLoanV4Migrator (Most derived contract)
  - From MapleLoanV4Migrator
    - decodeArguments(bytes) (public)
    - encodeArguments(address) (external)
    - fallback() (external)

+ Contract IMapleLoanV4Migrator
  - From IMapleLoanV4Migrator
    - decodeArguments(bytes) (external)
    - encodeArguments(address) (external)

+ Contract IGlobalsLike (Most derived contract)
  - From IGlobalsLike
    - governor() (external)
    - isBorrower(address) (external)
    - isFactory(bytes32,address) (external)
    - mapleTreasury() (external)
    - platformOriginationFeeRate(address) (external)
    - platformServiceFeeRate(address) (external)

+ Contract ILenderLike (Most derived contract)
  - From ILenderLike
    - claim(uint256,uint256,uint256,uint256) (external)

+ Contract ILoanLike (Most derived contract)
  - From ILoanLike
    - factory() (external)
    - fundsAsset() (external)
    - lender() (external)
    - paymentInterval() (external)
    - paymentsRemaining() (external)
    - principal() (external)
    - principalRequested() (external)

+ Contract ILoanManagerLike (Most derived contract)
  - From ILoanManagerLike
    - owner() (external)
    - poolManager() (external)

+ Contract IMapleFeeManagerLike (Most derived contract)
  - From IMapleFeeManagerLike
    - updateDelegateFeeTerms(uint256,uint256) (external)
    - updatePlatformServiceFee(uint256,uint256) (external)

+ Contract IMapleProxyFactoryLike (Upgradeable Proxy) (Most derived contract)
  - From IMapleProxyFactoryLike
    - mapleGlobals() (external)

+ Contract IPoolManagerLike (Most derived contract)
  - From IPoolManagerLike
    - poolDelegate() (external)

+ Contract IERC20 (Most derived contract)
  - From IERC20
    - DOMAIN_SEPARATOR() (external)
    - PERMIT_TYPEHASH() (external)
    - allowance(address,address) (external)
    - approve(address,uint256) (external)
    - balanceOf(address) (external)
    - decimals() (external)
    - decreaseAllowance(address,uint256) (external)
    - increaseAllowance(address,uint256) (external)
    - name() (external)
    - nonces(address) (external)
    - permit(address,address,uint256,uint256,uint8,bytes32,bytes32) (external)
    - symbol() (external)
    - totalSupply() (external)
    - transfer(address,uint256) (external)
    - transferFrom(address,address,uint256) (external)

modules/loan/contracts/MapleLoanV4Migrator.sol analyzed (11 contracts)
