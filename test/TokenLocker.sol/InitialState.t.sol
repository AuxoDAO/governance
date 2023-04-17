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

contract TestlockerInitialState is TestlockerSetup {
    function setUp() public {
        prepareSetup();
    }
    /// ======= INITIAL STATE =======

    // test the intializer reverts if min >= max
    function testInitialStateRevertsMinGteMax(
        ERC20 _depositToken,
        IERC20MintableBurnable _rewardsToken,
        uint32 _minLockDuration,
        uint32 _maxLockDuration,
        uint192 _minLockAmount
    ) public {
        vm.assume(_minLockDuration >= _maxLockDuration);
        TokenLocker freshlocker = _deployLockerUninitialized();

        vm.expectRevert("Initialze: min>=max");
        freshlocker.initialize(_depositToken, _rewardsToken, _minLockDuration, _maxLockDuration, _minLockAmount);
    }

    // test the simple state variables
    function testInitialStateVariables(
        ERC20 _depositToken,
        IERC20MintableBurnable _rewardsToken,
        uint32 _minLockDuration,
        uint32 _maxLockDuration,
        uint192 _minLockAmount,
        address _checkMapping,
        address _xAUXO
    ) public {
        vm.assume(_minLockDuration < _maxLockDuration);

        TokenLocker freshlocker =
            _deployLocker(_depositToken, _rewardsToken, _minLockDuration, _maxLockDuration, _minLockAmount);
        freshlocker.setPRV(_xAUXO);

        assertEq(address(_depositToken), address(freshlocker.depositToken()));
        assertEq(address(_rewardsToken), address(freshlocker.veToken()));
        assertEq(_minLockDuration, freshlocker.minLockDuration());
        assertEq(_maxLockDuration, freshlocker.maxLockDuration());
        assertEq(_minLockAmount, freshlocker.minLockAmount());
        assertEq(freshlocker.emergencyUnlockTriggered(), false);
        assertEq(freshlocker.whitelisted(_checkMapping), false);
        assertEq(freshlocker.PRV(), _xAUXO);

        // access control
        assertEq(freshlocker.hasRole(locker.DEFAULT_ADMIN_ROLE(), address(this)), true);
        assertEq(freshlocker.getRoleMemberCount(locker.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(freshlocker.getRoleMemberCount(locker.COMPOUNDER_ROLE()), 0);
    }

    // test the ratio array set correctly
    function testInitialStateRatioArray(
        ERC20 _depositToken,
        IERC20MintableBurnable _rewardsToken,
        uint32 _minLockDuration,
        uint32 _maxLockDuration,
        uint192 _minLockAmount
    ) public {
        vm.assume(_minLockDuration < _maxLockDuration);
        TokenLocker freshlocker =
            _deployLocker(_depositToken, _rewardsToken, _minLockDuration, _maxLockDuration, _minLockAmount);

        // check deployer
        uint256 prev;
        for (uint256 m; m < 37; m++) {
            uint256 multiplier = freshlocker.maxRatioArray(m);
            assertGt(multiplier, prev);
            assertEq(freshlocker.getDuration(m), AVG_SECONDS_MONTH * m);
            if (m == 36) assertEq(multiplier, 1e18);
            prev = multiplier;
        }
    }
}
