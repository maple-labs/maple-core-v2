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
    forge test --ffi --fork-url "$ETH_RPC_URL";
else
    forge test --ffi --match "$test" --fork-url "$ETH_RPC_URL";
fi
