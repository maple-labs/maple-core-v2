source ./.env
# Note to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index
# and you have to use --mnemonics foo as foundry enforces a mnemonic flag requirement when using mnemonic-indexes
# see https://github.com/foundry-rs/foundry/issues/5179
FOUNDRY_PROFILE=production forge script --rpc-url $ETH_RPC_URL -vvvv --mnemonics foo --mnemonic-indexes 3 --ledger --broadcast --sender $ETH_SENDER scripts/DeployHealthChecker.s.sol:DeployHealthChecker
