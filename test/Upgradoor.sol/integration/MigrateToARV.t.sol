// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import "@test/utils.sol";

contract TestMigrateToARV is TestUpgradoorIntegrationSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    function testFuzz_ExitToVeAuxoBoosted(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        vm.assume(_depositor.isEOA());

        (uint256 total,,,) = _initLocks(_depositor, _months, _amounts);

        uint256 tokenLockerAuxoBalance = auxo.balanceOf(address(tokenLocker));

        vm.prank(_depositor);
        UP.aggregateAndBoost();

        (uint192 amount, uint32 lockedAt, uint32 lockDuration) = tokenLocker.lockOf(_depositor);

        assertEq(amount, total / 100);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockDuration, 36 * AVG_SECONDS_MONTH);

        assertEq(veauxo.balanceOf(_depositor), amount);
        assertEq(auxo.balanceOf(address(tokenLocker)), tokenLockerAuxoBalance + amount);

        assertEq(veDOUGH.balanceOf(_depositor), 0);
        assertEq(mockDOUGH.balanceOf(address(UP)), total);
    }

    function testFuzz_ExitToVeAuxoBoostedWithExpiry(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint64 _fastForward
    ) public {
        vm.assume(_depositor.isEOA());

        (uint256 total,,,) = _initLocks(_depositor, _months, _amounts);
        _warpTo(_fastForward);

        uint256 tokenLockerAuxoBalance = auxo.balanceOf(address(tokenLocker));
        (uint256 amountValid,, bool foundValidLock,) = _getLongestValidLock(_depositor);

        if (!foundValidLock) {
            vm.expectRevert("SharesTimeLock: Lock expired");
            vm.prank(_depositor);
            UP.aggregateAndBoost();
        } else {
            vm.prank(_depositor);
            UP.aggregateAndBoost();

            (uint192 amount, uint32 lockedAt, uint32 lockDuration) = tokenLocker.lockOf(_depositor);

            assertEq(amount, amountValid / 100);
            assertEq(lockedAt, block.timestamp);
            assertEq(lockDuration, 36 * AVG_SECONDS_MONTH);

            assertEq(veauxo.balanceOf(_depositor), amount);
            assertEq(auxo.balanceOf(address(tokenLocker)), tokenLockerAuxoBalance + amountValid / 100);

            if (total == amountValid) {
                assertEq(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            } else {
                assertGt(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            }
        }
    }

    function testFuzz_ExitToVeAuxoNonBoosted(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        vm.assume(_depositor.isEOA());

        (uint256 total,, uint32 longestLockedAt, uint32 longestDuration) = _initLocks(_depositor, _months, _amounts);

        uint256 tokenLockerAuxoBalance = auxo.balanceOf(address(tokenLocker));
        uint256 adjustedMonths = UP.getMonthsNewLock(longestLockedAt, longestDuration);
        uint256 expectedQty = ((total / 100) * tokenLocker.maxRatioArray(adjustedMonths)) / (10 ** 18);

        vm.prank(_depositor);
        UP.aggregateToARV();

        (uint192 amount, uint32 lockedAt, uint32 lockDuration) = tokenLocker.lockOf(_depositor);

        assertEq(amount, total / 100);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockDuration, adjustedMonths * AVG_SECONDS_MONTH);

        assertEq(veauxo.balanceOf(_depositor), expectedQty);
        assertEq(auxo.balanceOf(address(tokenLocker)), tokenLockerAuxoBalance + amount);

        assertEq(veDOUGH.balanceOf(_depositor), 0);
        assertEq(mockDOUGH.balanceOf(address(UP)), total);
    }

    function testFuzz_ExitToVeAuxoNonBoostedWithExpiry(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint64 _fastForward
    ) public {
        vm.assume(_depositor.isEOA());

        (uint256 total,,,) = _initLocks(_depositor, _months, _amounts);
        _warpTo(_fastForward);

        (uint256 amountValid, SharesTimeLock.Lock memory longestValidLock, bool foundValidLock,) =
            _getLongestValidLock(_depositor);
        uint256 adjustedMonths = UP.getMonthsNewLock(longestValidLock.lockedAt, longestValidLock.lockDuration);
        uint256 expectedQty = ((amountValid / 100) * tokenLocker.maxRatioArray(adjustedMonths)) / (10 ** 18);
        uint256 tokenLockerAuxoBalance = auxo.balanceOf(address(tokenLocker));

        if (!foundValidLock) {
            vm.expectRevert("SharesTimeLock: Lock expired");
            vm.prank(_depositor);
            UP.aggregateToARV();
        } else {
            vm.prank(_depositor);
            UP.aggregateToARV();

            {
                (uint192 amount, uint32 lockedAt, uint32 lockDuration) = tokenLocker.lockOf(_depositor);
                assertEq(amount, amountValid / 100);
                assertEq(lockedAt, block.timestamp);
                assertEq(lockDuration, adjustedMonths * AVG_SECONDS_MONTH);
            }

            assertEq(veauxo.balanceOf(_depositor), expectedQty);
            assertEq(auxo.balanceOf(address(tokenLocker)), tokenLockerAuxoBalance + amountValid / 100);

            if (total == amountValid) {
                assertEq(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            } else {
                assertGt(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            }
        }
    }

    // Ensure that migrating all after a single lock reverts gracefully
    function testFuzz_migrateNoLocksRevertsGracefully() public {
        // init a single lock for the depositor with 36 months and 1000 DOUGH
        address _depositor = address(0x1);
        _addMockLock(36, _depositor, 1000 ether);

        vm.startPrank(_depositor);
        {
            // migrate the single lock
            UP.upgradeSingleLockARV(_depositor);

            // do an aggregation call - this should revert but
            // cleanly, in the past it has out of gassed in an infinite loop
            vm.expectRevert("Nothing to Burn");
            UP.aggregateToARV();
        }
        vm.stopPrank();

    }
}
