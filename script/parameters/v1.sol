pragma solidity ^0.8.0;

/**
 * @dev version 1
 * A collection of constants that are used in the auxo protocol that can be known ahead of time.
 * Import these into deployment scripts and commit a new version for easy reference.
 * Convention is to use {CONTRACT}_{PARAM} for the constant name.
 *
 * Note: foundry does have support for env variables and JSON, but we have opted for a config file in solidity:
 *       - Env files are more suited to sensistive data that we do not commit to the repo
 *       - JSON would be good, but the foundry JSON utilities require very careful ordering of keys, or will
 *         incorrectly decode the values, which seems too dangerous for critical parameters.
 */

/// @dev utility constant used across several contracts.
uint32 constant AVG_SECONDS_MONTH = 2628000; // do not change

/**
 * ------------- @dev TRUSTED ADDRESSES -------------
 *
 *      Here we define important addresses in the deployment of the new protocol.
 *      These include multisigs and governance addresses.
 */

/// @dev Gnosis safe that holds majority of DAO funds
address constant MULTISIG_TREASURY = 0x3bCF3Db69897125Aa61496Fc8a8B55A5e3f245d5;

/// @dev Gnosis safe that interacts with smart contracts for operations
address constant MULTISIG_OPS = 0x6458A23B020f489651f2777Bd849ddEd34DfCcd2;

/**
 * ----------- @dev GOVERNANCE PARAMS ------------
 *      These are the initial settings for the OpenZeppelin Governor contract.
 *      Many of them can be changed by the governance contract itself, but will
 *      require a proposal and vote to do so.
 */

/// @dev the delay between a proposal being created and it being able to be voted on, in blocks
///      13140 default is taken from Compound finance ~= 44 hours
uint256 constant GOV_VOTING_DELAY_BLOCKS = 13140;

/// @dev the duration of a proposal in blocks
uint256 constant GOV_VOTING_PERIOD_BLOCKS = 50000; // 7 days

/// @dev the minimum amount of tokens that must be staked to create a proposal, in wei
uint256 constant GOV_MINIMUM_TOKENS_PROPOSAL = 10000 ether;

/// @dev the minimum percentage of tokens that must vote to pass a proposal, in whole percent
uint256 constant GOV_QUORUM_PERCENTAGE = 5;

/// @dev delay between vote passing and ability to execute through timelock controller IN SECONDS
uint32 constant GOV_TIMELOCK_DELAY_SECONDS = 1 days;

/// @dev who can call execute on timelock controller, zero address is anyone
address constant GOV_TIMELOCK_EXECUTOR_ADDRESS = address(0);

/// @dev admin can circumvent gov delays on the timelock, useful in post-deploy operations, or can be set to zero
address constant GOV_TIMELOCK_ADMIN_ADDRESS = MULTISIG_OPS;

/* --------- @dev AUXO token params ---------- */

/// @dev the initial mint of auxo to the multisig treasury
uint256 constant AUXO_TREASURY_INITIAL_MINT = 0 ether;

/* --------- @dev LSD token params ---------- */

/// @dev the fee to mint PRV, where 10 ** 18 is 100%
uint256 constant PRV_FEE = 10 ** 16; // 1%

/// @dev the recipient of LSD mint fees
address constant PRV_FEE_BENEFICIARY = MULTISIG_TREASURY;

/* --------- @dev TOKEN LOCKER PARAMS ---------- */

/// @dev recipient of principal for early exit from ARV -> PRV
address constant LOCKER_EARLY_EXIT_PENALTY_BENFICIARY = MULTISIG_TREASURY;

/// @dev percentage of principal to be sent to EARLY_EXIT_PENALTY_BENFICIARY
uint256 constant LOCKER_EARLY_EXIT_PENALTY_PERCENTAGE = 2 * (10 ** 17); // 20%

/// @dev the address that should have the compounder role in the locker
address constant LOCKER_COMPOUNDER = MULTISIG_OPS;

/// @dev the minimum duration of a lock, in seconds
uint32 constant LOCKER_MIN_LOCK_DURATION = 6 * AVG_SECONDS_MONTH;

/// @dev the maximum duration of a lock, in seconds
uint32 constant LOCKER_MAX_LOCK_DURATION = 36 * AVG_SECONDS_MONTH;

/// @dev the minimum amount of tokens that can be locked, in wei
uint192 constant LOCKER_MIN_LOCK_AMOUNT = 1 gwei;

/// @dev the veDOUGH whitelisted smart contract for jailwarden.eth
address constant LOCKER_WHITELISTED_SMART_CONTRACT = 0xEa9f2E31Ad16636f4e1AF0012dB569900401248a;

/* --------- @dev RollStaker Params ---------- */

/// @dev the operator for the rollstaker
address constant ROLLSTAKER_OPERATOR = MULTISIG_OPS;

/* --------- @dev Upgradoor params ---------- */

/// @dev the address of the old shares timelock contract that locks veDOUGH
address payable constant UPGRADOOR_OLD_TIMELOCK = payable(0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45);

/// @dev PieDAO tokens
address constant DOUGH = 0xad32A8e6220741182940c5aBF610bDE99E737b2D;
address constant VEDOUGH = 0xE6136F2e90EeEA7280AE5a0a8e6F48Fb222AF945;
