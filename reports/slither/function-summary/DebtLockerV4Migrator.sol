
Contract DebtLockerStorage
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator']
Inheritance:: []
 
+----------+------------+-----------+------+-------+----------------+----------------+
| Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls |
+----------+------------+-----------+------+-------+----------------+----------------+
+----------+------------+-----------+------+-------+----------------+----------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract DebtLockerV4Migrator
Contract vars: ['_liquidator', '_loan', '_pool', '_repossessed', '_allowedSlippage', '_amountRecovered', '_fundsToCapture', '_minRatio', '_principalRemainingAtLastClaim', '_loanMigrator']
Inheritance:: ['DebtLockerStorage', 'IDebtLockerV4Migrator']
 
+--------------------------+------------+-----------+--------------+-------------------+---------------------+---------------------------------------------+
|         Function         | Visibility | Modifiers |     Read     |       Write       |    Internal Calls   |                External Calls               |
+--------------------------+------------+-----------+--------------+-------------------+---------------------+---------------------------------------------+
| encodeArguments(address) |  external  |     []    |      []      |         []        |          []         |                      []                     |
|  decodeArguments(bytes)  |  external  |     []    |      []      |         []        |          []         |                      []                     |
| encodeArguments(address) |  external  |     []    |      []      |         []        |   ['abi.encode()']  |          ['abi.encode(migrator_)']          |
|  decodeArguments(bytes)  |   public   |     []    |      []      |         []        |   ['abi.decode()']  | ['abi.decode(encodedArguments_,(address))'] |
|        fallback()        |  external  |     []    | ['msg.data'] | ['_loanMigrator'] | ['decodeArguments'] |                      []                     |
+--------------------------+------------+-----------+--------------+-------------------+---------------------+---------------------------------------------+

+-----------+------------+------+-------+----------------+----------------+
| Modifiers | Visibility | Read | Write | Internal Calls | External Calls |
+-----------+------------+------+-------+----------------+----------------+
+-----------+------------+------+-------+----------------+----------------+


Contract IDebtLockerV4Migrator
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

modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol analyzed (3 contracts)
