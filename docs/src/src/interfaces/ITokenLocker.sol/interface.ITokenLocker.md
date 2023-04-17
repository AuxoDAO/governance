# ITokenLocker
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/interfaces/ITokenLocker.sol)


## Functions
### depositByMonths


```solidity
function depositByMonths(uint192 _amount, uint256 _months, address _receiver) external;
```

### boostToMax


```solidity
function boostToMax() external;
```

### increaseAmount


```solidity
function increaseAmount(uint192 _amount) external;
```

### increaseByMonths


```solidity
function increaseByMonths(uint256 _months) external;
```

### migrate


```solidity
function migrate(address staker) external;
```

### eject

Ejects a list of lock accounts from the contract.

*Smart contracts with locked rewardToken balances should be mindful that
they may be ejected from the contract by external users.*


```solidity
function eject(address[] calldata _lockAccounts) external;
```

### getLock


```solidity
function getLock(address _depositor) external returns (Lock memory);
```

### lockOf


```solidity
function lockOf(address account) external view returns (uint192, uint32, uint32);
```

### minLockAmount


```solidity
function minLockAmount() external returns (uint256);
```

### maxLockDuration


```solidity
function maxLockDuration() external returns (uint32);
```

### getLockMultiplier


```solidity
function getLockMultiplier(uint32 _duration) external view returns (uint256);
```

### getSecondsMonths


```solidity
function getSecondsMonths() external view returns (uint256);
```

### previewDepositByMonths


```solidity
function previewDepositByMonths(uint192 _amount, uint256 _months, address _receiver) external view returns (uint256);
```

## Structs
### Lock

```solidity
struct Lock {
    uint192 amount;
    uint32 lockedAt;
    uint32 lockDuration;
}
```

