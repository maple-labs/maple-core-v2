# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index

export FOUNDRY_PROFILE=production
echo Using profile: $FOUNDRY_PROFILE

# For Testing

# For Core strategy And Router Deployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/CoreStrategyAndRouterDeployment.s.sol:CoreStrategyAndRouterDeployment

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

# For WithdrawalManagerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/WithdrawalManagerDeployment.s.sol:WithdrawalManagerDeployment

# For BitcoinStrategyDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/BitcoinStrategyDeployment.s.sol:BitcoinStrategyDeployment

# For CompositeTokenDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/CompositeTokenDeployment.s.sol:CompositeTokenDeployment

# For AssetControllerOracleDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/AssetControllerOracleDeployment.s.sol:AssetControllerOracleDeployment

# For SyrupBitcoinRouterDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/SyrupBitcoinRouterDeployment.s.sol:SyrupBitcoinRouterDeployment

# For AssetControllerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/AssetControllerDeployment.s.sol:AssetControllerDeployment

# For ModularReleaseDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --unlocked \
#     --slow \
#     --sender $ETH_SENDER \
#     scripts/ModularReleaseDeployment.s.sol:ModularReleaseDeployment

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

# For Core strategy And Router Deployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 15 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     --broadcast \
#     scripts/CoreStrategyAndRouterDeployment.s.sol:CoreStrategyAndRouterDeployment

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

# For WithdrawalManagerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/WithdrawalManagerDeployment.s.sol:WithdrawalManagerDeployment

# For BitcoinStrategyDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/BitcoinStrategyDeployment.s.sol:BitcoinStrategyDeployment

# For CompositeTokenDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/CompositeTokenDeployment.s.sol:CompositeTokenDeployment

# For AssetControllerOracleDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/AssetControllerOracleDeployment.s.sol:AssetControllerOracleDeployment

# For SyrupBitcoinRouterDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/SyrupBitcoinRouterDeployment.s.sol:SyrupBitcoinRouterDeployment

# For AssetControllerDeployment
# forge script \
#     --rpc-url $ETH_RPC_URL \
#     -vvvv \
#     --mnemonic-indexes 20 \
#     --ledger \
#     --slow \
#     --sender $ETH_SENDER \
#     --gas-estimate-multiplier 150 \
#     scripts/AssetControllerDeployment.s.sol:AssetControllerDeployment

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
