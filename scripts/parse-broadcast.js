var json = require("../broadcast/DeployMapleV2.s.sol/1/run-latest.json");

var summaryJson = json.transactions
    .filter(t => t.transactionType == "CREATE")
    .map(t => ({name: t.contractName, address: t.contractAddress}))

console.log(summaryJson)
