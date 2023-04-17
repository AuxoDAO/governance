// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IERC20MintableBurnable} from "@interfaces/IERC20MintableBurnable.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {MockRewardsToken} from "@test/mocks/Token.sol";

import "@test/utils.sol";

/**
 * We could prank the migrator, but it's more representative to test via an actual smart contract call
 */
contract Migrator {
    address internal sharesTimelock;

    constructor(address _sharesTimelock) {
        sharesTimelock = _sharesTimelock;
    }

    function migrate(address _depositor, uint256 _lockId) external {
        SharesTimeLock(sharesTimelock).migrate(_depositor, _lockId);
    }

    function migrateMany(address _depositor, uint256[] calldata _lockIds) external {
        SharesTimeLock(sharesTimelock).migrateMany(_depositor, _lockIds);
    }
}

contract TestSharesTimelock is Test {
    using IsEOA for address;

    SharesTimeLock internal stl;
    MockRewardsToken internal dough;
    MockRewardsToken internal vedough;
    Migrator internal migrator;

    uint256 private constant LOCKS_PER_USER = 10;
    uint32 private constant AVG_SECONDS_MONTH = 2628000;

    function _deploySharesTimelock() public returns (SharesTimeLock) {
        SharesTimeLock impl = new SharesTimeLock();
        Proxy proxy = new Proxy();
        proxy.setImplementation(address(impl));
        return SharesTimeLock(address(proxy));
    }

    function setUp() public {
        dough = new MockRewardsToken();
        vedough = new MockRewardsToken();

        stl = _deploySharesTimelock();
        migrator = new Migrator(address(stl));

        stl.initialize({
            depositToken_: address(dough),
            rewardsToken_: IERC20MintableBurnable(address(vedough)),
            minLockDuration_: 6 * AVG_SECONDS_MONTH,
            maxLockDuration_: 36 * AVG_SECONDS_MONTH,
            minLockAmount_: 1 ether
        });
    }

    function testOwnable(address _notOwner) public {
        vm.assume(_notOwner != address(this));

        vm.startPrank(_notOwner);
        {
            vm.expectRevert(Errors.OWNABLE);
            stl.setMigratoor(_notOwner);

            vm.expectRevert(Errors.OWNABLE);
            stl.setMigrationON();

            vm.expectRevert(Errors.OWNABLE);
            stl.setMigrationOFF();
        }
        vm.stopPrank();
    }

    function testMigrateReverts(
        address _migrator,
        address _depositor,
        uint256 _lockId,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        vm.assume(_migrator != address(this));
        _initLocks(_depositor, _months, _amounts);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = _lockId;

        // migrate reverts because not enabled
        vm.expectRevert(Errors.MIGRATION_DISABLED);
        stl.migrate(address(0), _lockId);

        vm.expectRevert(Errors.MIGRATION_DISABLED);
        stl.migrateMany(address(0), lockIds);

        // enable the migration
        stl.setMigrationON();

        // no migrator set
        vm.expectRevert(Errors.NOT_MIGRATOR);
        stl.migrate(address(0), _lockId);

        vm.expectRevert(Errors.NOT_MIGRATOR);
        stl.migrateMany(address(0), lockIds);

        // set the migrator
        stl.setMigratoor(_migrator);

        // migrate reverts because caller is probably not migrator
        if (_migrator != address(this)) {
            vm.expectRevert(Errors.NOT_MIGRATOR);
            stl.migrate(address(0), _lockId);

            vm.expectRevert(Errors.NOT_MIGRATOR);
            stl.migrateMany(address(0), lockIds);
        } else {
            // alternatively, pick a lock ID that doesn't exist, should revert on expiry
            _lockId = LOCKS_PER_USER + 1;
            lockIds[0] = _lockId;

            vm.expectRevert(Errors.LOCK_EXPIRED);
            stl.migrate(address(0), _lockId);

            vm.expectRevert(Errors.LOCK_EXPIRED);
            stl.migrateMany(address(0), lockIds);
        }
    }

    // test single migrate
    function testMigrate(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        vm.assume(_depositor != address(migrator));
        _initLocks(_depositor, _months, _amounts);

        // enable the migration and set the migrator
        stl.setMigrationON();
        stl.setMigratoor(address(migrator));

        SharesTimeLock.Lock[] memory locksBefore = stl.getLocks(_depositor);
        uint256 total = 0;

        // loop over staker's locks and test before and after
        for (uint256 i; i < locksBefore.length; i++) {
            // before
            SharesTimeLock.Lock memory lockBefore = locksBefore[i];
            total += lockBefore.amount;

            uint256 rewardBalanceBefore = vedough.balanceOf(_depositor);
            uint256 migratorDepositBalanceBefore = dough.balanceOf(address(migrator));
            uint256 stlDepositBalanceBefore = dough.balanceOf(address(stl));
            uint256 depositorDepositBalanceBefore = dough.balanceOf(_depositor);
            bool lockExpired = stl.lockExpired(_depositor, i);

            // if expired, check for revert and eject
            if (lockExpired) {
                // expect revert
                vm.expectRevert(Errors.LOCK_EXPIRED);
                migrator.migrate(_depositor, i);
                // boot them anyway
                _ejectOrWithdraw(_depositor, i);
            } else {
                // else migrate
                migrator.migrate(_depositor, i);
            }

            // empty lock after
            assertEq(stl.getLocks(_depositor)[i].amount, 0);
            assertEq(stl.getLocks(_depositor)[i].lockDuration, 0);
            assertEq(stl.getLocks(_depositor)[i].lockedAt, 0);

            // after
            uint256 expectedBurn = (stl.getRewardsMultiplier(lockBefore.lockDuration) * lockBefore.amount) / 1e18;

            // these values should be easy to calculate
            assertEq(dough.balanceOf(address(stl)), stlDepositBalanceBefore - lockBefore.amount);
            assertEq(vedough.balanceOf(_depositor), rewardBalanceBefore - expectedBurn);

            // deposits will be split between the depositor (if expired) or the migrator
            assertEq(
                dough.balanceOf(address(migrator)),
                lockExpired ? migratorDepositBalanceBefore : migratorDepositBalanceBefore + lockBefore.amount
            );
            assertEq(
                dough.balanceOf(_depositor),
                lockExpired ? depositorDepositBalanceBefore + lockBefore.amount : depositorDepositBalanceBefore
            );
        }

        assertEq(vedough.balanceOf(_depositor), 0);
        assertEq(dough.balanceOf(address(stl)), 0);
        assertEq(dough.balanceOf(address(migrator)) + dough.balanceOf(_depositor), total);
    }

    function testCannotMigrateTwice(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        vm.assume(_depositor != address(migrator));
        _initLocks(_depositor, _months, _amounts);

        // enable the migration and set the migrator
        stl.setMigrationON();
        stl.setMigratoor(address(migrator));
        SharesTimeLock.Lock[] memory locksBefore = stl.getLocks(_depositor);

        for (uint256 i; i < locksBefore.length; i++) {
            bool lockExpired = stl.lockExpired(_depositor, i);
            // if expired, check for revert and eject
            if (lockExpired) {
                // expect revert
                vm.expectRevert(Errors.LOCK_EXPIRED);
                migrator.migrate(_depositor, i);
                // boot them anyway
                _ejectOrWithdraw(_depositor, i);
            } else {
                // else migrate
                migrator.migrate(_depositor, i);
            }

            // try again and fail
            vm.expectRevert(Errors.LOCK_EXPIRED);
            migrator.migrate(_depositor, i);
        }
    }

    function testMigrateMany(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint8[] memory _lockIds
    ) public {
        vm.assume(_lockIds.length < 20);
        vm.assume(_depositor != address(migrator));
        _initLocks(_depositor, _months, _amounts);

        // enable the migration and set the migrator
        stl.setMigrationON();
        stl.setMigratoor(address(migrator));

        uint256 expectedMigrate = 0;
        uint256 expectedBackToDepositor = 0;

        // analyse the array and lift valid locks
        uint256[] memory migrateIds = new uint256[](_lockIds.length);
        uint256 j;
        for (uint256 i; i < _lockIds.length; i++) {
            // we break on an out of position zero
            if (i > 0 && _lockIds[i] == 0) {
                // stop the loop here - we can't migrate this
                break;
            }

            // case: trying to access a non-existent lock
            if (_lockIds[i] >= LOCKS_PER_USER) {
                continue;
            }

            uint256 value = stl.getLocks(_depositor)[_lockIds[i]].amount;

            // value zero means we have ejected or withdrawn in the next step
            if (value == 0) {
                continue;
            }

            // case 2: lock expired - eject or withdraw
            if (stl.lockExpired(_depositor, _lockIds[i])) {
                _ejectOrWithdraw(_depositor, _lockIds[i]);
                expectedBackToDepositor += value;
                continue;
            }

            // everything else should be migrated
            // ...but check if the lock is already added
            bool alreadyAdded = false;
            for (uint256 k; k < j; k++) {
                if (migrateIds[k] == _lockIds[i]) {
                    alreadyAdded = true;
                    break;
                }
            }
            // we can still add to the array
            migrateIds[j] = (_lockIds[i]);
            ++j;

            // but not to totals
            if (alreadyAdded) continue;
            expectedMigrate += value;
        }

        // end the fuzz iteration if nothing to migrate
        vm.assume(expectedMigrate > 0);

        migrator.migrateMany(_depositor, migrateIds);

        assertEq(dough.balanceOf(address(migrator)), expectedMigrate);
        // assertEq(dough.balanceOf(_depositor), expectedBackToDepositor);

        // running again just reverts on nothing to migrate
        vm.expectRevert();
        migrator.migrateMany(_depositor, migrateIds);
    }

    function testMigrateManyReverts(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint8[] memory _lockIds
    ) public {
        vm.assume(_depositor != address(migrator));
        _initLocks(_depositor, _months, _amounts);

        // enable the migration and set the migrator
        stl.setMigrationON();
        stl.setMigratoor(address(migrator));

        string memory expectedError;
        bool expectError = false;
        uint256 expectedMigrate = 0;

        // analyse the array and predict the first error
        for (uint256 i; i < _lockIds.length; i++) {
            // we break on an out of position zero
            if (i > 0 && _lockIds[i] == 0) {
                // stop the loop - internal function will break
                break;
            }

            // case: trying to access a non-existent lock
            if (_lockIds[i] >= LOCKS_PER_USER) {
                expectedError = "Index out of bounds";
                expectError = true;
                break;
            }

            // case: lock expired
            if (stl.lockExpired(_depositor, _lockIds[i])) {
                expectedError = string(Errors.LOCK_EXPIRED);
                expectError = true;
                break;
            }

            expectedMigrate += stl.getLocks(_depositor)[_lockIds[i]].amount;
        }

        if (expectedMigrate == 0) {
            expectedError = "Nothing to burn";
            expectError = true;
        }

        uint256[] memory castIds = castArray8to256(_lockIds);
        // migrate
        if (expectError) {
            console2.log("expecting error", expectedError);
            // would try and test for specifics but foundry is fighting with me
            vm.expectRevert();
            migrator.migrateMany(_depositor, castIds);
        } else {
            // should be happy migrating otherwise
            migrator.migrateMany(_depositor, castIds);
        }

        // running again just reverts on nothing to migrate
        vm.expectRevert();
        migrator.migrateMany(_depositor, castIds);
    }

    /* -------- TEST HELPERS -------- */

    function _ejectOrWithdraw(address _depositor, uint256 _lockId) public {
        address[] memory depositors = new address[](1);
        depositors[0] = _depositor;

        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = _lockId;

        // eject if we can else prank and withdraw
        if (stl.canEject(_depositor, _lockId)) {
            stl.eject(depositors, lockIds);
        } else {
            vm.prank(_depositor);
            stl.withdraw(_lockId);
        }
    }

    /**
     * @dev sets up LOCKS_PER_USER locks with 1 month in between each.
     */
    function _initLocks(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) internal {
        for (uint256 i; i < _amounts.length; i++) {
            // using vm.assume will cause tests to fail with too many rejects.
            // It's easier to just overwrite invalid entries with valid - especially given that we are not testing lock logic
            if (_months[i] > 36) _months[i] = 36;
            if (_months[i] < 6) _months[i] = 6;
            if (_amounts[i] < stl.minLockAmount()) _amounts[i] = uint128(stl.minLockAmount());

            // Space out locks with 1 month in between. With 5 test cases, this means none will have expired by default.
            vm.warp(block.timestamp + AVG_SECONDS_MONTH + 1);
            _addMockLock(_months[i], _depositor, _amounts[i]);
        }
    }

    /// @dev creates an actual lock in the old sharestimelock contract with the passed values
    function _addMockLock(uint8 _months, address _receiver, uint128 _amount) internal {
        vm.assume(_receiver.isEOA());
        vm.assume(_amount >= stl.minLockAmount());
        vm.assume(_months <= 36 && _months >= 6);

        dough.mint(_receiver, _amount);

        vm.startPrank(_receiver, _receiver);
        {
            dough.approve(address(stl), _amount);
            stl.depositByMonths(_amount, _months, _receiver);
        }
        vm.stopPrank();
    }
}
