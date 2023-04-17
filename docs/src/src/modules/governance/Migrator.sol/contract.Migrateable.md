# Migrateable
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/governance/Migrator.sol)

**Inherits:**
Ownable, [IMigrateableEvents](/src/modules/governance/Migrator.sol/contract.IMigrateableEvents.md)

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
function setMigrationEnabled(bool _migratonEnabled) external onlyOwner;
```

### setMigrator

sets the destination for deposit tokens when the `migrate` function is invoked


```solidity
function setMigrator(address _migrator) external onlyOwner;
```

### migrate

contract must override this to determine the migrate logic


```solidity
function migrate() external virtual;
```

