# RollStaker
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/RollStaker.sol)

**Inherits:**
[IRollStaker](/src/modules/PRV/RollStaker.sol/interface.IRollStaker.md), AccessControl, Pausable, ReentrancyGuard

Staking contract that continues a user's position in perpetuity, until unstaked.

*Staking is based on epochs: the contract can store information for up to 256 epochs.
- assuming a 1 month epoch, this will cover just over 21 years.
A user can deposit in this epoch, and when the next epoch starts, these deposits will be
added to their previous balance. Users can remove tokens at any time, either from pending deposits,
current deposits or both.
The admin/owner of the contract is soley responsible for advancing epochs, there is no time limit.
This contract does not calculate any sort of staking rewards,
which are assumed to be computed either off-chain or in secondary contracts.*


## State Variables
### OPERATOR_ROLE
operators can increment epochs and pause/unpause the contract


```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```


### stakingToken
the token to be staked in the contract. Set during initializer.


```solidity
IERC20 public stakingToken;
```


### currentEpochId
the current epoch ID


```solidity
uint8 public currentEpochId;
```


### epochBalances
list of historical epoch balances by epoch Id


```solidity
uint256[] public epochBalances;
```


### epochPendingBalance
the current quantity of tokens pending activation next epoch


```solidity
uint256 public epochPendingBalance;
```


### userStakes
contains information about each user's staking positions


```solidity
mapping(address => UserStake) public userStakes;
```


### __gap
*reserved storage slots for upgrades*


```solidity
uint256[50] private __gap;
```


## Functions
### nonZero


```solidity
modifier nonZero(uint256 _amount);
```

### constructor

*disable initializers in implementation contracts*


```solidity
constructor();
```

### initialize


```solidity
function initialize(address _stakingToken) external initializer;
```

### getProjectedNextEpochBalance

based on current deposits, what will be the number of tokens earning staking rewards starting next epoch.

*assumes no further deposits or withdrawals. Use this function instead of fetching next epoch directly.*


```solidity
function getProjectedNextEpochBalance() public view returns (uint256);
```

### getCurrentEpochBalance

epoch balance of the contract right now


```solidity
function getCurrentEpochBalance() external view returns (uint256);
```

### getEpochBalanceWithProjection


```solidity
function getEpochBalanceWithProjection(uint8 _epochId) external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance of staking tokens at a given epochId. if passed future epoch, will return a projection.|


### getEpochBalances

fetch the epoch balances array 'as-is', with no projections


```solidity
function getEpochBalances() external view returns (uint256[] memory);
```

### getTotalBalanceForUser

fetches the total user balance locked in the contract, including pending deposits


```solidity
function getTotalBalanceForUser(address _user) public view returns (uint256);
```

### getPendingBalanceForUser

gets staked tokens currently pending and not earning rewards for the user

*this will be zero if the last written to epoch is not the current epoch*


```solidity
function getPendingBalanceForUser(address _user) public view returns (uint256);
```

### getActiveBalanceForUser

gets staked tokens currently active and earning rewards for the user

*if the last written to epoch is the current epoch
the user has pending deposits which we exclude.*


```solidity
function getActiveBalanceForUser(address _user) public view returns (uint256);
```

### getUserStakingData

fetches the user's stake data into memory


```solidity
function getUserStakingData(address _user) public view returns (UserStake memory);
```

### getActivations

return the bitfield of activations


```solidity
function getActivations(address _user) external view returns (Bitfields.Bitfield memory);
```

### userIsActive

is the user currently active


```solidity
function userIsActive(address _user) external view returns (bool);
```

### userIsActiveForEpoch

was the user active for a particular epoch


```solidity
function userIsActiveForEpoch(address _user, uint8 _epoch) external view returns (bool);
```

### lastEpochUserWasActive

starting from current epoch, returns the last epoch in which the user was active


```solidity
function lastEpochUserWasActive(address _user) external view returns (uint8);
```

### deposit

lock staking tokens into the contract, can be removed at any time. Must approve a transfer first.
Deposits will be added to the NEXT epoch, and the user will be eligible for rewards at the end of it.

*will set the user as active for all future epochs if not already, no need to restake.*


```solidity
function deposit(uint256 _amount) external nonReentrant whenNotPaused nonZero(_amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|the amount of tokens to deposit, must be > 0|


### depositFor

sender deposits on behalf of another `_receiver`. Tokens are taken from the sender.


```solidity
function depositFor(uint256 _amount, address _receiver) external nonReentrant whenNotPaused nonZero(_amount);
```

### depositWithSignature

make a gasless deposit using EIP-712 compliant permit signature for approvals


```solidity
function depositWithSignature(uint256 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s)
    external
    nonReentrant
    whenNotPaused
    nonZero(_amount);
```

### depositForWithSignature

sender deposits on behalf of another `_receiver`. Tokens are taken from the sender.


```solidity
function depositForWithSignature(uint256 _amount, address _receiver, uint256 _deadline, uint8 v, bytes32 r, bytes32 s)
    external
    nonReentrant
    whenNotPaused
    nonZero(_amount);
```

### _depositFor

*actions the deposit for the receiver on behalf of the sender*


```solidity
function _depositFor(uint256 _amount, address _receiver) internal;
```

### quit

removes the user's staked tokens from the contract, including pending deposits next epoch.


```solidity
function quit() external;
```

### withdraw

withdraw tokens from the contract. This can only be called by the depositor.

*If withdrawing all tokens, the user will be set as inactive*


```solidity
function withdraw(uint256 _amount) public nonReentrant whenNotPaused nonZero(_amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|amount to withdraw, cannot be zero and must be <= user's total deposits|


### _exit

*reset user's position, deactivate and transfer all tokens*


```solidity
function _exit(UserStake storage _u) internal;
```

### _withdraw

internal function to action withdrawal once paramaters checked.

*this function assumes < the full balance is being withdrawn.
if the full balance is being withdrawn, use _exit*


```solidity
function _withdraw(uint256 _amount, UserStake storage _u) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|to withdraw, assumed to be valid|
|`_u`|`UserStake`|storage pointer to the user withdrawal data|


### _resetPendingIfEpochHasPassed

*if the last time we saw the user was in a past epoch
then we need to move their pending balance to active
and reset the pending balance.*


```solidity
function _resetPendingIfEpochHasPassed(UserStake storage _u) internal;
```

### activateNextEpoch

move to the next epoch. The balance at the end of the previous epoch is rolled forward.


```solidity
function activateNextEpoch() external onlyRole(OPERATOR_ROLE);
```

### pause

see OpenZeppelin Pauseable


```solidity
function pause() external onlyRole(OPERATOR_ROLE);
```

### unpause


```solidity
function unpause() external onlyRole(OPERATOR_ROLE);
```

### emergencyWithdraw

withdraws all of the deposited staking tokens from the contract

*this function can be called even when the contract is paused, but must be called by the admin.*


```solidity
function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE);
```

