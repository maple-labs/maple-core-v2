# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index

export FOUNDRY_PROFILE=production
echo Using profile: $FOUNDRY_PROFILE

# # For Testing
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/DeployQ4Update.s.sol:DeployQ4UpdateETH

# For Production
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 6 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/DeployQ4Update.s.sol:DeployQ4UpdateETH

# For Healthchecker
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 2 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/DeployHealthChecker.s.sol:DeployHealthChecker
