# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# env var check
check-env :; echo $(ETHERSCAN_API_KEY)

all: clean install build

# Clean the repo
clean :; forge clean

# Install the Modules
install :; foundryup && forge install

# setup foundry, install node modules and initialize husky
build :; forge build && yarn && yarn prepare

# Allow executable scripts
executable :; chmod +x scripts/*

# create an HTML coverage report in ./report (requires lcov & genhtml)
coverage :; forge coverage --no-match-path "test/fork/**/*.sol" --report lcov && genhtml lcov.info -o report --branch-coverage

# Run the slither container
analyze :; python3 analysis/remappings.py && ./analysis/analyze.sh

# run unit tests (and exclude fork tests)
test-unit :; forge test --no-match-path "test/fork/**/*.sol"

test-unit-gas :; forge test --no-match-path "test/fork/**/*.sol" --gas-report

# run unit tests in watch mode
test-unit-w :; forge test --no-match-path "test/fork/**/*.sol" --watch

# run only fork tests (and exclude unit)
# Note: this can take 10 - 20 minutes the first time you run it
test-fork :; forge test --match-path "test/fork/**/*t.sol"

# run all tests
test :; forge test

#### Deployment scripts ####

# MAINNET #

deploy-mainnet-sim :; forge script DeployAuxoProduction \
    --rpc-url ${RPC_URL} \
    -vvvv

deploy-mainnet :; forge script DeployAuxoProduction \
    --rpc-url ${RPC_URL} \
    --broadcast \
    --keystores ${KEYSTORE_PATH} \
    --verify \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    -vvvv

deploy-verifier-sim :; forge script DeployPRVVerifier \
    --rpc-url ${RPC_URL} \
    -vvvv

deploy-verifier-mainnet :; forge script DeployPRVVerifier \
    --rpc-url ${RPC_URL} \
    --broadcast \
    --keystores ${KEYSTORE_PATH} \
    --verify \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    -vvvv

deploy-upgradoor-sim :; forge script DeployUpgradoor \
    --rpc-url ${RPC_URL} \
    -vvvvv

deploy-upgradoor-mainnet :; forge script DeployUpgradoor \
    --rpc-url ${RPC_URL} \
    --keystores ${KEYSTORE_PATH} \
    --broadcast \
    --verify \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    -vvvvv

# TESTNETS AND FORKS #

# simulate a mainnet deployment with mocks for the Sharestimelock
mock-deploy :; forge script DeployAuxoLocal

# simulate a mainnet deployment against a remote fork
sim-deploy :; forge script DeployAuxoForked \
    --rpc-url ${RPC_URL} \
    --block-number 16632830 \
    -vvvvv

# deploy a local, persistent fork against which to run simulations
fork :; anvil --fork-url ${RPC_URL} --fork-block-number 16890699

# deploy to the persistent fork with real broadcast
# run make fork first, or use an alternative fork such as bestnet
sim-deploy-fork :; forge script DeployAuxoPersistentFork \
    --rpc-url http://127.0.0.1:8545 \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    -vvvvv

setup-dist :; chmod +x scripts/setup-distributors.sh && scripts/setup-distributors.sh

# adjusted command for bestnet deploy
deploy-bestnet :; forge script DeployAuxoPersistentFork \
    --rpc-url ${RPC} \
    --private-key ${PRIVATE_KEY} \
    --broadcast

# deploy to goerli and verify on goerli.etherscan
deploy-goerli :; forge script DeployGovernance \
    --rpc-url https://rpc.ankr.com/eth_goerli \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    --verify \
    -vvvv

# preview a deployment with transaction logs without actually posting Txs
sim-deploy-goerli :; forge script DeployGovernance \
    --rpc-url https://rpc.ankr.com/eth_goerli \
    -vvvv

deploy-fork :; forge script DeployGovernanceFork \
    --rpc-url $(RPC) \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    -vv


sim-deploy-upgradoor :; forge script DeployUpgradoor \
    --rpc-url ${RPC_URL} \
    -vvvvv

deploy-fork-remote :; forge script DeployAuxoPersistentFork \
    --rpc-url $(RPC) \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    --slow \
    -vv

deploy-oracle-goerli :; forge script DeployOracle \
    --rpc-url https://rpc.ankr.com/eth_goerli \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    --etherscan-api-key ${ETHERSCAN_API_KEY} \
    --verify \
    -vvvv


sim-deploy-fuji :; forge script DeployAuxoProduction \
    --rpc-url ${FUJI_URL}

deploy-fuji :; forge script DeployAuxoProduction \
    --rpc-url ${FUJI_URL} \
    --keystores ${KEYSTORE_PATH} \
    --broadcast \
    -vvvv

sim-activate-migration :; forge script ActivateMigration \
    --rpc-url ${RPC_URL} \
    -vvvvv

simulation :; forge script AuxoProtocolSimulation \
    --rpc-url ${RPC_URL} \
    --block-number 17046052

depositFor :; forge script DepositFor \
    --rpc-url ${FUJI_URL} \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    -vvvv
