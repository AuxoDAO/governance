# Auxo Governance

![Unit Tests][forge-test-status]
![Static Analysis][slither-test-status]

This is the repository for the Auxo governance contracts. It contains the following elements:

1. Locking mechanism
2. Auxo Token Implementation
3. On-chain governance contracts
4. Liquid Staking Derivative
5. Staking Contract without lockup
6. DecayOracle
7. MerkleDistributor with delegation
8. Upgrade contracts from veDOUGH

# Overview
What are you auditing in gist version is a governance system which main components are as follows:
| Contract Name                                     | InScope | Purpose                                                                                                                          |
|---------------------------------------------------|-------------|------------------------------------------------------------------------------------------------------------------------------|
| src/AUXO.sol                                      | YES         | ERC20 Token implementing permit and AccessControl                                                                            |
| src/ARV.sol                                       | YES         | Non-Transferable ERC20 used to represent the recepit of lock inside the TokenLocker and as governanve power in the Governor. |
| src/modules/governance/EarlyTermination.sol       | YES         | Base logic to allow the TokenLocker to terminate a lock early by making the user pay a penalty                               |
| src/modules/governance/Governor.sol               | YES         | The on-chain representation of the Auxo DAO, the governor manages the voting process                                         |
| src/modules/governance/IncentiveCurve.sol         | YES         | Implements an incentive curve mapping months of lock to a muliplier                                                          |
| src/modules/governance/Migrator.sol               | YES         | Base logic to make the TokenLocker migratable to a new version.                                                              |
| src/modules/governance/TokenLocker.sol            | YES         | It holds staked AUXO until a lock expires and mints ARV.                                                                     |
| src/modules/LSD/bitfield.sol                      | YES         | Library for efficiently setting epoch ranges as bitfields.                                                                   |
| src/modules/LSD/RollStaker.sol                    | YES         | Epoch-Based Staking contract that continues a user's position in perpetuity, until unstaked.                                 |
| src/modules/LSD/StakingManager.sol                | YES         | Contract Holding the lock for the PRV                                                                                        |
| src/modules/LSD/PRV.sol                           | YES         | Liquid Staking Derivative on ARV                                                                                             |
| src/modules/reward-policies/SimpleDecayOracle.sol |             | Simple Oracle computing the decay of a lock in the TokenLocker                                                               |
| src/modules/rewards/DelegationRegistry.sol        |             | Delegation Logic for the MerkleDistributor                                                                                   |
| src/modules/rewards/MerkleDistributor.sol         | YES         | MerkleDistributor contract. Allows an owner to distribute any reward ERC20 with Merkle roots.                                |
| src/modules/vedough-bridge/Upgradoor.sol          |             | Contract to Upgrage veDOUGH Locks to either xAuxo or ARV                                                                     |

# Auxo Contracts Setup

