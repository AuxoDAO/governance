// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {AccessControlEnumerableUpgradeable as AccessControlEnumerable} from "@oz-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

interface IMigrateableEvents {
    event MigratorUpdated(address indexed newMigrator);
    event MigrationEnabledChanged(bool enabled);
    /**
     * @notice should be emitted within the override
     * @param amountDepositMigrated quantity of tokens locked in the contract that were moved
     */
    event Migrated(address indexed account, uint256 amountDepositMigrated);
}

/**
 * @notice a minimal set of state variables and methods to enable users to extract tokens from one contract implementation to another
 *         without relying on upgradeability.
 * @dev override the `migrate` function in the inheriting contract
 */
abstract contract Migrateable is AccessControlEnumerable, IMigrateableEvents {
    /// @notice the contract that will receive tokens during the migration
    address public migrator;

    /// @notice once enabled, users can call the `migrate` function
    bool public migrationEnabled;

    /**
     * @notice when set to 'true' by the owner, activates the migration process and allows early exit of locks
     */
    function setMigrationEnabled(bool _migratonEnabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        migrationEnabled = _migratonEnabled;
        emit MigrationEnabledChanged(_migratonEnabled);
    }

    /**
     * @notice sets the destination for deposit tokens when the `migrate` function is invoked
     */
    function setMigrator(address _migrator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        migrator = _migrator;
        emit MigratorUpdated(_migrator);
    }

    /**
     * @notice contract must override this to determine the migrate logic
     */
    function migrate(address staker) external virtual {
        emit Migrated(staker, 0);
    }
}
