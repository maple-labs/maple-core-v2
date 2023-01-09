#!/usr/bin/env bash
set -e

while getopts d:p:t: flag
do
    case "${flag}" in
        d) directory=${OPTARG};;
        p) profile=${OPTARG};;
        t) test=${OPTARG};;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

if [ -z "$test" ];
then
    forge test --ffi --fork-url "$ETH_RPC_URL" --no-match-test "invariant" --match-path "contracts/$directory/*.t.sol";
else
    forge test --ffi --fork-url "$ETH_RPC_URL" --match "$test";
fi
