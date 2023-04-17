pragma solidity 0.8.16;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {
    IERC20MintableBurnable,
    TokenLocker,
    IERC20MintableBurnable,
    ITokenLockerEvents,
    IMigrateableEvents
} from "@governance/TokenLocker.sol";
import {TestlockerSetup, DelegateDeposit} from "./Setup.t.sol";
import "../utils.sol";

contract TestlockerWithdraw is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ =======

    function testFuzz_CannotMakeEmptyWithdraw() public {
        vm.expectRevert("Lock !exist");
        locker.withdraw();
    }

    // cannot withdraw early
    function testFuzz_CannotWithdrawEarly(address _depositor, uint128 _qty, uint8 _months, uint32 _secondsToTimeTravel)
        public
    {
        vm.assume(_secondsToTimeTravel <= _months * AVG_SECONDS_MONTH);

        _makeDeposit(_depositor, _qty, _months);

        // travel to any time in future before lock expires
        vm.warp(_secondsToTimeTravel);

        vm.startPrank(_depositor);

        vm.expectRevert("Lock !expired");
        locker.withdraw();

        vm.stopPrank();
    }

    // but can after that
    function testFuzz_CanWithdrawOtherwise(address _depositor, uint128 _qty, uint8 _months, uint32 _secondsToTimeTravel)
        public
    {
        vm.assume(_secondsToTimeTravel > _months * AVG_SECONDS_MONTH);

        _makeDeposit(_depositor, _qty, _months);

        // travel to any time in future after lock expires
        vm.warp(_secondsToTimeTravel);

        vm.startPrank(_depositor);

        locker.withdraw();

        vm.stopPrank();

        assertEq(reward.balanceOf(_depositor), 0);
        assertEq(deposit.balanceOf(_depositor), _qty);

        (uint256 amount, uint32 lockedAt, uint32 lockDuration) = locker.lockOf(_depositor);
        assertEq(amount, 0);
        assertEq(lockedAt, 0);
        assertEq(lockDuration, 0);
    }
}
