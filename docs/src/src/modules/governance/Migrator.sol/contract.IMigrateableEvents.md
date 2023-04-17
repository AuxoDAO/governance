# IMigrateableEvents
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/governance/Migrator.sol)


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

