# Migrateable
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/Migrator.sol)

**Inherits:**
AccessControlEnumerable, [IMigrateableEvents](/src/modules/governance/Migrator.sol/interface.IMigrateableEvents.md)

a minimal set of state variables and methods to enable users to extract tokens from one contract implementation to another
without relying on upgradeability.

*override the `migrate` function in the inheriting contract*


## State Variables
### migrator
the contract that will receive tokens during the migration


```solidity
address public migrator;
```


### migrationEnabled
once enabled, users can call the `migrate` function


```solidity
bool public migrationEnabled;
```


## Functions
### setMigrationEnabled

when set to 'true' by the owner, activates the migration process and allows early exit of locks


```solidity
function setMigrationEnabled(bool _migratonEnabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### setMigrator

sets the destination for deposit tokens when the `migrate` function is invoked


```solidity
function setMigrator(address _migrator) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### migrate

contract must override this to determine the migrate logic


```solidity
function migrate(address staker) external virtual;
```

