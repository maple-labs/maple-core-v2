# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index

export FOUNDRY_PROFILE=production
echo Using profile: $FOUNDRY_PROFILE

# For Testing
# For Maple Strategies Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/MapleStrategiesDeployment.s.sol:MapleStrategiesDeployment

# For Delegated Initiated Loans Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/DelegateInitiatedLoansDeployment.s.sol:DelegateInitiatedLoansDeployment

# For BorrowerActions Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/BorrowerActionsDeployment.s.sol:BorrowerActionsDeployment

# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/BorrowerActionsProxyDeployment.s.sol:BorrowerActionsProxyDeployment

# For Production

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

# For Maple Strategies Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/MapleStrategiesDeployment.s.sol:MapleStrategiesDeployment

# For Delegated Initiated Loans Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/DelegateInitiatedLoansDeployment.s.sol:DelegateInitiatedLoansDeployment

# For BorrowerActions Release
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/BorrowerActionsDeployment.s.sol:BorrowerActionsDeployment

# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/BorrowerActionsProxyDeployment.s.sol:BorrowerActionsProxyDeployment
