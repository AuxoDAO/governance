# Upgradoor
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/vedough-bridge/Upgradoor.sol)

*This contract assumes all locks are properly ejected*


## State Variables
### AUXO

```solidity
address public immutable AUXO;
```


### PRV

```solidity
address public immutable PRV;
```


### DOUGH

```solidity
address public immutable DOUGH;
```


### veDOUGH

```solidity
address public immutable veDOUGH;
```


### prvRouter

```solidity
address public immutable prvRouter;
```


### tokenLocker

```solidity
ITokenLocker public tokenLocker;
```


### AVG_SECONDS_MONTH

```solidity
uint32 public constant AVG_SECONDS_MONTH = 2628000;
```


### oldLock

```solidity
ISharesTimelocker public oldLock;
```


## Functions
### constructor


```solidity
constructor(
    address _oldLock,
    address _auxo,
    address _dough,
    address _tokenLocker,
    address _prv,
    address _veDOUGH,
    address _router
);
```

### previewAggregateToPRV

Returns the expected PRV return amount when upgrading all veDOUGH locks to PRV.


```solidity
function previewAggregateToPRV(address receiver) external view returns (uint256);
```

### previewAggregateAndBoost

Returns the expected AUXO return amount when aggregating all veDOUGH locks and boosting to 36 months

*boosting to max will yield a 1:1 conversion from veDOUGH -> AUXO*


```solidity
function previewAggregateAndBoost(address receiver) external view returns (uint256);
```

### previewAggregateARV

Aggregate all locks to ARV based on the remaining months of the longest lock


```solidity
function previewAggregateARV(address receiver) external view returns (uint256);
```

### previewUpgradeSingleLockARV


```solidity
function previewUpgradeSingleLockARV(address lockOwner, address receiver) external view returns (uint256);
```

### previewUpgradeSingleLockPRV

Returns the expected PRV return amount when upgrading a single lock.


```solidity
function previewUpgradeSingleLockPRV(address lockOwner) external view returns (uint256);
```

### aggregateAndBoost

aggregates all the locks to one at max time


```solidity
function aggregateAndBoost() external;
```

### aggregateToARV

aggregates all the locks to one ARV

*Aggregated to *REMAINING* months on the longest lock*

*If the remaining months are < 6 than we default to 6*


```solidity
function aggregateToARV() external;
```

### aggregateToPRV

aggregates all the locks to PRV


```solidity
function aggregateToPRV() external;
```

### aggregateToPRVAndStake

aggregates all the locks to PRV


```solidity
function aggregateToPRVAndStake() external;
```

### upgradeSingleLockARV

If the remaning months are < 6 than we default to 6


```solidity
function upgradeSingleLockARV(address receiver) external;
```

### upgradeSingleLockPRV

If receiver has an existing lock it will revert
because otherwise receiver would not be able to migrate his own lock


```solidity
function upgradeSingleLockPRV(address receiver) external;
```

### upgradeSingleLockPRVAndStake


```solidity
function upgradeSingleLockPRVAndStake(address receiver) external;
```

### _runMigrationAll


```solidity
function _runMigrationAll() internal returns (uint256);
```

### _runMigrationOne


```solidity
function _runMigrationOne(uint256 idx) internal returns (uint256);
```

### getMonthsNewLock

Returns the number of months remaining for the lock, with a minimum of 6 months


```solidity
function getMonthsNewLock(uint32 lockedAt, uint32 duration) public view returns (uint256);
```

### getOldLock


```solidity
function getOldLock(address owner, uint256 oldLockId) public view returns (uint256, uint32, uint32);
```

### getAmountAndLongestDuration

Return the cumulative amount migratable together with the longest duration

*ignores expired locks.*

*returns Tuple containing:
1. `longestDuration` in seconds that DOUGH was locked for i.e 35 months in seconds
2. Cumulative `longestAmount` migrateable together
3. `longestIndex` representing the lockID of the longest lock duration. In the event of multiple locks with
the same duration, we use the first id that appears*


```solidity
function getAmountAndLongestDuration(address guy) public view returns (uint32, uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guy`|`address`|the user with the existing veDOUGH lock|


### getNextLongestLock

Returns the single longest lock by duration in order of creation

*skips empty locks and expired locks*

*if two locks have the same duration, the first one in order of creation will be user*


```solidity
function getNextLongestLock(address guy) public view returns (uint256, uint32, uint32, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guy`|`address`|user to fetch locks for|


### getRate


```solidity
function getRate(uint256 amount) public pure returns (uint256);
```

## Events
### AggregatedAndBoosted

```solidity
event AggregatedAndBoosted(address owner, uint256 amountMigrated);
```

### AggregatedToARV

```solidity
event AggregatedToARV(address owner, uint256 amountMigrated);
```

### AggregateToPRV

```solidity
event AggregateToPRV(address owner, uint256 amountMigrated);
```

### AggregateToPRVAndStake

```solidity
event AggregateToPRVAndStake(address owner, uint256 amountMigratedAndStaker);
```

### LockUpgradedARV

```solidity
event LockUpgradedARV(address receiver, uint256 idx, uint256 amountMigrated);
```

### LockUpgradedPRV

```solidity
event LockUpgradedPRV(address receiver, uint256 idx, uint256 amountMigrated);
```

### LockUpgradedPRVAndStake

```solidity
event LockUpgradedPRVAndStake(address receiver, uint256 idx, uint256 amountMigratedAndStaker);
```

