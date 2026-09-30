# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index

export FOUNDRY_PROFILE=production
echo Using profile: $FOUNDRY_PROFILE

# For Testing

# For Refinance Upgrades Deployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/RefinanceUpgradesDeployment.s.sol:RefinanceUpgradesDeployment

# For GovernorTimelock
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     --broadcast \
#     scripts/GovernorTimelockDeployment.s.sol:GovernorTimelockDeployment

# For GovernorTimelock Cross Chain
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     --broadcast \
#     scripts/GovernorTimelockCrossChainDeployment.s.sol:GovernorTimelockCrossChainDeployment

# For ModularReleaseDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/ModularReleaseDeployment.s.sol:ModularReleaseDeployment

# For HealthCheckerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/HealthCheckerDeployment.s.sol:HealthCheckerDeployment

# For Production

# For Refinance Upgrades Deployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/RefinanceUpgradesDeployment.s.sol:RefinanceUpgradesDeployment

# For GovernorTimelock
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 19 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/GovernorTimelockDeployment.s.sol:GovernorTimelockDeployment

# For GovernorTimelock Cross Chain
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 19 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/GovernorTimelockCrossChainDeployment.s.sol:GovernorTimelockCrossChainDeployment

# For ModularReleaseDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 21 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/ModularReleaseDeployment.s.sol:ModularReleaseDeployment

# For HealthCheckerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 21 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/HealthCheckerDeployment.s.sol:HealthCheckerDeployment
