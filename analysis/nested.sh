#!/bin/bash

# Analyzes smart contract code in "src" directory using "slither" command and
# saves results in "analysis/results" directory as json files with directory
# path as the file name (with '/' replaced by '-')
# Also saves summary of results in "analysis/summary" directory as json files

# clear out the current results and summary
rm -rf analysis/results/*
rm -rf analysis/summary/*

# find all files in the src directory that are not interfaces
DIRECTORIES=$(find src -type f -not -path '*/interfaces/*' -not -path '*/interfaces')

for DIRECTORY in $DIRECTORIES;
do
    echo "Analyzing $DIRECTORY"

    # create a new name for the json file which replaces the / with a -
    DIR_NAME=$(echo $DIRECTORY | sed 's/\//-/g');

    # ensure the file is not write protected
    chmod 777 "analysis/results/$DIR_NAME.json"

    # run slither on the file and save the results to a json file
    slither "$DIRECTORY" --json "analysis/results/$DIR_NAME.json"

    # extract the description, check, and timestamp if the impact is 'medium or high' and log it to a summary file
    jq -c '.results.detectors[] | select(.impact == "High" or .impact == "Medium") | {check: .check, impact: .impact, description: .description }'\
         "analysis/results/$DIR_NAME.json" > "analysis/summary/$DIR_NAME.json"

done
