# ISharesTimelocker
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/vedough-bridge/Upgradoor.sol)

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

