source ./.env

# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index
FOUNDRY_PROFILE=production forge script --rpc-url $ETH_RPC_URL -vvvv --mnemonic-indexes 5 --ledger --sender $ETH_SENDER scripts/DeployQ4Update.s.sol:DeployQ4UpdateETH
