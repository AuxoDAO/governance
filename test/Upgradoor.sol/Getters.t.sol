// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorSetup} from "./Setup.sol";

contract TestGetters is TestUpgradoorSetup {
    function setUp() public {
        prepareSetup();
    }

    function testGetAmountAndLongestDuration() public {
        (uint256 longest, uint256 amount,) = UP.getAmountAndLongestDuration(address(this));
        assertEq(longest, LONGEST.lockDuration);
    }

    /// This test doesn't do much besides making sure that it doesn't break with different values
    function testGetMonthsNewLock(uint32 _randTimePassed) public {
        // Time the old lock was deployed
        vm.assume(_randTimePassed > 0);
        vm.assume(_randTimePassed < AVG_SECONDS_MONTH * 36);

        uint256 present = 1631434044 + _randTimePassed;
        vm.warp(present);

        if (present > SHORTER.lockedAt + SHORTER.lockDuration) {
            assertEq(0, UP.getMonthsNewLock(SHORTER.lockedAt, SHORTER.lockDuration));
        } else {
            assertEq(6, UP.getMonthsNewLock(SHORTER.lockedAt, SHORTER.lockDuration));
        }
    }

    function testGetOldLock() public {
        uint256 lockAmount;
        uint32 lockLockedAt;
        uint32 lockDuration;

        (lockAmount, lockLockedAt, lockDuration) = UP.getOldLock(address(this), 0);

        assertEq(lockAmount, SHORTER.amount);
        assertEq(lockLockedAt, SHORTER.lockedAt);
        assertEq(lockDuration, SHORTER.lockDuration);

        (lockAmount, lockLockedAt, lockDuration) = UP.getOldLock(address(this), NUMLOCKS / 2);
        assertEq(lockAmount, MIDDLE.amount);
        assertEq(lockLockedAt, MIDDLE.lockedAt);
        assertEq(lockDuration, MIDDLE.lockDuration);

        (lockAmount, lockLockedAt, lockDuration) = UP.getOldLock(address(this), NUMLOCKS);

        assertEq(lockAmount, LONGEST.amount);
        assertEq(lockLockedAt, LONGEST.lockedAt);
        assertEq(lockDuration, LONGEST.lockDuration);
    }
}
