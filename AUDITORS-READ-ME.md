Welcome fellow bug-seeker, breaker of contracts.

# Audit Scope
| Contract Name                                     | Audit Scope | Purpose                                                                                                                      |
|---------------------------------------------------|-------------|------------------------------------------------------------------------------------------------------------------------------|
| src/AUXO.sol                                      | YES         | ERC20 Token implementing permit and AccessControl                                                                            |
| src/veAUXO.sol                                    | YES         | Non-Transferable ERC20 used to represent the recepit of lock inside the TokenLocker and as governanve power in the Governor. |
| src/modules/governance/EarlyTermination.sol       | YES         | Base logic to allow the TokenLocker to terminate a lock early by making the user pay a penalty                               |
| src/modules/governance/Governor.sol               | YES         | The on-chain representation of the Auxo DAO, the governor manages the voting process                                         |
| src/modules/governance/IncentiveCurve.sol         | YES         | Implements an incentive curve mapping months of lock to a muliplier                                                          |
| src/modules/governance/Migrator.sol               | YES         | Base logic to make the TokenLocker migratable to a new version.                                                              |
| src/modules/governance/TokenLocker.sol            | YES         | It holds staked AUXO until a lock expires and mints veAUXO.                                                                  |
| src/modules/LSD/bitfield.sol                      | YES         | Library for efficiently setting epoch ranges as bitfields.                                                                   |
| src/modules/LSD/RollStaker.sol                    | YES         | Epoch-Based Staking contract that continues a user's position in perpetuity, until unstaked.                                 |
| src/modules/LSD/StakingManager.sol                | YES         | Contract Holding the lock for the xAUXO                                                                                      |
| src/modules/LSD/xAUXO.sol                         | YES         | Liquid Staking Derivative on veAUXO                                                                                          |
| src/modules/reward-policies/SimpleDecayOracle.sol |             | Simple Oracle computing the decay of a lock in the TokenLocker                                                               |
| src/modules/rewards/DelegationRegistry.sol        |             | Delegation Logic for the MerkleDistributor                                                                                   |
| src/modules/rewards/MerkleDistributor.sol         | YES         | MerkleDistributor contract. Allows an owner to distribute any reward ERC20 with Merkle roots.                                |
| src/modules/vedough-bridge/Upgradoor.sol          |             | Contract to Upgrage veDOUGH Locks to either xAuxo or veAUXO                                                                  |

## Overview
What are you auditing in gist version is a governance system which main components are as follows:

**Elements:**
1. `AUXO`: The base ERC-20 token of the Auxo DAO, it can be freely transfered and holds no voting power, but it can be staked to veAUXO or exchanged for a liquid staking derivative xAUXO.
2. `veAUXO`: Voting Escrowed Auxo, it cannot be transfered and can only be acquired as a receipt of locking Auxo from 6 - 36 months in the `TokenLocker` contract. veAUXO confers voting power on its holder at a rate of 1 vote = 1 veAUXO token and also keeps track of *delegation.* (oz-governor)
3. `TokenLocker`: The contract with exclusive control of the veAUXO supply (the only actor able to burn and mint veAUXO). It holds staked AUXO until a lock expires and the user is able to burn veAUXO and withdraw AUXO.
4. `Governor`: the on-chain representation of the Auxo DAO, the governor manages the voting process **and tallies the votes for, against, and abstaining from active proposals.
5. `TimelockController`: a separate contract to the governor which is in charge of actually executing proposals that have passed voting.
6. `xAUXO`: a transferable derivative of veAUXO. It's a one way conversion, once deposited in xAUXO there is no coming back. xAUXO holders are required to be staked, see RollStaker, in the epoch to be counted for rewards (offchain calculation). The xAUXO contract is designed to be as simple as possible, it's basically a receipt, the actual staking logic is handled in the StakingManager

## Contract Breakdown

---

Here are some additional technical notes about governance I felt were relevant.

### `ARV.sol`

- Checkpoints: units of time from when voting becomes active
    - Votes become active 1 block after delegation
    - Binary search iterates through the length of checkpoints
- Delegation: activation of checkpoints
    - Delegation writes a checkpoint, which says when the vote is active
    - You can delegate to yourself
    - Alternatively, you can delegate to another, in which case your `getVotes` will return zero, and the delegatee will have `getVotes` increased
    - Users must self-delegate and vote to be eligible for rewards. If the user wishes to be a passive investor, use xAUXO

### `TockenLocker.sol`

Some behavious are defined in contracts where are then extende by the TockenLocker, as for now it is:

- Terminatable (early unlock with penalty)
- Migrateable

- Lock:
    - Only one lock is allowed per address
    - Only EOAs can lock unless whitelisted

