
Contract Pool
Contract vars: ['name', 'symbol', 'decimals', 'totalSupply', 'balanceOf', 'allowance', 'PERMIT_TYPEHASH', 'nonces', 'asset', 'manager', '_locked']
Inheritance:: ['ERC20', 'IPool', 'IERC4626', 'IERC20']
 
+-----------------------------------------------------------------------+------------+-------------------------------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                                Function                               | Visibility |           Modifiers           |              Read             |            Write             |                            Internal Calls                            |                                                                                                             External Calls                                                                                                             |
+-----------------------------------------------------------------------+------------+-------------------------------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                    constructor(string,string,uint8)                   |   public   |               []              |               []              |     ['decimals', 'name']     |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                                                                       |            |                               |                               |          ['symbol']          |                                                                      |                                                                                                                                                                                                                                        |
|                        approve(address,uint256)                       |   public   |               []              |         ['msg.sender']        |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
|                   decreaseAllowance(address,uint256)                  |   public   |               []              |         ['msg.sender']        |              []              |                        ['_decreaseAllowance']                        |                                                                                                                   []                                                                                                                   |
|                   increaseAllowance(address,uint256)                  |   public   |               []              |  ['allowance', 'msg.sender']  |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
|     permit(address,address,uint256,uint256,uint8,bytes32,bytes32)     |   public   |               []              | ['PERMIT_TYPEHASH', 'nonces'] |          ['nonces']          |                 ['abi.encode()', 'keccak256(bytes)']                 | ['abi.encode(PERMIT_TYPEHASH,owner_,spender_,amount_,nonces[owner_] ++,deadline_)', 'abi.encodePacked(\x19\x01,DOMAIN_SEPARATOR(),keccak256(bytes)(abi.encode(PERMIT_TYPEHASH,owner_,spender_,amount_,nonces[owner_] ++,deadline_)))'] |
|                                                                       |            |                               |      ['block.timestamp']      |                              | ['ecrecover(bytes32,uint8,bytes32,bytes32)', 'require(bool,string)'] |                                                                                                                                                                                                                                        |
|                                                                       |            |                               |                               |                              |              ['DOMAIN_SEPARATOR', 'abi.encodePacked()']              |                                                                                                                                                                                                                                        |
|                                                                       |            |                               |                               |                              |                             ['_approve']                             |                                                                                                                                                                                                                                        |
|                       transfer(address,uint256)                       |   public   |               []              |         ['msg.sender']        |              []              |                            ['_transfer']                             |                                                                                                                   []                                                                                                                   |
|                 transferFrom(address,address,uint256)                 |   public   |               []              |         ['msg.sender']        |              []              |                 ['_decreaseAllowance', '_transfer']                  |                                                                                                                   []                                                                                                                   |
|                           DOMAIN_SEPARATOR()                          |   public   |               []              |   ['name', 'block.chainid']   |              []              |                 ['keccak256(bytes)', 'abi.encode()']                 |               ['abi.encode(keccak256(bytes)(EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)),keccak256(bytes)(bytes(name)),keccak256(bytes)(bytes(1)),block.chainid,address(this))']                |
|                                                                       |            |                               |            ['this']           |                              |                                                                      |                                                                                                                                                                                                                                        |
|                   _approve(address,address,uint256)                   |  internal  |               []              |         ['allowance']         |        ['allowance']         |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         _burn(address,uint256)                        |  internal  |               []              |  ['balanceOf', 'totalSupply'] | ['balanceOf', 'totalSupply'] |                                  []                                  |                                                                                                                   []                                                                                                                   |
|              _decreaseAllowance(address,address,uint256)              |  internal  |               []              |         ['allowance']         |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
|                         _mint(address,uint256)                        |  internal  |               []              |  ['balanceOf', 'totalSupply'] | ['balanceOf', 'totalSupply'] |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   _transfer(address,address,uint256)                  |  internal  |               []              |         ['balanceOf']         |        ['balanceOf']         |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        approve(address,uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   decreaseAllowance(address,uint256)                  |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   increaseAllowance(address,uint256)                  |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|     permit(address,address,uint256,uint256,uint8,bytes32,bytes32)     |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                       transfer(address,uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                 transferFrom(address,address,uint256)                 |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                       allowance(address,address)                      |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           balanceOf(address)                          |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                               decimals()                              |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           DOMAIN_SEPARATOR()                          |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                                 name()                                |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                            nonces(address)                            |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           PERMIT_TYPEHASH()                           |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                                symbol()                               |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                             totalSupply()                             |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                               manager()                               |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|    depositWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)   |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
| mintWithPermit(uint256,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         removeShares(uint256)                         |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        requestWithdraw(uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         requestRedeem(uint256)                        |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        balanceOfAssets(address)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                      convertToExitShares(uint256)                     |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           unrealizedLosses()                          |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                                asset()                                |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        deposit(uint256,address)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         mint(uint256,address)                         |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                    redeem(uint256,address,address)                    |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   withdraw(uint256,address,address)                   |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        convertToAssets(uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        convertToShares(uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                          maxDeposit(address)                          |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                            maxMint(address)                           |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           maxRedeem(address)                          |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                          maxWithdraw(address)                         |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        previewDeposit(uint256)                        |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                          previewMint(uint256)                         |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         previewRedeem(uint256)                        |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        previewWithdraw(uint256)                       |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                             totalAssets()                             |  external  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|       constructor(address,address,address,uint256,string,string)      |   public   |               []              |      ['asset', 'manager']     |     ['asset', 'manager']     |                     ['require(bool,string)', '']                     |                                                                        ['ERC20Helper.approve(asset_,manager_,type()(uint256).max)', 'ERC20(asset_).decimals()']                                                                        |
|                                                                       |            |                               |                               |                              |                              ['_mint']                               |                                                                                                                                                                                                                                        |
|                        deposit(uint256,address)                       |  external  | ['nonReentrant', 'checkCall'] |         ['msg.sender']        |              []              |                        ['checkCall', '_mint']                        |                                                                                                                   []                                                                                                                   |
|                                                                       |            |                               |                               |                              |                  ['nonReentrant', 'previewDeposit']                  |                                                                                                                                                                                                                                        |
|    depositWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)   |  external  | ['nonReentrant', 'checkCall'] |    ['asset', 'msg.sender']    |              []              |                        ['checkCall', '_mint']                        |                                                                              ['ERC20(asset).permit(msg.sender,address(this),assets_,deadline_,v_,r_,s_)']                                                                              |
|                                                                       |            |                               |            ['this']           |                              |                  ['nonReentrant', 'previewDeposit']                  |                                                                                                                                                                                                                                        |
|                         mint(uint256,address)                         |  external  | ['nonReentrant', 'checkCall'] |         ['msg.sender']        |              []              |                     ['checkCall', 'previewMint']                     |                                                                                                                   []                                                                                                                   |
|                                                                       |            |                               |                               |                              |                      ['_mint', 'nonReentrant']                       |                                                                                                                                                                                                                                        |
| mintWithPermit(uint256,address,uint256,uint256,uint8,bytes32,bytes32) |  external  | ['nonReentrant', 'checkCall'] |    ['asset', 'msg.sender']    |              []              |                    ['checkCall', 'nonReentrant']                     |                                                                            ['ERC20(asset).permit(msg.sender,address(this),maxAssets_,deadline_,v_,r_,s_)']                                                                             |
|                                                                       |            |                               |            ['this']           |                              |               ['previewMint', 'require(bool,string)']                |                                                                                                                                                                                                                                        |
|                                                                       |            |                               |                               |                              |                              ['_mint']                               |                                                                                                                                                                                                                                        |
|                    redeem(uint256,address,address)                    |  external  |        ['nonReentrant']       |   ['manager', 'msg.sender']   |              []              |                      ['_burn', 'nonReentrant']                       |                                                                                      ['IPoolManagerLike(manager).processRedeem(shares_,owner_)']                                                                                       |
|                   withdraw(uint256,address,address)                   |  external  |        ['nonReentrant']       |   ['manager', 'msg.sender']   |              []              |                   ['_burn', 'convertToExitShares']                   |                                                                            ['IPoolManagerLike(manager).processRedeem(convertToExitShares(assets_),owner_)']                                                                            |
|                                                                       |            |                               |                               |                              |                           ['nonReentrant']                           |                                                                                                                                                                                                                                        |
|                       transfer(address,uint256)                       |   public   |         ['checkCall']         |               []              |              []              |                      ['checkCall', 'transfer']                       |                                                                                                                   []                                                                                                                   |
|                 transferFrom(address,address,uint256)                 |   public   |         ['checkCall']         |               []              |              []              |                    ['checkCall', 'transferFrom']                     |                                                                                                                   []                                                                                                                   |
|                         removeShares(uint256)                         |  external  |        ['nonReentrant']       |   ['manager', 'msg.sender']   |              []              |                           ['nonReentrant']                           |                                                                                     ['IPoolManagerLike(manager).removeShares(shares_,msg.sender)']                                                                                     |
|                         requestRedeem(uint256)                        |  external  |        ['nonReentrant']       |         ['msg.sender']        |              []              |                  ['nonReentrant', '_requestRedeem']                  |                                                                                                                   []                                                                                                                   |
|                        requestWithdraw(uint256)                       |  external  |        ['nonReentrant']       |         ['msg.sender']        |              []              |               ['convertToExitShares', 'nonReentrant']                |                                                                                                                   []                                                                                                                   |
|                                                                       |            |                               |                               |                              |                          ['_requestRedeem']                          |                                                                                                                                                                                                                                        |
|             _burn(uint256,uint256,address,address,address)            |  internal  |               []              |           ['asset']           |              []              |            ['require(bool,string)', '_decreaseAllowance']            |                                                                                           ['ERC20Helper.transfer(asset,receiver_,assets_)']                                                                                            |
|                                                                       |            |                               |                               |                              |                              ['_burn']                               |                                                                                                                                                                                                                                        |
|                      _divRoundUp(uint256,uint256)                     |  internal  |               []              |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                 _mint(uint256,uint256,address,address)                |  internal  |               []              |       ['asset', 'this']       |              []              |                  ['require(bool,string)', '_mint']                   |                                                                                   ['ERC20Helper.transferFrom(asset,caller_,address(this),assets_)']                                                                                    |
|                        _requestRedeem(uint256)                        |  internal  |               []              |   ['manager', 'msg.sender']   |              []              |                ['require(bool,string)', '_transfer']                 |                                                 ['IPoolManagerLike(manager).getEscrowParams(msg.sender,shares_)', 'IPoolManagerLike(manager).requestRedeem(escrowShares_,msg.sender)']                                                 |
|                        balanceOfAssets(address)                       |  external  |               []              |         ['balanceOf']         |              []              |                         ['convertToAssets']                          |                                                                                                                   []                                                                                                                   |
|                          maxDeposit(address)                          |  external  |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                          ['IPoolManagerLike(manager).maxDeposit(receiver_)']                                                                                           |
|                            maxMint(address)                           |  external  |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                            ['IPoolManagerLike(manager).maxMint(receiver_)']                                                                                            |
|                           maxRedeem(address)                          |  external  |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                            ['IPoolManagerLike(manager).maxRedeem(owner_)']                                                                                             |
|                          maxWithdraw(address)                         |  external  |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                           ['IPoolManagerLike(manager).maxWithdraw(owner_)']                                                                                            |
|                         previewRedeem(uint256)                        |  external  |               []              |   ['manager', 'msg.sender']   |              []              |                                  []                                  |                                                                                    ['IPoolManagerLike(manager).previewRedeem(msg.sender,shares_)']                                                                                     |
|                        previewWithdraw(uint256)                       |  external  |               []              |   ['manager', 'msg.sender']   |              []              |                                  []                                  |                                                                                   ['IPoolManagerLike(manager).previewWithdraw(msg.sender,assets_)']                                                                                    |
|                        convertToAssets(uint256)                       |   public   |               []              |        ['totalSupply']        |              []              |                           ['totalAssets']                            |                                                                                                                   []                                                                                                                   |
|                        convertToShares(uint256)                       |   public   |               []              |        ['totalSupply']        |              []              |                           ['totalAssets']                            |                                                                                                                   []                                                                                                                   |
|                      convertToExitShares(uint256)                     |   public   |               []              |        ['totalSupply']        |              []              |                 ['unrealizedLosses', '_divRoundUp']                  |                                                                                                                   []                                                                                                                   |
|                                                                       |            |                               |                               |                              |                           ['totalAssets']                            |                                                                                                                                                                                                                                        |
|                        previewDeposit(uint256)                        |   public   |               []              |               []              |              []              |                         ['convertToShares']                          |                                                                                                                   []                                                                                                                   |
|                          previewMint(uint256)                         |   public   |               []              |        ['totalSupply']        |              []              |                    ['_divRoundUp', 'totalAssets']                    |                                                                                                                   []                                                                                                                   |
|                             totalAssets()                             |   public   |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                              ['IPoolManagerLike(manager).totalAssets()']                                                                                               |
|                           unrealizedLosses()                          |   public   |               []              |          ['manager']          |              []              |                                  []                                  |                                                                                            ['IPoolManagerLike(manager).unrealizedLosses()']                                                                                            |
|                     slitherConstructorVariables()                     |  internal  |               []              |               []              |         ['_locked']          |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                 slitherConstructorConstantVariables()                 |  internal  |               []              |               []              |     ['PERMIT_TYPEHASH']      |                                  []                                  |                                                                                                                   []                                                                                                                   |
+-----------------------------------------------------------------------+------------+-------------------------------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+--------------------+------------+-------------------------+-------------+--------------------------+------------------------------------------------------------------------+
|     Modifiers      | Visibility |           Read          |    Write    |      Internal Calls      |                             External Calls                             |
+--------------------+------------+-------------------------+-------------+--------------------------+------------------------------------------------------------------------+
| checkCall(bytes32) |  internal  | ['manager', 'msg.data'] |      []     | ['require(bool,string)'] | ['IPoolManagerLike(manager).canCall(functionId_,msg.sender,msg.data)'] |
|                    |            |      ['msg.sender']     |             |                          |                                                                        |
|   nonReentrant()   |  internal  |       ['_locked']       | ['_locked'] | ['require(bool,string)'] |                                   []                                   |
+--------------------+------------+-------------------------+-------------+--------------------------+------------------------------------------------------------------------+


Contract IERC4626
Contract vars: []
Inheritance:: ['IERC20']
 
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                            Function                           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                    approve(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|               decreaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
|               increaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
| permit(address,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |     []    |  []  |   []  |       []       |       []       |
|                   transfer(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             transferFrom(address,address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                   allowance(address,address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                       balanceOf(address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                           decimals()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                       DOMAIN_SEPARATOR()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                             name()                            |  external  |     []    |  []  |   []  |       []       |       []       |
|                        nonces(address)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                       PERMIT_TYPEHASH()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                            symbol()                           |  external  |     []    |  []  |   []  |       []       |       []       |
|                         totalSupply()                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                            asset()                            |  external  |     []    |  []  |   []  |       []       |       []       |
|                    deposit(uint256,address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                     mint(uint256,address)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                redeem(uint256,address,address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|               withdraw(uint256,address,address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                    convertToAssets(uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                    convertToShares(uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                      maxDeposit(address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                        maxMint(address)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                       maxRedeem(address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                      maxWithdraw(address)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                    previewDeposit(uint256)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                      previewMint(uint256)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                     previewRedeem(uint256)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                    previewWithdraw(uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                         totalAssets()                         |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPool
Contract vars: []
Inheritance:: ['IERC4626', 'IERC20']
 
+-----------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                                Function                               | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                                asset()                                |  external  |     []    |  []  |   []  |       []       |       []       |
|                        deposit(uint256,address)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                         mint(uint256,address)                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                    redeem(uint256,address,address)                    |  external  |     []    |  []  |   []  |       []       |       []       |
|                   withdraw(uint256,address,address)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|                        convertToAssets(uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                        convertToShares(uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                          maxDeposit(address)                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                            maxMint(address)                           |  external  |     []    |  []  |   []  |       []       |       []       |
|                           maxRedeem(address)                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                          maxWithdraw(address)                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                        previewDeposit(uint256)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                          previewMint(uint256)                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                         previewRedeem(uint256)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                        previewWithdraw(uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                             totalAssets()                             |  external  |     []    |  []  |   []  |       []       |       []       |
|                        approve(address,uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                   decreaseAllowance(address,uint256)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                   increaseAllowance(address,uint256)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|     permit(address,address,uint256,uint256,uint8,bytes32,bytes32)     |  external  |     []    |  []  |   []  |       []       |       []       |
|                       transfer(address,uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                 transferFrom(address,address,uint256)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                       allowance(address,address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                           balanceOf(address)                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                               decimals()                              |  external  |     []    |  []  |   []  |       []       |       []       |
|                           DOMAIN_SEPARATOR()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                                 name()                                |  external  |     []    |  []  |   []  |       []       |       []       |
|                            nonces(address)                            |  external  |     []    |  []  |   []  |       []       |       []       |
|                           PERMIT_TYPEHASH()                           |  external  |     []    |  []  |   []  |       []       |       []       |
|                                symbol()                               |  external  |     []    |  []  |   []  |       []       |       []       |
|                             totalSupply()                             |  external  |     []    |  []  |   []  |       []       |       []       |
|                               manager()                               |  external  |     []    |  []  |   []  |       []       |       []       |
|    depositWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)   |  external  |     []    |  []  |   []  |       []       |       []       |
| mintWithPermit(uint256,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |     []    |  []  |   []  |       []       |       []       |
|                         removeShares(uint256)                         |  external  |     []    |  []  |   []  |       []       |       []       |
|                        requestWithdraw(uint256)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                         requestRedeem(uint256)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                        balanceOfAssets(address)                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                      convertToExitShares(uint256)                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                           unrealizedLosses()                          |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20Like
Contract vars: []
Inheritance:: []
 
+--------------------+------------+-----------+------+-------+----------------+----------------+
|      Function      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------+------------+-----------+------+-------+----------------+----------------+
| balanceOf(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|     decimals()     |  external  |     []    |  []  |   []  |       []       |       []       |
|   totalSupply()    |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerLike
Contract vars: []
Inheritance:: []
 
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                     Function                    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
| acceptNewTerms(address,address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|             assetsUnderManagement()             |  external  |     []    |  []  |   []  |       []       |       []       |
|               claim(address,bool)               |  external  |     []    |  []  |   []  |       []       |       []       |
|       finishCollateralLiquidation(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|                  fund(address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|        removeDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|       triggerDefaultWarning(address,bool)       |  external  |     []    |  []  |   []  |       []       |       []       |
|             triggerDefault(address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                unrealizedLosses()               |  external  |     []    |  []  |   []  |       []       |       []       |
+-------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanManagerInitializerLike
Contract vars: []
Inheritance:: []
 
+--------------------------+------------+-----------+------+-------+----------------+----------------+
|         Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------+------------+-----------+------+-------+----------------+----------------+
| encodeArguments(address) |  external  |     []    |  []  |   []  |       []       |       []       |
|  decodeArguments(bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILiquidatorLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
| liquidatePortion(uint256,uint256,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|    pullFunds(address,address,uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanV3Like
Contract vars: []
Inheritance:: []
 
+---------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function         | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------+------------+-----------+------+-------+----------------+----------------+
| getNextPaymentBreakdown() |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract ILoanLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                 Function                | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              acceptLender()             |  external  |     []    |  []  |   []  |       []       |       []       |
| acceptNewTerms(address,uint256,bytes[]) |  external  |     []    |  []  |   []  |       []       |       []       |
|   batchClaimFunds(uint256[],address[])  |  external  |     []    |  []  |   []  |       []       |       []       |
|                borrower()               |  external  |     []    |  []  |   []  |       []       |       []       |
|       claimFunds(uint256,address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|               collateral()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            collateralAsset()            |  external  |     []    |  []  |   []  |       []       |       []       |
|               feeManager()              |  external  |     []    |  []  |   []  |       []       |       []       |
|               fundsAsset()              |  external  |     []    |  []  |   []  |       []       |       []       |
|            fundLoan(address)            |  external  |     []    |  []  |   []  |       []       |       []       |
|       getClosingPaymentBreakdown()      |  external  |     []    |  []  |   []  |       []       |       []       |
|    getNextPaymentDetailedBreakdown()    |  external  |     []    |  []  |   []  |       []       |       []       |
|        getNextPaymentBreakdown()        |  external  |     []    |  []  |   []  |       []       |       []       |
|              gracePeriod()              |  external  |     []    |  []  |   []  |       []       |       []       |
|              interestRate()             |  external  |     []    |  []  |   []  |       []       |       []       |
|           isInDefaultWarning()          |  external  |     []    |  []  |   []  |       []       |       []       |
|              lateFeeRate()              |  external  |     []    |  []  |   []  |       []       |       []       |
|           nextPaymentDueDate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|            paymentInterval()            |  external  |     []    |  []  |   []  |       []       |       []       |
|           paymentsRemaining()           |  external  |     []    |  []  |   []  |       []       |       []       |
|               principal()               |  external  |     []    |  []  |   []  |       []       |       []       |
|           principalRequested()          |  external  |     []    |  []  |   []  |       []       |       []       |
|           refinanceInterest()           |  external  |     []    |  []  |   []  |       []       |       []       |
|          removeDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|            repossess(address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|        setPendingLender(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         triggerDefaultWarning()         |  external  |     []    |  []  |   []  |       []       |       []       |
|        prewarningPaymentDueDate()       |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleGlobalsLike
Contract vars: []
Inheritance:: []
 
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                       Function                      | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|               getLatestPrice(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                      governor()                     |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isBorrower(address)                 |  external  |     []    |  []  |   []  |       []       |       []       |
|              isFactory(bytes32,address)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                 isPoolAsset(address)                |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDelegate(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|               isPoolDeployer(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
| isValidScheduledCall(address,address,bytes32,bytes) |  external  |     []    |  []  |   []  |       []       |       []       |
|          platformManagementFeeRate(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxCoverLiquidationPercent(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|                   migrationAdmin()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|               minCoverAmount(address)               |  external  |     []    |  []  |   []  |       []       |       []       |
|                   mapleTreasury()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|              ownedPoolManager(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                   protocolPaused()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|      transferOwnedPoolManager(address,address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|        unscheduleCall(address,bytes32,bytes)        |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleLoanFeeManagerLike
Contract vars: []
Inheritance:: []
 
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
|           Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+
| platformServiceFee(address) |  external  |     []    |  []  |   []  |       []       |       []       |
+-----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IMapleProxyFactoryLike
Contract vars: []
Inheritance:: []
 
+----------------+------------+-----------+------+-------+----------------+----------------+
|    Function    | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------+------------+-----------+------+-------+----------------+----------------+
| mapleGlobals() |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolDelegateCoverLike
Contract vars: []
Inheritance:: []
 
+----------------------------+------------+-----------+------+-------+----------------+----------------+
|          Function          | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------+------------+-----------+------+-------+----------------+----------------+
| moveFunds(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolLike
Contract vars: []
Inheritance:: ['IERC20Like']
 
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                   Function                   | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|              balanceOf(address)              |  external  |     []    |  []  |   []  |       []       |       []       |
|                  decimals()                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                totalSupply()                 |  external  |     []    |  []  |   []  |       []       |       []       |
|                   asset()                    |  external  |     []    |  []  |   []  |       []       |       []       |
|           convertToAssets(uint256)           |  external  |     []    |  []  |   []  |       []       |       []       |
|         convertToExitShares(uint256)         |  external  |     []    |  []  |   []  |       []       |       []       |
|           deposit(uint256,address)           |  external  |     []    |  []  |   []  |       []       |       []       |
|                  manager()                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             previewMint(uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
| processExit(uint256,uint256,address,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|       redeem(uint256,address,address)        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IPoolManagerLike
Contract vars: []
Inheritance:: []
 
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|             Function             | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+
|     addLoanManager(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
|  canCall(bytes32,address,bytes)  |  external  |     []    |  []  |   []  |       []       |       []       |
|   convertToExitShares(uint256)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          claim(address)          |  external  |     []    |  []  |   []  |       []       |       []       |
|   delegateManagementFeeRate()    |  external  |     []    |  []  |   []  |       []       |       []       |
|  fund(uint256,address,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
| getEscrowParams(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|            globals()             |  external  |     []    |  []  |   []  |       []       |       []       |
|       hasSufficientCover()       |  external  |     []    |  []  |   []  |       []       |       []       |
|          loanManager()           |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxDeposit(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|         maxMint(address)         |  external  |     []    |  []  |   []  |       []       |       []       |
|        maxRedeem(address)        |  external  |     []    |  []  |   []  |       []       |       []       |
|       maxWithdraw(address)       |  external  |     []    |  []  |   []  |       []       |       []       |
|  previewRedeem(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| previewWithdraw(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
| processWithdraw(uint256,address) |  external  |     []    |  []  |   []  |       []       |       []       |
|          poolDelegate()          |  external  |     []    |  []  |   []  |       []       |       []       |
|       poolDelegateCover()        |  external  |     []    |  []  |   []  |       []       |       []       |
|    removeLoanManager(address)    |  external  |     []    |  []  |   []  |       []       |       []       |
|  removeShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|  requestRedeem(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
|  setWithdrawalManager(address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|          totalAssets()           |  external  |     []    |  []  |   []  |       []       |       []       |
|        unrealizedLosses()        |  external  |     []    |  []  |   []  |       []       |       []       |
|       withdrawalManager()        |  external  |     []    |  []  |   []  |       []       |       []       |
+----------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IWithdrawalManagerLike
Contract vars: []
Inheritance:: []
 
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|            Function            | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+
|   addShares(uint256,address)   |  external  |     []    |  []  |   []  |       []       |       []       |
|    isInExitWindow(address)     |  external  |     []    |  []  |   []  |       []       |       []       |
|       lockedLiquidity()        |  external  |     []    |  []  |   []  |       []       |       []       |
|     lockedShares(address)      |  external  |     []    |  []  |   []  |       []       |       []       |
| previewRedeem(address,uint256) |  external  |     []    |  []  |   []  |       []       |       []       |
|  processExit(address,uint256)  |  external  |     []    |  []  |   []  |       []       |       []       |
| removeShares(uint256,address)  |  external  |     []    |  []  |   []  |       []       |       []       |
+--------------------------------+------------+-----------+------+-------+----------------+----------------+

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
|        approve(address,address,uint256)       |  internal  |     []    |  []  |   []  | ['_call', 'abi.encodeWithSelector()'] | ['abi.encodeWithSelector(IERC20Like.approve.selector,spender_,amount_)', 'abi.encodeWithSelector(IERC20Like.approve.selector,spender_,uint256(0))'] |
|              _call(address,bytes)             |  private   |     []    |  []  |   []  |   ['code(address)', 'abi.decode()']   |                                               ['token_.call(data_)', 'abi.decode(returnData,(bool))']                                               |
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


Contract ERC20
Contract vars: ['name', 'symbol', 'decimals', 'totalSupply', 'balanceOf', 'allowance', 'PERMIT_TYPEHASH', 'nonces']
Inheritance:: ['IERC20']
 
+---------------------------------------------------------------+------------+-----------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                            Function                           | Visibility | Modifiers |              Read             |            Write             |                            Internal Calls                            |                                                                                                             External Calls                                                                                                             |
+---------------------------------------------------------------+------------+-----------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                    approve(address,uint256)                   |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|               decreaseAllowance(address,uint256)              |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|               increaseAllowance(address,uint256)              |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
| permit(address,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   transfer(address,uint256)                   |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|             transferFrom(address,address,uint256)             |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                   allowance(address,address)                  |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                       balanceOf(address)                      |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                           decimals()                          |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                       DOMAIN_SEPARATOR()                      |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                             name()                            |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                        nonces(address)                        |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                       PERMIT_TYPEHASH()                       |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                            symbol()                           |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                         totalSupply()                         |  external  |     []    |               []              |              []              |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                constructor(string,string,uint8)               |   public   |     []    |               []              |     ['decimals', 'name']     |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                                                               |            |           |                               |          ['symbol']          |                                                                      |                                                                                                                                                                                                                                        |
|                    approve(address,uint256)                   |   public   |     []    |         ['msg.sender']        |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
|               decreaseAllowance(address,uint256)              |   public   |     []    |         ['msg.sender']        |              []              |                        ['_decreaseAllowance']                        |                                                                                                                   []                                                                                                                   |
|               increaseAllowance(address,uint256)              |   public   |     []    |  ['allowance', 'msg.sender']  |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
| permit(address,address,uint256,uint256,uint8,bytes32,bytes32) |   public   |     []    | ['PERMIT_TYPEHASH', 'nonces'] |          ['nonces']          |                     ['_approve', 'abi.encode()']                     | ['abi.encode(PERMIT_TYPEHASH,owner_,spender_,amount_,nonces[owner_] ++,deadline_)', 'abi.encodePacked(\x19\x01,DOMAIN_SEPARATOR(),keccak256(bytes)(abi.encode(PERMIT_TYPEHASH,owner_,spender_,amount_,nonces[owner_] ++,deadline_)))'] |
|                                                               |            |           |      ['block.timestamp']      |                              |               ['keccak256(bytes)', 'DOMAIN_SEPARATOR']               |                                                                                                                                                                                                                                        |
|                                                               |            |           |                               |                              | ['ecrecover(bytes32,uint8,bytes32,bytes32)', 'require(bool,string)'] |                                                                                                                                                                                                                                        |
|                                                               |            |           |                               |                              |                        ['abi.encodePacked()']                        |                                                                                                                                                                                                                                        |
|                   transfer(address,uint256)                   |   public   |     []    |         ['msg.sender']        |              []              |                            ['_transfer']                             |                                                                                                                   []                                                                                                                   |
|             transferFrom(address,address,uint256)             |   public   |     []    |         ['msg.sender']        |              []              |                 ['_decreaseAllowance', '_transfer']                  |                                                                                                                   []                                                                                                                   |
|                       DOMAIN_SEPARATOR()                      |   public   |     []    |   ['name', 'block.chainid']   |              []              |                 ['keccak256(bytes)', 'abi.encode()']                 |               ['abi.encode(keccak256(bytes)(EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)),keccak256(bytes)(bytes(name)),keccak256(bytes)(bytes(1)),block.chainid,address(this))']                |
|                                                               |            |           |            ['this']           |                              |                                                                      |                                                                                                                                                                                                                                        |
|               _approve(address,address,uint256)               |  internal  |     []    |         ['allowance']         |        ['allowance']         |                                  []                                  |                                                                                                                   []                                                                                                                   |
|                     _burn(address,uint256)                    |  internal  |     []    |  ['balanceOf', 'totalSupply'] | ['balanceOf', 'totalSupply'] |                                  []                                  |                                                                                                                   []                                                                                                                   |
|          _decreaseAllowance(address,address,uint256)          |  internal  |     []    |         ['allowance']         |              []              |                             ['_approve']                             |                                                                                                                   []                                                                                                                   |
|                     _mint(address,uint256)                    |  internal  |     []    |  ['balanceOf', 'totalSupply'] | ['balanceOf', 'totalSupply'] |                                  []                                  |                                                                                                                   []                                                                                                                   |
|               _transfer(address,address,uint256)              |  internal  |     []    |         ['balanceOf']         |        ['balanceOf']         |                                  []                                  |                                                                                                                   []                                                                                                                   |
|             slitherConstructorConstantVariables()             |  internal  |     []    |               []              |     ['PERMIT_TYPEHASH']      |                                  []                                  |                                                                                                                   []                                                                                                                   |
+---------------------------------------------------------------+------------+-----------+-------------------------------+------------------------------+----------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IERC20
Contract vars: []
Inheritance:: []
 
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                            Function                           | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+
|                    approve(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|               decreaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
|               increaseAllowance(address,uint256)              |  external  |     []    |  []  |   []  |       []       |       []       |
| permit(address,address,uint256,uint256,uint8,bytes32,bytes32) |  external  |     []    |  []  |   []  |       []       |       []       |
|                   transfer(address,uint256)                   |  external  |     []    |  []  |   []  |       []       |       []       |
|             transferFrom(address,address,uint256)             |  external  |     []    |  []  |   []  |       []       |       []       |
|                   allowance(address,address)                  |  external  |     []    |  []  |   []  |       []       |       []       |
|                       balanceOf(address)                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                           decimals()                          |  external  |     []    |  []  |   []  |       []       |       []       |
|                       DOMAIN_SEPARATOR()                      |  external  |     []    |  []  |   []  |       []       |       []       |
|                             name()                            |  external  |     []    |  []  |   []  |       []       |       []       |
|                        nonces(address)                        |  external  |     []    |  []  |   []  |       []       |       []       |
|                       PERMIT_TYPEHASH()                       |  external  |     []    |  []  |   []  |       []       |       []       |
|                            symbol()                           |  external  |     []    |  []  |   []  |       []       |       []       |
|                         totalSupply()                         |  external  |     []    |  []  |   []  |       []       |       []       |
+---------------------------------------------------------------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+

modules/pool-v2/contracts/Pool.sol analyzed (20 contracts)
