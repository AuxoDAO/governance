# ISharesTimelocker
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/vedough-bridge/Upgradoor.sol)

===============================
===== Audit: NOT IN SCOPE =====
===============================


## Functions
### getLocksOfLength


```solidity
function getLocksOfLength(address account) external view returns (uint256);
```

### locksOf


```solidity
function locksOf(address account, uint256 id) external view returns (uint256, uint32, uint32);
```

### migrate


```solidity
function migrate(address staker, uint256 lockId) external;
```

### canEject


```solidity
function canEject(address account, uint256 lockId) external view returns (bool);
```

### migrateMany


```solidity
function migrateMany(address staker, uint256[] calldata lockIds) external returns (uint256);
```