- As a User, once locked you can:
    - increase the amount of staked tokens
    - increase the number of months you are locked for (until <= max)
    - withdraw after the lock is expires
    - boost your lock to maxTime
    - Decide to terminate the lock early, pay the penalty and exit the LiquidStakingDerivative

- Others can:
    - increase the amount of staked tokens (gift)
    - eject expired locks (if over ejectBuffer)

- As an Admin you can:
    - Set the minimum lock amount that can be locked
    - Whitelist contracts to allow them to be depositors
    - Trigger the emergency unlock
    - Set the time allowed after a lock expires before anyone can eject it
    - Set the address the Early termination will use
    - Set the address the Early termination Fee
    - Set the Migrator Address (a contract designed to migrate positions)

### `RollStaker.sol`

Epoch-Based Staking contract that continues a user's position in perpetuity, until unstaked.
A user can deposit in this epoch, and when the next epoch starts, these deposits will be added to their previous balance. Users can remove tokens at any time, either from pending deposits, current deposits or both.
The whitelisted operators of the contract are responsible for advancing epochs, there is no time limit.

*This contract does not calculate any sort of staking rewards which are assumed to be computed either off-chain or in secondary contracts.*

Epochs:
- the contract can store information for up to 256 epochs.
- assuming a 1 month epoch, this will cover just over 21 years.

- As a User you can:
    - Deposit tokens to the NEXT epoch
    - Withdraw your token any time (no lock)
    - Withdraw tokens up to the total balance the user
    - Withdraw any tokens newly deposited in the next epoch, without affecting the current staking.

- As an Admin you can:
    - Move to the next epoch. (The balance at the end of the previous epoch is rolled forward.)
    - Pause
    - Unpause

## Onchain Governance
The implementation of on-chain governance is based on `oz-governor` and unchanged.

### `TimelockController.sol`

- Administrative Roles
    - Proposers
        - proposers have exclusive access to the `schedule` and `scheduleBatch` functions
        - The governor is the only proposer (although anyone can make proposals on the governor itself)
    - Executors
        - Can be zero address in which case, this role is open
    - Super Admin
        - Can grant roles
        - This is  `TIMELOCK_ADMIN_ROLE` which replaces the `DEFAULT_ADMIN_ROLE` in OZ
    - Cancellors
        - Can remove a scheduled proposal before execution
        - By default, proposers are also cancellors
- Scheduling vs. execution
    - Timelock can only `execute` a proposal whose `id` is stored in the `_timestamps` mapping
- Delay in block.timestamp
- Tracks post vote-delay
- Executes transactions - restricted to executor

### `Governor.sol`

- Create proposals
- Track proposals
    - State
    - Votes for/against/abstain on proposals
- Track wider governance params
    - Voting token
    - Quorum
    - Delegation Delay
- Executes transactions to the timelockcontroller **but does not execute transactions themselves**

**Relevant Sub Components of Governor:**

- `GovernorTimelockControl`: Extends the Base Governor contract to work with the TimelockController for execution
    - Adds `queue` `proposalEta` and `timelock` to the Governor contract
- `GovernorSetttings`
    - sets voting delay, period, and proposal threshold
- `GovernorCountingSimple`
    - vote options are FOR / ABSTAIN & AGAINST
    - 1 veAUXO = 1 vote
- `GovernorVotes`
    - Read voting weight from the veAUXO token
- `GovernorVotesQuorumFraction`
    - Allows adjusting minimum quorum of votes (FOR + ABSTAIN) needed for a vote to be valid

**Governor Params:**

- voting delay and delegation - blocks
    - When voting starts and how users have time to adjust voting power
- voting period - blocks
    - How long the vote lasts
- proposal threshold
    - Min veAUXO to create a new vote
- Quorum
    - percent of votes a proposal needs to reach (of total voting power) before a proposal is considered valid.
    - the `quorum` getter returns an absolute number of votes
    - both FOR and ABSTAIN votes count towards the quorum
    - AGAINST don’t technically count
    - Example:
        - Quorum 20 votes
            - 10 votes FOR
            - 8 abstain
            - 6 against
            - Remainder non voting
            - FOR > AGAINST but Quorum not reached
            - Vote cannot be proposed
        - Quorum 20 votes
            - 15 FOR
            - 5 abstain
            - 10 against
            - FOR > AGAINST, FOR + ABSTAIN > Quorum
            - Quorum reached vote can be proposed

# Acknowledgements

## Tokenlocker
- The contract is Upgradable
- we use uint32 for block.timestamp, meaning the contract will only work until Sun Feb 07 2106 06:28:15 GMT+0000
- Any amount which does not result into at least a 1 wei increase in veToken will revert, this is because the multiplier will return zero new veTokens if < 13 wei.


## Rollstaker
- We use uint8 for epochs, meaning only 254 epoch are available, roughly 21.5y considering 1 epoch per month.
- The contract is Upgradable
- The contract can be paused and actions such as withdraw would not work
- There is an `emergencyWithdraw` function which can withdraw all tokens under admin control.

