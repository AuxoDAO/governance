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
import {MockRewardsToken} from "../mocks/Token.sol";
import "../utils.sol";

contract TestlockerEject is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    // test the canEject utility for a single account
    function testFuzz_CanEjectGetter(
        address _depositor,
        uint128 _qty,
        uint8 _months,
        uint32 _buffer,
        address _notDepositor
    ) public {
        // upcast to 64bit so we can ensure the total is less than the overflow qty
        vm.assume(uint64(_buffer) + uint64(_months) * AVG_SECONDS_MONTH < type(uint32).max);
        vm.assume(_notDepositor != _depositor);

        // initial state false
        assertEq(locker.canEject(_depositor), false);

        // set buffer and make a deposit
        locker.setEjectBuffer(_buffer);
        _makeDeposit(_depositor, _qty, _months);

        // still false
        assertEq(locker.canEject(_depositor), false);

        // timewarp 1 minute before - still false
        vm.warp(_months * AVG_SECONDS_MONTH + _buffer - 60);
        assertEq(locker.canEject(_depositor), false);

        // make up the final period
        vm.warp(_months * AVG_SECONDS_MONTH + _buffer + 1);
        assertEq(locker.canEject(_depositor), true);

        TokenLocker.Lock memory lock = locker.getLock(_notDepositor);

        // log the lock using console2.log
        console2.log(lock.lockedAt, lock.lockDuration, lock.amount, block.timestamp);
        console2.log(locker.ejectBuffer());

        // and check this still false for another depositor
        assertEq(locker.canEject(_notDepositor), false);
    }

    function testFuzz_canEject(
        address[2] memory _depositors,
        uint128[2] memory _qtys,
        uint8[2] memory _months,
        uint32 _buffer
    ) public {
        // prevent overflows
        if (uint64(_buffer) + uint64(_months[1]) * AVG_SECONDS_MONTH > type(uint32).max) {
            _buffer = type(uint16).max;
        }

        // assume sorted array makes scenario modelling easier
        vm.assume(_months[0] < _months[1]);
        vm.assume(_depositors[0] != _depositors[1]);
        vm.assume(_depositors[0] != address(0));
        vm.assume(_depositors[1] != address(0));

        uint256 totalQty = uint256(_qtys[0]) + uint256(_qtys[1]);

        uint256 lockerInitialBalance = deposit.balanceOf(address(locker));

        // make our deposits for 2 users
        _makeDeposit(_depositors[0], _qtys[0], _months[0]);
        _makeDeposit(_depositors[1], _qtys[1], _months[1]);

        locker.setEjectBuffer(_buffer);

        // cache some state
        uint rewardSupplyPre = reward.totalSupply();
        uint rewardBalanceDepositor0Pre = reward.balanceOf(_depositors[0]);
        uint rewardBalanceDepositor1Pre = reward.balanceOf(_depositors[1]);

        vm.warp(block.timestamp + _months[0] * AVG_SECONDS_MONTH + _buffer - 1);

        // create dynamic arrays to pass to the eject fn
        address[] memory lockAccounts = new address[](2);
        // lock ids are relative to each account
        lockAccounts[0] = _depositors[0];
        lockAccounts[1] = _depositors[1];

        // try eject - should be no change
        locker.eject(lockAccounts);
        assertEq(deposit.balanceOf(address(locker)), totalQty + lockerInitialBalance);
        assertEq(reward.totalSupply(), rewardSupplyPre);

        // first user should be ejectable
        // @dev some local variables are scoped here to avoid stack too deep
        {
            (, uint256 lockedAt0, uint256 lockDuration0) = locker.lockOf(_depositors[0]);
            vm.warp(lockedAt0 + lockDuration0 + _buffer + 1);
            locker.eject(lockAccounts);
        }

        // account 0 has money back, not account 1
        assertEq(deposit.balanceOf(_depositors[0]), _qtys[0]);
        assertEq(deposit.balanceOf(_depositors[1]), 0);

        // no reward tokens in account 0, account 1 untouched
        assertEq(reward.balanceOf(_depositors[0]), 0);
        assertEq(reward.balanceOf(_depositors[1]), rewardBalanceDepositor1Pre);

        // check the locker
        assertEq(deposit.balanceOf(address(locker)), totalQty + lockerInitialBalance - _qtys[0]);
        assertEq(reward.totalSupply(), rewardSupplyPre - rewardBalanceDepositor0Pre);

        // eject second user
        (, uint256 lockedAt1, uint256 lockDuration1) = locker.lockOf(_depositors[1]);

        vm.warp(lockedAt1 + lockDuration1 + _buffer + 1);
        locker.eject(lockAccounts);

        assertEq(deposit.balanceOf(_depositors[1]), _qtys[1]);
        assertEq(deposit.balanceOf(address(locker)), lockerInitialBalance);

        // account 1 has no reward tokens, and total supply is reduced to reflect
        assertEq(reward.balanceOf(_depositors[1]), 0);
        assertEq(reward.totalSupply(), rewardSupplyPre - rewardBalanceDepositor0Pre - rewardBalanceDepositor1Pre);
    }
}
