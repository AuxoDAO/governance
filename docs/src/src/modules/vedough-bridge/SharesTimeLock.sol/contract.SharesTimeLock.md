# SharesTimeLock
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/vedough-bridge/SharesTimeLock.sol)

**Inherits:**
Ownable


## State Variables
### depositToken

```solidity
address public depositToken;
```


### rewardsToken

```solidity
IERC20MintableBurnable public rewardsToken;
```


### minLockDuration

```solidity
uint32 public minLockDuration;
```


### maxLockDuration

```solidity
uint32 public maxLockDuration;
```


### minLockAmount

```solidity
uint256 public minLockAmount;
```


### AVG_SECONDS_MONTH

```solidity
uint256 private constant AVG_SECONDS_MONTH = 2628000;
```


### emergencyUnlockTriggered

```solidity
bool public emergencyUnlockTriggered;
```


### maxRatioArray
Mapping of coefficient for the staking curve
y=x/k*log(x)
where `x` is the staking time
and `k` is a constant 56.0268900276223
the period of staking here is calculated in months.


```solidity
uint256[37] public maxRatioArray;
```


### locksOf

```solidity
mapping(address => Lock[]) public locksOf;
```


### whitelisted

```solidity
mapping(address => bool) public whitelisted;
```


### ejectBuffer

```solidity
uint256 public ejectBuffer;
```


### migrationEnabled
NEW STORAGE HERE


```solidity
bool public migrationEnabled;
```


### migrator

```solidity
address public migrator;
```


## Functions
### getLocksOfLength


```solidity
function getLocksOfLength(address account) external view returns (uint256);
```

### getLocks


```solidity
function getLocks(address account) external view returns (Lock[] memory);
```

### getRewardsMultiplier

*Returns the rewards multiplier for `duration` expressed as a fraction of 1e18.*


```solidity
function getRewardsMultiplier(uint32 duration) public view returns (uint256 multiplier);
```

### initialize


```solidity
function initialize(
    address depositToken_,
    IERC20MintableBurnable rewardsToken_,
    uint32 minLockDuration_,
    uint32 maxLockDuration_,
    uint256 minLockAmount_
) public initializer;
```

### depositByMonths


```solidity
function depositByMonths(uint256 amount, uint256 months, address receiver) external;
```

### deposit


```solidity
function deposit(uint256 amount, uint32 duration, address receiver) internal;
```

### withdraw


```solidity
function withdraw(uint256 lockId) external;
```

### boostToMax


```solidity
function boostToMax(uint256 lockId) external;
```

### eject


```solidity
function eject(address[] memory lockAccounts, uint256[] memory lockIds) external;
```

### setMigratoor

Setters


```solidity
function setMigratoor(address migrator_) external onlyOwner;
```

### setMigrationON


```solidity
function setMigrationON() external onlyOwner;
```

### setMigrationOFF


```solidity
function setMigrationOFF() external onlyOwner;
```

### setMinLockAmount


```solidity
function setMinLockAmount(uint256 minLockAmount_) external onlyOwner;
```

### setWhitelisted


```solidity
function setWhitelisted(address user, bool isWhitelisted) external onlyOwner;
```

### triggerEmergencyUnlock


```solidity
function triggerEmergencyUnlock() external onlyOwner;
```

### setEjectBuffer


```solidity
function setEjectBuffer(uint256 buffer) external onlyOwner;
```

### getStakingData

Getters


```solidity
function getStakingData(address account) external view returns (StakingData memory data);
```

### secondsPerMonth


```solidity
function secondsPerMonth() internal view virtual returns (uint256);
```

### canEject


```solidity
function canEject(address account, uint256 lockId) external view returns (bool);
```

### lockExpired


```solidity
function lockExpired(address staker, uint256 lockId) public view returns (bool);
```

### lockExpired

*overloaded to allow passing the lock if available*


```solidity
function lockExpired(Lock memory lock) public view returns (bool);
```

### migrate

migrates a single lockId for the passed staker.
Dough is transferred to the migrator and veDOUGH is burned.


```solidity
function migrate(address staker, uint256 lockId) external;
```

### migrateMany

migrates multiple staking positions as determined by the passed lockIds

*you can pass any array of Ids and the contract will migrate them if they are not expired for that staker
however it is advised that the array is sorted.
Specifically, If LockId `0` is to be migrated, it should be the first element of the lockIds array.*


```solidity
function migrateMany(address staker, uint256[] calldata lockIds) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`staker`|`address`||
|`lockIds`|`uint256[]`|an array of lock indexes to migrate for the current staker, should be sorted in ascending order.|


## Events
### MinLockAmountChanged

```solidity
event MinLockAmountChanged(uint256 newLockAmount);
```

### WhitelistedChanged

```solidity
event WhitelistedChanged(address indexed user, bool indexed whitelisted);
```

### Deposited

```solidity
event Deposited(uint256 indexed lockId, uint256 amount, uint32 lockDuration, address indexed owner);
```

### Withdrawn

```solidity
event Withdrawn(uint256 indexed lockId, uint256 amount, address indexed owner);
```

### Ejected

```solidity
event Ejected(uint256 indexed lockId, uint256 amount, address indexed owner);
```

### BoostedToMax

```solidity
event BoostedToMax(uint256 indexed oldLockId, uint256 indexed newLockId, uint256 amount, address indexed owner);
```

### EjectBufferUpdated

```solidity
event EjectBufferUpdated(uint256 newEjectBuffer);
```

## Structs
### Lock

```solidity
struct Lock {
    uint256 amount;
    uint32 lockedAt;
    uint32 lockDuration;
}
```

### StakingData

```solidity
struct StakingData {
    uint256 totalStaked;
    uint256 veTokenTotalSupply;
    uint256 accountVeTokenBalance;
    uint256 accountWithdrawableRewards;
    uint256 accountWithdrawnRewards;
    uint256 accountDepositTokenBalance;
    uint256 accountDepositTokenAllowance;
    Lock[] accountLocks;
}
```

