# IRollStaker
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/RollStaker.sol)


## Events
### Deposited

```solidity
event Deposited(address indexed depositor, address indexed receiver, uint8 indexed epoch, uint256 amount);
```

### Withdrawn

```solidity
event Withdrawn(address indexed depositor, uint8 indexed epoch, uint256 amount);
```

### Exited

```solidity
event Exited(address indexed depositor, uint8 indexed epoch);
```

### NewEpoch

```solidity
event NewEpoch(uint8 indexed newEpochId, uint256 startedTimestamp);
```

### EmergencyWithdraw

```solidity
event EmergencyWithdraw(address indexed user, uint256 amount);
```

## Errors
### ZeroAmount

```solidity
error ZeroAmount();
```

### InvalidWithdrawalAmount

```solidity
error InvalidWithdrawalAmount(address sender, uint256 amount);
```

### InvalidEmptyBalance

```solidity
error InvalidEmptyBalance(address sender, uint256 withdrawAmount);
```

### TransferFailed

```solidity
error TransferFailed();
```

## Structs
### UserStake
contains information about user staking positions.

*this activations array can efficiently store up to 256 epochs for a user and preserves historical state
however you should access using the Bitfields library.*

*120bits unsigned is a bit of an odd value, so we cast to uint256 for all external functions.*


```solidity
struct UserStake {
    Bitfields.Bitfield activations;
    uint8 epochWritten;
    uint120 pending;
    uint120 active;
}
```

