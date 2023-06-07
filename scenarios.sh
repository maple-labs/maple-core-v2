#!/bin/bash

for filename in ./scenarios/data/csv/*.csv; do
    name=`basename $filename .csv`
    node ./scripts/convertScenario.js $name
    SCENARIO=$name ./test.sh -d scenarios -p scenarios
done
