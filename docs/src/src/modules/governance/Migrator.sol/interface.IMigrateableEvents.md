# IMigrateableEvents
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/Migrator.sol)


## Events
### MigratorUpdated

```solidity
event MigratorUpdated(address indexed newMigrator);
```

### MigrationEnabledChanged

```solidity
event MigrationEnabledChanged(bool enabled);
```

### Migrated
should be emitted within the override


```solidity
event Migrated(address indexed account, uint256 amountDepositMigrated);
```

