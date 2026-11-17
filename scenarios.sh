#!/bin/bash

VERSION=${VERSION:-${1:-v2}}
CONVERTER=./scripts/convertScenario${VERSION^^}.js

for filename in ./scenarios/${VERSION}/data/csv/*.csv; do
    name=$(basename "$filename" .csv)
    node "$CONVERTER" "$name"
    SCENARIO=$name ./test.sh -d "scenarios/${VERSION}" -p scenarios
done
