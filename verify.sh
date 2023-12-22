#!/usr/bin/env bash
set -e

# -c argument needs is a path to the contract file and the name of the contract within it (e.g. ./modules/pool/contracts/MaplePool.sol:MaplePool)
# -s argument is the contructor signature (e.g. "constructor(address,address,address,uint256,uint256,string,string)")
# -g argument is the contructor arguments (e.g. "0x24617612DeC91855e126e6330580425F6A262ee9 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0x580B1A894b9FbdBf7d29Ba9b492807Bf539dD508 100000 16265965068493 \"M11 Credit Maple Pool USDC1\" \"MPL-mcUSDC1\""

while getopts a:c:g:i:k:n:p:s:v: flag
do
    case "${flag}" in
        a) address=${OPTARG};;
        c) pathToContract=${OPTARG};;
        g) constructorArguments=${OPTARG};;
        i) chainIdentifier=${OPTARG};;
        k) apiKey=${OPTARG};;
        n) optimizations=${OPTARG};;
        p) profile=${OPTARG};;
        s) constructorSignature=${OPTARG};;
        v) compiler=${OPTARG};;
    esac
done

if [ -z ${address+x} ]; then echo No address provided; exit 1; fi
if [ -z ${pathToContract+x} ]; then echo No contract provided; exit 1; fi

if [ -z ${profile+x} ]; then profile=production; fi
if [ -z ${compiler+x} ]; then compiler=v0.8.7+commit.e28d00a7; fi
if [ -z ${optimizations+x} ]; then optimizations=200; fi
if [ -z ${chainIdentifier+x} ]; then chainIdentifier=mainnet; fi

export FOUNDRY_PROFILE=$profile
export ETHERSCAN_API_KEY=$apiKey

echo Profile: $FOUNDRY_PROFILE
echo Compiler: $compiler
echo Address: $address
echo Path To Contract: $pathToContract
echo Optimzations: $optimizations
echo Chain: $chainIdentifier

if [ -z "$constructorArguments" ];
then
    forge verify-contract --num-of-optimizations $optimizations --compiler-version $compiler --chain $chainIdentifier --watch $address $pathToContract
else
    echo constructorSignature: $constructorSignature
    echo constructorArguments: $constructorArguments

    forge verify-contract --num-of-optimizations $optimizations --compiler-version $compiler --chain $chainIdentifier --watch --constructor-args $(cast abi-encode "$constructorSignature" $constructorArguments) $address $pathToContract
fi
