
+ Contract MapleLoanFeeManager (Most derived contract)
  - From IMapleLoanFeeManager
    - delegateOriginationFee(address) (external)
    - delegateRefinanceServiceFee(address) (external)
    - delegateServiceFee(address) (external)
    - globals() (external)
    - platformRefinanceServiceFee(address) (external)
    - platformServiceFee(address) (external)
  - From MapleLoanFeeManager
    - _getAsset(address) (internal)
    - _getPlatformOriginationFee(address,uint256) (internal)
    - _getPoolDelegate(address) (internal)
    - _getPoolManager(address) (internal)
    - _getTreasury() (internal)
    - _transferTo(address,address,uint256,string) (internal)
    - constructor(address) (public)
    - getDelegateServiceFeesForPeriod(address,uint256) (public)
    - getOriginationFees(address,uint256) (external)
    - getPlatformOriginationFee(address,uint256) (external)
    - getPlatformServiceFeeForPeriod(address,uint256,uint256) (public)
    - getServiceFeeBreakdown(address,uint256) (public)
    - getServiceFees(address,uint256) (external)
    - getServiceFeesForPeriod(address,uint256) (external)
    - payOriginationFees(address,uint256) (external)
    - payServiceFees(address,uint256) (external)
    - updateDelegateFeeTerms(uint256,uint256) (external)
    - updatePlatformServiceFee(uint256,uint256) (external)
    - updateRefinanceServiceFees(uint256,uint256) (external)

+ Contract IMapleLoanFeeManager
  - From IMapleLoanFeeManager
    - delegateOriginationFee(address) (external)
    - delegateRefinanceServiceFee(address) (external)
    - delegateServiceFee(address) (external)
    - getDelegateServiceFeesForPeriod(address,uint256) (external)
    - getOriginationFees(address,uint256) (external)
    - getPlatformOriginationFee(address,uint256) (external)
    - getPlatformServiceFeeForPeriod(address,uint256,uint256) (external)
    - getServiceFeeBreakdown(address,uint256) (external)
    - getServiceFees(address,uint256) (external)
    - getServiceFeesForPeriod(address,uint256) (external)
    - globals() (external)
    - payOriginationFees(address,uint256) (external)
    - payServiceFees(address,uint256) (external)
    - platformRefinanceServiceFee(address) (external)
    - platformServiceFee(address) (external)
    - updateDelegateFeeTerms(uint256,uint256) (external)
    - updatePlatformServiceFee(uint256,uint256) (external)
    - updateRefinanceServiceFees(uint256,uint256) (external)

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

+ Contract ERC20Helper (Most derived contract)
  - From ERC20Helper
    - _call(address,bytes) (private)
    - approve(address,address,uint256) (internal)
    - transfer(address,address,uint256) (internal)
    - transferFrom(address,address,address,uint256) (internal)

+ Contract IERC20Like (Most derived contract)
  - From IERC20Like
    - approve(address,uint256) (external)
    - transfer(address,uint256) (external)
    - transferFrom(address,address,uint256) (external)

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

modules/loan/contracts/MapleLoanFeeManager.sol analyzed (12 contracts)
