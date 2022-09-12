
+ Contract PoolDelegateCover (Most derived contract)
  - From IPoolDelegateCover
    - asset() (external)
    - poolManager() (external)
  - From PoolDelegateCover
    - constructor(address,address) (public)
    - moveFunds(uint256,address) (external)

+ Contract IPoolDelegateCover
  - From IPoolDelegateCover
    - asset() (external)
    - moveFunds(uint256,address) (external)
    - poolManager() (external)

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

modules/pool-v2/contracts/PoolDelegateCover.sol analyzed (4 contracts)
