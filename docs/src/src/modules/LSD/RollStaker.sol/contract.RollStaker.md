# RollStaker
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/LSD/RollStaker.sol)

**Inherits:**
[IRollStaker](/src/modules/LSD/RollStaker.sol/contract.IRollStaker.md), AccessControl, Pausable, ReentrancyGuard

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
the token to be staked in the contract. Set during contract deploy.


```solidity
IERC20 public immutable stakingToken;
```


### userStakes
contains information about each user's staking positions


```solidity
mapping(address => UserStake) public userStakes;
```


### epochBalances
list of historical epoch balances by epoch Id + pending deposits next epoch

*when next epoch begins, the balance of the current epoch will be added to pending deposits and rolled forward*


```solidity
uint256[] public epochBalances;
```


### currentEpochId
the current epoch ID


```solidity
uint8 public currentEpochId;
```


## Functions
### constructor


```solidity
constructor(address _stakingToken);
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

fetches the balance of staking tokens at a given epochId.
if passed the next epoch id, will return a projection.


```solidity
function getEpochBalanceWithProjection(uint8 _epochId) external view returns (uint256);
```

### getEpochBalances

fetch the epoch balances array 'as-is', with no projections


```solidity
function getEpochBalances() external view returns (uint256[] memory);
```

### getUserBalances

fetches balances for the user up to nextEpoch.

*If a balance is empty, check to see if the user was active in that epoch, then if so,
look at the next available balance. See the `getHistoricalBalance` for an example.*

*Required because we use a mapping vs a contiguous array.
This function can get quite expensive so best to leave it as a view*


```solidity
function getUserBalances(address _user) external view returns (uint256[] memory);
```

### getTotalBalanceForUser

assuming no deposits nor withdrawals, fetches what the user's balance will be starting from next epoch.


```solidity
function getTotalBalanceForUser(address _user) external view returns (uint256 balance);
```

### getActiveBalanceForUser

get epoch balance for the current epoch, for a given user.


```solidity
function getActiveBalanceForUser(address _user) public view returns (uint256 balance);
```

### getHistoricalBalanceForUser

fetches the actual balance for a user at a given epoch.

*if the user's balance was zero but they were active, walks back through epochs to find the last known value*


```solidity
function getHistoricalBalanceForUser(address _user, uint8 _epoch) public view returns (uint256 balance);
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
function deposit(uint256 _amount) public nonReentrant whenNotPaused;
```

### depositWithSignature

make a gasless deposit using EIP-712 compliant permit signature for approvals


```solidity
function depositWithSignature(uint256 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external;
```

### quit

removes all staked tokens from the contract, including pending deposits next epoch.


```solidity
function quit() external;
```

### revertDepositAndWithdraw

withdraw tokens up to the total balance the user has stored in the contract.
We first try to remove from pending deposits, then will withdraw from current.

*This function is a convenience function to avoid multiple transactions.
If you know ahead of time if the user is only reverting or only withdrawing,
save them some gas and call the proper function.*


```solidity
function revertDepositAndWithdraw(uint256 _amount) public nonReentrant whenNotPaused;
```

### revertDeposit

removes any tokens newly deposited in the next epoch, without affecting the current staking.


```solidity
function revertDeposit(uint256 _amount) public nonReentrant whenNotPaused;
```

### _revertDeposit

internal function to action accounting changes and the token transfer.

*we use calldata arguments to avoid recomputing some of the expensive variables already checked in the outer scopes.*


```solidity
function _revertDeposit(uint256 _amount, uint256 _available, uint8 _nextEpochId, UserStake storage _u) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|that will be withdrawn, assumed to be <= available|
|`_available`|`uint256`|to withdraw, we assume this has been checked|
|`_nextEpochId`|`uint8`||
|`_u`|`UserStake`|the storage pointer to the current user's staking data|


### withdraw

withdraw tokens from the contract. If withdrawing all, the user will be set as inactive
if the user has deposited tokens into the next epoch, these must be withdrawn first.


```solidity
function withdraw(uint256 _amount) public nonReentrant whenNotPaused;
```

### _withdraw

internal function to action withdrawal once paramaters checked.

*similar to _revertDeposit it splits checks from effects and interactions.*


```solidity
function _withdraw(uint256 _amount, UserStake storage _u) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|to withdraw, assumed to be valid|
|`_u`|`UserStake`|storage pointer to the user withdrawal data|


### activateNextEpoch

move to the next epoch. The balance at the end of the previous epoch is rolled forward.

*until this function is called, the balance of the next epoch only represents pending deposits.*


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

