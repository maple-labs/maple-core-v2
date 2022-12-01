export FOUNDRY_PROFILE=production
echo using profile $FOUNDRY_PROFILE

forge script --fork-url $ETH_RPC_URL -vvvv --legacy --slow --sender 0x632a45c25d2139E6B2745eC3e7D309dEf99f2b9F --unlocked scripts/DeployMapleV2.s.sol:DeployMapleV2
