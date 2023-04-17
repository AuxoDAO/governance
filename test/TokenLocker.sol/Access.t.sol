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

contract TestlockerAccess is TestlockerSetup {
    function setUp() public {
        prepareSetup();
    }

    // admin getter is as expected
    function testAdminGetter() public {
        assertEq(locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), address(this)), true);
        assertEq(locker.getAdmin(), address(this));
    }
}
