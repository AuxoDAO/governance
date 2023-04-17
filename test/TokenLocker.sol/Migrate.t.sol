pragma solidity 0.8.16;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {
    IERC20MintableBurnable,
    TokenLocker,
    IERC20MintableBurnable,
    ITokenLockerEvents,
    IMigrateableEvents
} from "@governance/TokenLocker.sol";
import {TestlockerSetup} from "./Setup.t.sol";
import {MockRewardsToken} from "@mocks/Token.sol";
import {MockMigrator} from "@mocks/MockMigrator.sol";
import "../utils.sol";

contract TestlockerMigrate is TestlockerSetup {
    using IsEOA for address;

    MockMigrator migrator;

    function setUp() public {
        prepareSetup();
        migrator = new MockMigrator(address(locker));
    }

    /// ======= FUZZ ======
    function testFuzz_Migrate(address _depositor, uint128 _qty, uint8 _months) public {
        vm.assume(_qty >= locker.minLockAmount());

        uint256 lockerBalancePre = deposit.balanceOf(address(locker));

        _makeDeposit(_depositor, _qty, _months);
        locker.setMigrationEnabled(true);
        locker.setMigrator(address(migrator));
        vm.prank(_depositor);
        vm.expectEmit(true, false, false, true);
        emit Migrated(_depositor, _qty);
        migrator.execMigration();

        (uint192 amount,,) = locker.lockOf(_depositor);
        assertEq(_qty, deposit.balanceOf(address(migrator)));
        assertEq(false, locker.hasLock(_depositor));
        assertEq(deposit.balanceOf(address(locker)), lockerBalancePre);
        assertEq(0, amount);
    }

    function testFuzz_CannotMigrateByDefault(address _depositor) public {
        vm.prank(_depositor);
        vm.expectRevert("!migrationEnabled");
        migrator.execMigration();
    }

    function testFuzz_CannotMigrateIfMigratorIsNotSet(address _depositor) public {
        _makeDeposit(_depositor, 1 ether, 36);
        locker.setMigrationEnabled(true);

        vm.prank(_depositor);
        vm.expectRevert("!migrator");
        migrator.execMigration();
    }

    function testFuzz_CannotMigrateIfAmountIsZero(address _depositor) public notAdmin(_depositor) {
        locker.setMigrationEnabled(true);
        locker.setMigrator(address(migrator));
        vm.prank(_depositor);
        vm.expectRevert("Lock !exist");
        migrator.execMigration();
    }

    function testFuzz_CannotMigrateIfLockIsExpired(address _depositor) public {
        _makeDeposit(_depositor, 1 ether, 36);
        locker.setMigrationEnabled(true);
        locker.setMigrator(address(migrator));

        vm.warp(block.timestamp + AVG_SECONDS_MONTH * 37);

        vm.prank(_depositor);
        vm.expectRevert("Lock expired");
        migrator.execMigration();
    }

    function testFuzz_OnlyMigratorCanCallMigrate(address _depositor) public notAdmin(_depositor) {
        _makeDeposit(_depositor, 1 ether, 36);

        locker.setMigrationEnabled(true);
        locker.setMigrator(address(migrator));

        vm.prank(_depositor);
        vm.expectRevert("not migrator");
        locker.migrate(_depositor);
    }
}
