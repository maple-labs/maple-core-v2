
Contract PoolDelegateCover
Contract vars: ['asset', 'poolManager']
Inheritance:: ['IPoolDelegateCover']
 
+------------------------------+------------+-----------+--------------------------+--------------------------+--------------------------+----------------------------------------------------+
|           Function           | Visibility | Modifiers |           Read           |          Write           |      Internal Calls      |                   External Calls                   |
+------------------------------+------------+-----------+--------------------------+--------------------------+--------------------------+----------------------------------------------------+
|           asset()            |  external  |     []    |            []            |            []            |            []            |                         []                         |
|        poolManager()         |  external  |     []    |            []            |            []            |            []            |                         []                         |
|  moveFunds(uint256,address)  |  external  |     []    |            []            |            []            |            []            |                         []                         |
| constructor(address,address) |   public   |     []    | ['asset', 'poolManager'] | ['asset', 'poolManager'] | ['require(bool,string)'] |                         []                         |
|  moveFunds(uint256,address)  |  external  |     []    | ['asset', 'poolManager'] |            []            | ['require(bool,string)'] | ['ERC20Helper.transfer(asset,recipient_,amount_)'] |
|                              |            |           |      ['msg.sender']      |                          |                          |                                                    |
+------------------------------+------------+-----------+--------------------------+--------------------------+--------------------------+----------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolDelegateCover
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          asset()           |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolManager()        |  external  |     []    |  []  |   []  |       []       |       []       |
| moveFunds(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ERC20Helper
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|                    Function                   | Visibility | Modifiers | Read | Write |             Internal Calls            |                                                                    External Calls                                                                   |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
|       transfer(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                         ['abi.encodeWithSelector(IERC20Like.transfer.selector,to_,amount_)']                                        |
| transferFrom(address,address,address,uint256) |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] |                                    ['abi.encodeWithSelector(IERC20Like.transferFrom.selector,from_,to_,amount_)']                                   |
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['code(address)', 'abi.decode()']   |                                               ['abi.decode(returnData,(bool))', 'token_.call(data_)']                                               |
+-----------------------------------------------+------------+-----------+------+-------+---------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                Function               | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+
|        approve(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       transfer(address,uint256)       |  external  |     []    |  []  |   []  |       []       |       []       |
| transferFrom(address,address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/pool-v2/contracts/PoolDelegateCover.sol analyzed (4 contracts)
