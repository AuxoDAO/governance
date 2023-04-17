// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {MockRewardsToken} from "../mocks/Token.sol";
import {Migrateable, IMigrateableEvents} from "@governance/Migrator.sol";
import {TestLocker} from "./Setup.t.sol";
import "@test/utils.sol";

contract TestMigrator is Test, IMigrateableEvents {
    TestLocker private locker;

    function setUp() public {
        TestLocker impl = new TestLocker();
        Proxy proxy = new Proxy();
        proxy.setImplementation(address(impl));
        locker = TestLocker(address(proxy));
        locker.initialize();
    }

    function testFuzz_SetMigrator(address _newMigrator, address _caller) public {
        vm.startPrank(_caller);
        if (locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), _caller)) {
            vm.expectEmit(true, false, false, true);
            emit MigratorUpdated(_newMigrator);
            locker.setMigrator(_newMigrator);
            assertEq(_newMigrator, locker.migrator());
        } else {
            vm.expectRevert(bytes(accessControlRevertString(_caller, locker.DEFAULT_ADMIN_ROLE())));
            locker.setMigrator(_newMigrator);
        }
        vm.stopPrank();
    }

    function testFuzz_SetMigration(bool enabled, address _caller) public {
        vm.startPrank(_caller);
        if (locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), _caller)) {
            vm.expectEmit(true, false, false, true);
            emit MigrationEnabledChanged(enabled);
            locker.setMigrationEnabled(enabled);
            assertEq(locker.migrationEnabled(), enabled);
        } else {
            vm.expectRevert(bytes(accessControlRevertString(_caller, locker.DEFAULT_ADMIN_ROLE())));
            locker.setMigrationEnabled(enabled);
        }
        vm.stopPrank();
    }
}
