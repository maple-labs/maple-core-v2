#!/usr/bin/env bash
set -e

rm -rf reports/slither/contract-summary reports/slither/function-summary reports/slither/vars-and-auth reports/slither/storage-layout

mkdir -p reports/slither/contract-summary reports/slither/function-summary reports/slither/vars-and-auth reports/slither/storage-layout

for dir in modules/*; do
    if [[ "$dir" = "modules/contract-test-utils" ]] || [[ "$dir" = "modules/erc20" ]]; then
        continue
    fi
    for filepath in $dir/contracts/*.sol; do
        file=${filepath##*"contracts/"}
        slither $filepath --print contract-summary --disable-color 2> reports/slither/contract-summary/$file
        slither $filepath --print function-summary 2> reports/slither/function-summary/$file
        slither $filepath --print vars-and-auth 2> reports/slither/vars-and-auth/$file
        slither $filepath --print variable-order 2> reports/slither/storage-layout/$file
    done
done