Auxo runs on [Foundry](https://github.com/foundry-rs/foundry). If you don't have it installed, follow the installation instructions [here](https://book.getfoundry.sh/getting-started/installation).

Ensure you have nodejs, yarn and [foundry](https://book.getfoundry.sh/getting-started/installation) installed. Docker is recommended for locally running static analysis.

You can install dependencies with the following command:

```sh
forge build && yarn
```

# Deploying

## Environment

Private environment variables should be set in a `.env` file in the root of the project. Copy the `.env.example` file to `.env` and fill in the values, don't commit this file to source control.
Public parameters for E2E deployment scripts are in the [parameters](./script/parameters/) folder. These have defaults set but if you're doing a fresh deployment, give them a careful read as most have
major implications for protocol security and resilience. If changing parameters for a new deploy, please copy the latest file and commit to source control for easy reference.

## Forge Scripts

Deployment scripts are found in the [scripts](./scripts) directory. `forge script $CONTRACT` will run a script, but you'll need certain parameters to be set. Check out the [makefile](./Makefile) for examples.

Importantly, you can preview a script *without running it* by excluding the `--broadcast` flag. This is a great way to test out a deployment before committing to it. `make sim-{command}` are examples of deploy scripts that will just show transaction validity and previewed stack traces.

# Verifying

Etherscan can sometimes fail to verify and it can be challenging to verify a deployed contract. Here are the steps I recommend to verify contracts:

1. Use `--verify` in forge scripts that deploy new contracts. Generally the easiest way to get automatic verifcation. You will need an `--etherscan-api-key` flag set.

2. If `--verify` times out, run the script again with the `--resume` flag added. This will not do a new deploy but will instead attempt to reverify. In some cases, with different block explorers under different loads, it can require waiting up to 30 minutes post-deployment.

3. If `--resume` does not work, you can use `forge verify-contract`. This is a tricky command to get right. Let's look at 2 working examples:

```sh
forge verify-contract 0x32C68cbe73473053A4A73D09a90f23296cC69bFf Auxo $ETHERSCAN_API_KEY --chain goerli --watch
```
This script verifies the contract inside `src` named `Auxo` at address `0x32C...Ff`. The name Auxo must be unique, if not we need to specify the exact path to the contract with `[path]:[name]` (for example `src/AUXO.sol:Auxo`).

There are no constructor arguments, but the network we are using is `goerli`, which is defined in the `[etherscan]` section of our `foundry.toml`:

```
[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
goerli = { key = "${ETHERSCAN_API_KEY}", chain_id = "5", url = "https://api-goerli.etherscan.io/" }
```
> Note the .env var `ETHERSCAN_API_KEY`

Finally, the `--watch` param will keep the process from exiting until it receives confirmation from the etherscan server, or hits a timeout.


A more tricky example is this:

```sh
export CONTRACT_PATH="lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

forge verify-contract 0x05fc909dFca9d4f256A628C15f2c2540Db8c0e00 \
    $CONTRACT_PATH:TransparentUpgradeableProxy $ETHERSCAN_API_KEY \
    --chain goerli \
    --constructor-args-path args.txt \
    --watch
```
Here, we've deployed a proxy from a library, so we need to pass the full path to the library.

Secondly, this contract was deployed with arguments. I've found the easiest way to pass such args is to create a temp file in the root directory `args.txt` that looks like:

```
0x841Ef4B35a26e2E9d46E32F174a05ca772dfDF09 0xB0509dcf35D1683e398BB42069Dc19aC472747ea 0x
```


# CI

Continuous integration is setup via [Github actions](./.github/workflows/run-tests.yml). The following checks are run:
- Run the test suite with `forge test`

# Conventions

Below are a list of recommended conventions. Most of these are optional but will give a consistent style between contracts.

## Formatting

Formatting is handled by `forge fmt`. We use the default settings provided by foundry.
You can enable format on save in your own editor but out the box it's not setup. The CI hook will reject any PRs where the formatter has not been run.

A small `.editorconfig` file has been added that standardises things like line endings and indentation, this matches `forge fmt` so the style won't change drastically when you save.

## Linting

`solhint` is installed to provide additional inline linting recommendations for code conventions. You must have NodeJS running for it to work.

## Imports and Remappings

We use import remappings to resolve import paths. Remappings should be prefixed with an `@` symbol and added to `remappings.txt`, in the format:

```txt
@[shortcut]/=[original-path]/
```

For example:

```txt
@solmate/=lib/solmate/src/
```

> Remappings may need to be added in multiple config files so that they can be accessed by different tools. For Slither, run `python3 analysis/remappings.py` to add the existing remappings to a `slither.config.json` file.

# Tests

> **Note**
> ARV was orginally named "veAUXO", PRV was originally named "xAUXO" and referred to as "LSD" (Liquid Staking Derivative). These names have been changed in the src files but you may see the old names crop up in tests and old scripts. Please feel free to update if you are working on the same file.


Run tests - recommended to just run unit tests for speed. Fork tests can be run but will take a lot longer.
```sh
# unit tests only
make test-unit
```
Invariant tests are available for some contracts, it's recommended to increase the number of runs in `foundry.toml` when running invariants to give foundry a chance to properly test all possibilities.

```sh
# in foundry.toml
[invariant]
runs = 10000 # increase temporarily from 256, DO NOT COMMIT

# run invariants
make test-invariant
```

Fetch coverage and print to a coverage report in `/report`
```
make coverage
```
# Static Analysis

You can perform static analysis on your contracts using [Slither](https://github.com/crytic/slither). This will run a series of checks against known exploits and highlight where issues may be raised.

## Installing

Slither has a number of dependencies and configuration settings before it can work. You are welcome to install these yourself, but the Dockerfile will handle all of this for you.

There is also an official [Trail of Bits security toolkit](https://github.com/trailofbits/eth-security-toolbox/) you can use, we will not go into detail here.

Both the toolkit and the Dockerfile require docker to be installed. I also recommend you run docker using WSL if you're using Windows.

## Running the Container

The Dockerfile installs dependencies and creates a `/work` directory which mounts the current working directory.
```sh
# run the docker command
make analyze
```
The analyze script builds and runs the container before dropping you into a shell. You can run slither from there with the `slither` command. You may need to change the solidity compiler you are using, in which case run `solc-select` to get a list of options for installing and selecting specific compilers.

## Addressing issues

CI will fail on unaddressed 'high' or 'medium' issues. These can either be ignored by adding inline comments to solidity files OR using the `--triage-mode` flag provided by slither.

An example inline comment:

```js
function potentiallyUnsafe(address _anywhere) external {
    require(_anywhere == trusted, "untrusted");
    // potentially unsafe operation is ignored by static analyser because we whitelist the call
    // without the next line, the CI will fail
    // slither-disable-next-line unchecked-transfer
    ERC20(_anywhere).transfer(address(this), 1e19);
}
```

# References

Config Reference for Foundry:

- https://book.getfoundry.sh/reference/config/