## StakingManager
- The contract is Upgradable

## MerkleDistributor
- The contract is Upgradable
- Admin can pause the contract
- Admin can withdraw rewards
- Admin can lock the pool using `setLock` potentially forever.


# Audits

The below are responses to the findings raised by Quantstamp Audits in 2023 that the Auxo team believe do not require code changes.

## Quantstamp April 2023

### AUX2-1 Privileged Roles and Ownership

In line with Quantstamp recommendations, we acknowledge that the following contracts have privileged roles and ownership, and users should therefore be aware that they are not fully trustless:

* `PRVMerkleVerifier.sol`

### AUX2-2 Missing Input Validation

We acknowledge that `_endBlock`, `_maxAmount` and `_merkleRoot` are not validated when setting windows on the `MerkleVerifier`.

As setting windows is an administrative function, we are happy to leave the inputs without contract-level validation - presuming that responsibility for checking the validity of these variables lies with the admin and any other operational checks and balances.

### AUX2-3 No Guarantee for Successful Withdraw with Valid Claim

Quantstamp notes that, with the current design, claims may exceed the `maxAmount` of a window. Quantstamp also notes that this is a constraint of the merkle root design, and cannot be enforced in code with the current design.

As with AUX2-2, we assume that contract owners will ensure that claims can be processed within the `maxAmount` of a window.

### AUX2-4 Multiple Claims for One Account per Window Have to Contain Cumulative Amounts

Quantstamp notes that if a user is issued multiple *claims* in the *same window* then there is a potential problem that they will not be able to fully withdraw.

This is because `amountWithdrawnFromWindow` is a nested mapping of `windowIndex` and `adddress`, so in the event that an account has multiple claims, they will only be able to withdraw a total equal to the highest single value across all claims.

We acknowledge this is by design: accounts are only intended to have one claim per window, but can make partial claims if they wish. We also acknowledge that this limitation is not enforced anywhere in the contract and is up to the generator of the merkle tree to avoid adding duplicate accounts in claims for the window.

### AUX2-5 Previous Window Can Still Be Active when Overwritten

We acknowledge that it is possible to overwrite an active window when calling the `setWindow` function. We also acknowledge that this would affect any users and claims in the overwritten window.

As with AUX2-2, we rely on contract owners to understand the implications of the `setWindow` function and choose inputs accordingly.

## Quantstamp Feb 2023

### QSP-3 Unclear Economic Incentive for xAUXO Liquid Staking

QSP-3 was raised as high severity due to the fact that the xAUXO/PRV does not have a withdraw mechanism, and, consequently, there is no guarantee of price parity between AUXO/PRV. The comparison was made between staking derivatives between ETH and stETH, where the price is dictated by the ability of the token to be redeemed for ETH at some later date.

On the other hand, there are other staking derivatives, with significant TVL and application across DeFi, that utilise one-way staking derivatives and no guarantee of price pegging. Examples of such protocols include veCRV/cvxCRV (Curve and ConvexCurve), and Balancer/AURA finance.

The Auxo team feel that, because such protocols have been successful without offering a price peg, this particular issue is incorrectly flagged as high severity when it should be considered 'informational', and communicated clearly to users. Additionally, the DAO has plans to allocate resources to xAUXO/PRV buybacks, which, while still to be confirmed, are aiming to give xAUXO holders opportunities to exit their positions.

### QSP-6 Privileged Roles and Ownership

In line with Quantstamp recommendations, we acknowledge that the following contracts have privileged roles and ownership, and users should therefore be aware that they are not fully trustless:

* EarlyTermination.sol
* TokenLocker.sol
* MerkleDistributor.sol
* RollStaker.sol
* AUXO.sol
* xAUXO.sol
* StakingManager.sol

### QSP-7 Input Validations

Quantstamp correctly notes that some variables do not have validations for null checks or known erroneous values. We subdivide these errors into:

- Initialization validation: missing validations during contract deployment and/or initialization
- Runtime validation: missing validations for values that can be changed over the contract lifetime

For **initialization validation**, we acknowledge the risks, instead opting for runtime, pre and post deploy health checks to ensure all variables are set as expected. These health checks are in the form of foundry scripts, although they have not themselves been subject to a formal audit. The scripts cover the following issues raised:

* StakingManager.sol: all values
* Governor.sol: all values
* RollStaker.sol: all values
* TokenLocker: min duration, max duration, min lock amount

For **runtime validation**, here are the specific comments:

