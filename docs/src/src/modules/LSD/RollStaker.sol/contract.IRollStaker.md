# IRollStaker
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/LSD/RollStaker.sol)


## Events
### Deposited

```solidity
event Deposited(address indexed user, uint8 indexed epoch, uint256 amount);
```

### DepositReverted

```solidity
event DepositReverted(address indexed user, uint8 indexed epoch, uint256 amount);
```

### Withdrawn

```solidity
event Withdrawn(address indexed user, uint8 indexed epoch, uint256 amount);
```

### Exited

```solidity
event Exited(address indexed user, uint8 indexed epoch);
```

### NewEpoch

```solidity
event NewEpoch(uint8 indexed newEpochId, uint256 startedTimestamp);
```

### Quit

```solidity
event Quit(address indexed user, uint8 indexed epoch);
```

## Errors
### ZeroAmount

```solidity
error ZeroAmount();
```

### NothingToWithdraw

```solidity
error NothingToWithdraw(address sender);
```

### Inactive

```solidity
error Inactive(address sender, uint8 epoch);
```

### InvalidWithdrawalAmount

```solidity
error InvalidWithdrawalAmount(address sender, uint256 amount);
```

### InvalidWithdrawalEpoch

```solidity
error InvalidWithdrawalEpoch(address sender, uint8 epoch);
```

### UserWithinGracePeriod

```solidity
error UserWithinGracePeriod(address user);
```

## Structs
### UserStake
contains information about user staking positions.

*this activations array can efficiently store up to 256 epochs for a user and preserves historical state
however you should access using the Bitfields library.*

***IMPORTANT** a zero balance DOES NOT mean the user had no balance, it simply means the user did not deposit
or withdraw in that epoch. You need to check the activations array to see if the user was active, then check
previous balances to find the last known balance.
We use a mapping here because it allows us to index by epoch id without having to initialize an array.*

*Not all locked tokens are active, tokens deposited this epoch activate next epoch.
Use getActiveBalanceForUser to get tokens activated *this* epoch.*


```solidity
struct UserStake {
    Bitfields.Bitfield activations;
    mapping(uint8 => uint256) balances;
    uint256 totalLocked;
}
```

