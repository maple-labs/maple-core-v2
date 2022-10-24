#!/usr/bin/env bash
set -e

while getopts p:t: flag
do
    case "${flag}" in
        p) profile=${OPTARG};;
        t) test=${OPTARG};;
    esac
done

export FOUNDRY_PROFILE=mainnet_simulations
echo Using profile: $FOUNDRY_PROFILE

if [ -z "$test" ];
then
    forge test --fork-block-number=15790000 --fork-url "$ETH_RPC_URL";
else
    forge test --match "$test" --fork-block-number=15790000 --fork-url "$ETH_RPC_URL";
fi
