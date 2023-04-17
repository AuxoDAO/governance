#!/bin/bash

echo "Installing JQ..."
apt install jq -y
echo "  ______                                   "
echo " /      \                                  "
echo "/SSSSSS  | __    __  __    __   ______     "
echo "SS |__SS |/  |  /  |/  \  /  | /      \    "
echo "SS    SS |SS |  SS |SS  \/SS/ /SSSSSS  |   "
echo "SSSSSSSS |SS |  SS | SS  SS<  SS |  SS |   "
echo "SS |  SS |SS \__SS | /SSSS  \ SS \__SS |   "
echo "SS |  SS |SS    SS/ /SS/ SS  |SS    SS/    "
echo "SS/   SS/  SSSSSS/  SS/   SS/  SSSSSS/     "
echo "                                           "
echo
echo "This is an interactive docker container for running slither tests with all prebuilt dependencies."
echo
echo "To get started, run 'slither [path to contract]' or just use 'slither .'"
echo "Alternatively, there is a bash script 'analysis/nested.sh' that will run slither on all contracts in the src/ directory."
echo
echo "NOTE: You will need to first ensure the correct compiler is installed and in use"
echo "      The default compiler is 0.8.16, which will be installed now"
echo "      but you can install and use any version you like."
echo
echo "      Run: 'solc-select install [compiler-version] && solc-select use [compiler-version]'"
echo "      Example: 'solc-select install 0.8.16 && solc-select use 0.8.16'"
echo
echo "[OPTIONAL] Slither supports GPT-3 analysis if you have an OPENAI_API_KEY set in your environment."
echo "Run it with:"
echo "      export OPENAI_API_KEY=[your key]"
echo "      slither [dir] --codex --codex-log"
echo
echo "Print this message again with './analysis/welcome.sh'"
echo
echo "Installing the solidity compiler..."
. venv/bin/activate
solc-select install 0.8.16 && solc-select use 0.8.16

# keep running the container after the entrypoint
bash
