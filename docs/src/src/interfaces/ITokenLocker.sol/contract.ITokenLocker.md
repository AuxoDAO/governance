# ITokenLocker
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/interfaces/ITokenLocker.sol)


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

