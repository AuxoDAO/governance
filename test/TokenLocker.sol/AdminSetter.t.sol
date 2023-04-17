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
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";
import "@test/utils.sol";

contract TestlockerAdminSetter is TestlockerSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= ADMIN FUNCTIONS =======

    function testEmergencyUnlock() public {
        locker.triggerEmergencyUnlock();
        assertEq(locker.emergencyUnlockTriggered(), true);
    }

    /// ======= FUZZ =======

    // Test admin setters
    function testFuzz_SetMinLock(uint192 _qty) public {
        vm.expectEmit(false, false, false, true);
        emit MinLockAmountChanged(_qty);
        locker.setMinLockAmount(_qty);
        assertEq(locker.minLockAmount(), _qty);
    }

    function testFuzz_SetWhiteListed(address _user, bool _isWhitelisted) public {
        vm.expectEmit(true, true, false, true);
        emit WhitelistedChanged(_user, _isWhitelisted);
        locker.setWhitelisted(_user, _isWhitelisted);
        assertEq(locker.whitelisted(_user), _isWhitelisted);
    }

    function testFuzz_SetEjectBuffer(uint32 _buffer) public {
        vm.expectEmit(false, false, false, true);
        emit EjectBufferUpdated(_buffer);
        locker.setEjectBuffer(_buffer);
        assertEq(locker.ejectBuffer(), _buffer);
    }

    // Test ownable modifiers
    function testFuzz_AdminFunctionNotCallableByNonAdmin(address _notAdmin) public {
        vm.assume(!locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), _notAdmin));

        bytes memory adminError = bytes(accessControlRevertString(_notAdmin, locker.DEFAULT_ADMIN_ROLE()));

        vm.startPrank(_notAdmin);

        vm.expectRevert(adminError);
        locker.setMinLockAmount(0);

        vm.expectRevert(adminError);
        locker.setWhitelisted(_notAdmin, true);

        vm.expectRevert(adminError);
        locker.triggerEmergencyUnlock();

        vm.expectRevert(adminError);
        locker.setEjectBuffer(0);

        vm.stopPrank();
    }
}