* Migrator.sol.setMigrationEnabled: covered by deploy scripts mentioned above
* TokenLocker.sol.setXAuxo: covered by deploy scripts and not expected to change
* xAuxo.sol.setEntryFee/constructor: risk of setting fee without beneficiary is bourne by operator
* EarlyTermination.sol.setPenaltyBeneficiary: risk of setting incorrect address is bourne by operator
* MerkleDistribution.sol.setLock: risk of setting incorrect block number is bourne by operator

The following 3 cases were flagged for missing validation but have reverts further down the call stack:

* TokenLocker.sol.depositByMonths: veAUXO reverts on mint to Zero Address
* TokenLocker.sol: getDuration(months) is called in depositByMonts, and increaseByMonths. Both these functions validate the passed months inside `getLockMultiplier`.
* xAUXO._depositAndStake: _account will revert if minting to the zero address as it is OpenZeppelin

### QSP-8 Ownership and Roles Can Be Renounced/Revoked

In line with Quantstamp recommendations, we acknowledge that the following contracts have access controls that can be renounced or revoked, potentially leaving some functions unable to be executed:

* EarlyTermination.sol
* TokenLocker.sol
* MerkleDistributor.sol
* RollStaker.sol
* xAUXO.sol
* StakingManager.sol
* Migrator.sol
* AUXO.sol

### QSP-11 Eject Functionality May Harm Interacting Contracts

Quantstamp notes that the TokenLocker has an eject function that allows anyone to force a user to exit their stake, after a grace period. It is argued that this behaviour may be unexpected for ARV/veAUXO holders that are also smart contracts.

Acknowledging this, we have added a note to the ITokenLocker interface and to the veAUXO contract, to remind developers. Furthermore, smart contracts must be whitelisted before they can deposit into the TokenLocker, so it is expected that the AUXO team will have a reasonable chance of conveying this behaviour during development.

### QSP-13 Only the Rollstaker Admin Can Activate the Next Epoch

Quantstamp notes that the RollStaker does not automatically activate the next epoch nor does it have any sort of time range for how long an epoch is. Further, only the admin of the RollStaker can activate the next epoch.

We confirm that it is intended behaviour **not** to encode specific epoch timings into the RollStaker.

This was a deliberate design decision made to align the RollStaker's concept of epochs with existing processes for distributing rewards in the MerkleDistributor.


### QSP-14 The StakingManager Should Not Be Ejectable

Quantstamp recommends that the StakingManager should be blacklisted from ejection from the TokenLocker, noting:

> The StakingManager contract holds the lock of AUXO in the TokenLocker on behalf of the xAUXO contract, the liquid staking version of the AUXO token. Given that the token is intended to be an irreversible conversion of the token, this contract should not be ejectable, as else the depositors would hold both the token and the token from their deposit.

Quantstamp also notes that the option to renew the stakingManager's lock is available to any user, and that, therefore it is a "very unlikely scenario that the lock will run out unnoticed" over the course of 36 months.

We therefore acknowledge this minor risk of forgetting to re-boost the staking manager, additionally we note that the staking manager should potentially be ejectable if it is decided to decommission the manager - a code upgrade would be needed here to remove the public `boostToMax` function.

### QSP-15 Unnecessary COMPOUNDER_ROLE

Quantstamp notes that the TokenLocker contract has a COMPOUNDER_ROLE, which is used only to restrict `increaseAmountsForMany` to the compounder, but asks why the role exists, given that same functionality can be achieved with repeated calls to `increaseAmountFor`.

`increaseAmountsForMany` was envisioned to be a utility method used by a to-be-developed compounding vault for ARV/veAUXO. Initially, we saw no harm in making it public and adding the same modifier functionality inside the for-loop. However, static analysis highlighted that there is a potential reentrancy attack due to state changes in between looped calls to `veToken.mint()` and the final `depositToken.safeTransferFrom` after the loops had completed. If, somehow, an attacker is able manipulate the control flow before the final `safeTransferFrom` is called, then they could have additional reward tokens without having to pay the deposit tokens.

While we couldn't define a specific exploit scenario, we decided to make the function permissioned as a precautionary measure, especially as we see a low likelihood of regular users needing it.

### QSP-16 Funds Locked by StakingManager Are Not 1:1 Pegged to xAuxo

Quantstamp acknowledges that the AUXO balance of the Staking Manager is not a reliable indicator of the xAUXO balance of the Staking Manager, and that the Staking Manager's AUXO balance may stray from the total xAUXO in the system due to the fact that the Staking Manager may have received AUXO from ERC20 transfers.

As recommended we formally acknowledge this risk. A comment has been added to the staking manager to make it clear.

### QSP-18 Quorum Denominator Cannot Be Adjusted Later

Quantstamp correctly identified a misunderstanding on the contract author's part: that OpenZeppelin governance's quorum denominator is not adjustable.

Having re-reviewed the documentation, we are happy to leave the default behaviour in place, with the deonomicator set to 100 - we have adjusted the comment to reflect this.
