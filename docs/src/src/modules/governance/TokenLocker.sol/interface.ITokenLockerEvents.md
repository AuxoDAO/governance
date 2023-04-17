# ITokenLockerEvents
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/TokenLocker.sol)


## Events
### MinLockAmountChanged

```solidity
event MinLockAmountChanged(uint192 newLockAmount);
```

### WhitelistedChanged

```solidity
event WhitelistedChanged(address indexed account, bool indexed whitelisted);
```

### Deposited

```solidity
event Deposited(uint192 amount, uint32 lockDuration, address indexed owner);
```

### Withdrawn

```solidity
event Withdrawn(uint192 amount, address indexed owner);
```

### BoostedToMax

```solidity
event BoostedToMax(uint192 amount, address indexed owner);
```

### IncreasedAmount

```solidity
event IncreasedAmount(uint192 amount, address indexed owner);
```

### IncreasedDuration

```solidity
event IncreasedDuration(uint192 amount, uint32 lockDuration, uint32 lockedAt, address indexed owner);
```

### Ejected

```solidity
event Ejected(uint192 amount, address indexed owner);
```

### EjectBufferUpdated

```solidity
event EjectBufferUpdated(uint32 newEjectBuffer);
```

### PRVAddressChanged

```solidity
event PRVAddressChanged(address prv);
```

