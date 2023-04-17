# ITokenLockerEvents
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/governance/TokenLocker.sol)


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

### IncreasedLock

```solidity
event IncreasedLock(uint192 amount, uint32 lockDuration, address indexed owner);
```

### Ejected

```solidity
event Ejected(uint192 amount, address indexed owner);
```

### EjectBufferUpdated

```solidity
event EjectBufferUpdated(uint32 newEjectBuffer);
```

### xAuxoAddressChanged

```solidity
event xAuxoAddressChanged(address xAUXO);
```

