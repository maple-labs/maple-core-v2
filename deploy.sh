source ./.env

FOUNDRY_PROFILE=production forge script --fork-url $ETH_RPC_URL -vvvv --legacy --slow --sender $ETH_SENDER --unlocked --broadcast scripts/DeployContracts.s.sol:DeployContracts
