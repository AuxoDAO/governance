// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract SharesTimeLockMock {
    struct Lock {
        uint256 amount;
        uint32 lockedAt;
        uint32 lockDuration;
    }

    mapping(address => Lock[]) public locksOf;
    bool migrationEnabled = true;
    address DOUGH;
    address migrator;

    constructor(address _dough) {
        DOUGH = _dough;
    }

    function setMigrator(address _migrator) external {
        migrator = _migrator;
    }

    function getLocksOfLength(address account) external view returns (uint256) {
        return locksOf[account].length;
    }

    function add(uint256 _amount, uint32 _lockedAt, uint32 _lockDuration) external {
        locksOf[msg.sender].push(Lock({amount: _amount, lockedAt: _lockedAt, lockDuration: _lockDuration}));
    }

    function migrate(address staker, uint256 lockId) external {
        require(
            uint256(locksOf[staker][lockId].lockedAt + locksOf[staker][lockId].lockDuration) > block.timestamp,
            "Lock expired"
        );
        require(migrationEnabled, "SharesTimeLockMock: !migrationEnabled");
        Lock memory lock = locksOf[staker][lockId];
        require(lock.amount > 0, "SharesTimeLockMock: nothing to migrate");
        delete locksOf[staker][lockId];
        IERC20(DOUGH).transfer(migrator, lock.amount);
    }

    function migrateMany(address staker, uint256[] calldata lockIds) external returns (uint256) {
        require(migrationEnabled, "SharesTimeLockMock: !migrationEnabled");
        uint256 amountToMigrate = 0;

        for (uint256 i = 0; i < lockIds.length;) {
            require(
                uint256(locksOf[staker][i].lockedAt + locksOf[staker][i].lockDuration) > block.timestamp,
                "SharesTimeLockMock: Lock expired"
            );
            amountToMigrate += locksOf[staker][i].amount;
            delete locksOf[staker][i];
            unchecked {
                ++i;
            }
        }

        IERC20(DOUGH).transfer(migrator, amountToMigrate);
        return amountToMigrate;
    }
}
