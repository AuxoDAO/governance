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

contract TestlockerIncreaseLock is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    // must deposit first
    function testFuzz_CannotIncreaseLockWithoutDeposit(address _depositor, uint128 _qty, uint8 _months)
        public
        notAdmin(_depositor)
    {
        // staking manager has infinite approval and an existing lock
        // it will revert with the incorrect error message and we are not
        // testing for this.
        vm.assume(_qty > 0 && _months > 0);

        vm.startPrank(_depositor);

        vm.expectRevert("Lock !exist");
        locker.increaseAmount(_qty);

        vm.expectRevert("Lock !exist");
        locker.increaseByMonths(_months);

        vm.stopPrank();
    }

    function testFuzz_CannotIncreaseLockWithZeroChange(address _depositor, uint128 _qty, uint8 _monthsOld)
        public
        notAdmin(_depositor)
    {
        _makeDeposit(_depositor, _qty, _monthsOld);
        vm.startPrank(_depositor);

        vm.expectRevert("IA: amount == 0");
        locker.increaseAmount(0);

        vm.expectRevert("IBM: 0 Months");
        locker.increaseByMonths(0);

        vm.stopPrank();
    }

    function testFuzz_CannotIncreaseLockMoreThanMax(
        address _depositor,
        uint128 _qty,
        uint8 _monthsOld,
        uint8 _monthsNew
    ) public {
        vm.assume(uint256(_monthsNew) + uint256(_monthsOld) > locker.maxLockDuration() / AVG_SECONDS_MONTH);
        _makeDeposit(_depositor, _qty, _monthsOld);

        vm.prank(_depositor);
        vm.expectRevert("IUD: Duration > Max");
        locker.increaseByMonths(_monthsNew);
    }

    function testFuzz_TerminateEarlyRevertsWithoutxAUXO(address _depositor, uint128 _qty, uint8 _monthsOld) public {
        _makeDeposit(_depositor, _qty, _monthsOld);
        locker.setPRV(address(0));

        vm.prank(_depositor);
        vm.expectRevert("TE: disabled");
        locker.terminateEarly();
    }

    function testFuzz_CanIncreaseLockQty(address _depositor, uint128 _qtyOld, uint8 _months, uint128 _qtyNew, uint32 _warpTo) public {
        vm.assume(_qtyNew >= MINIMUM_INCREASE_QTY);
        vm.assume(uint256(_qtyOld) + uint256(_qtyNew) < type(uint192).max);
        vm.assume(_warpTo < _months * AVG_SECONDS_MONTH);

        _makeDeposit(_depositor, _qtyOld, _months);

        vm.warp(_warpTo);

        uint256 rewardBalanceOld = reward.balanceOf(_depositor);

        TokenLocker.Lock memory lockPre = _fetchLock(_depositor);

        deposit.transfer(_depositor, _qtyNew);

        vm.startPrank(_depositor);
        {
            deposit.approve(address(locker), _qtyNew);
            vm.expectEmit(false, false, true, true);
            emit IncreasedAmount(_qtyNew, _depositor);
            locker.increaseAmount(_qtyNew);
        }
        vm.stopPrank();

        uint256 rewardBalanceNew = reward.balanceOf(_depositor);
        TokenLocker.Lock memory lockPost = _fetchLock(_depositor);

        // the expected reward balance at the end of this should be:
        // current reward balance + (new token * current multiplier)
        uint256 expectedRewardBalance = rewardBalanceOld + (_qtyNew * locker.maxRatioArray(_months) / 1e18);

        // reward increases as expected
        assertEq(rewardBalanceNew, expectedRewardBalance);

        // deposit increases as expected
        assertEq(lockPre.amount, _qtyOld);
        assertEq(lockPost.amount, uint(_qtyOld) + uint(_qtyNew));

        // duration unchanged
        assertEq(lockPre.lockDuration, lockPost.lockDuration);

        // lockedAt is set to now
        assertEq(lockPost.lockedAt, _warpTo);
    }

    function testCannotGovernanceAttack(address _depositor) public {
        // make the min deposit for the max time
        _makeDeposit(_depositor, uint128(locker.minLockAmount()), 36);

        // wait 36 - delta months
        vm.warp(36 * AVG_SECONDS_MONTH - 1);

        // increase lock to max
        deposit.transfer(_depositor, deposit.balanceOf(address(this)));

        vm.startPrank(_depositor);
        {
            deposit.approve(address(locker), deposit.balanceOf(_depositor));
            locker.increaseAmount(uint192(deposit.balanceOf(_depositor)));
        }
        vm.stopPrank();

        // warp the final amount
        vm.warp(36 * AVG_SECONDS_MONTH + 1 days);

        // try to withdraw
        vm.prank(_depositor);
        vm.expectRevert("Lock !expired");
        locker.withdraw();

        // because lock should be restarted
        assertEq(locker.getLock(_depositor).lockedAt, 36 * AVG_SECONDS_MONTH - 1);
    }

    function testFuzz_CanIncreaseLockDuration(address _depositor, uint128 _qty, uint8 _monthsOld, uint8 _monthsNew, uint32 _warpTo)
        public
    {
        vm.assume(uint16(_monthsOld) + uint16(_monthsNew) <= locker.maxLockDuration() / AVG_SECONDS_MONTH);
        vm.assume(_monthsNew > 0);
        vm.assume(_warpTo < _monthsOld * AVG_SECONDS_MONTH);

        _makeDeposit(_depositor, _qty, _monthsOld);

        vm.warp(_warpTo);

        uint32 duration = locker.getDuration(_monthsOld + _monthsNew);
        TokenLocker.Lock memory lockPre = _fetchLock(_depositor);

        vm.prank(_depositor);
        vm.expectEmit(false, false, false, true);
        emit IncreasedDuration(_qty, duration, lockPre.lockedAt, _depositor);
        locker.increaseByMonths(_monthsNew);

        TokenLocker.Lock memory lockPost = _fetchLock(_depositor);

        uint256 rewardBalanceNew = reward.balanceOf(_depositor);

        // the expected reward balance at the end of this should be:
        // quantity deposited * new multiplier
        // the new multiplier should be monthsOld + monthsNew
        uint256 expectedRewardBalance = _qty * locker.maxRatioArray(_monthsOld + _monthsNew) / 1e18;

        // reward increases as expected
        assertEq(rewardBalanceNew, expectedRewardBalance);

        // duration increases
        assertEq(lockPre.lockDuration, locker.getDuration(_monthsOld));
        assertEq(lockPost.lockDuration, locker.getDuration(_monthsOld + _monthsNew));

        // rest of lock stays the same
        assertEq(lockPre.amount, lockPost.amount);
        assertEq(lockPre.lockedAt, lockPost.lockedAt);
    }

    function testFuzz_CannotIncreaseLockQtyBelowMin(address _depositor, uint128 _qtyOld, uint8 _months) public {
        // 36 months will never revert because of division by 1
        vm.assume(_months < locker.maxLockDuration() / AVG_SECONDS_MONTH);
        _makeDeposit(_depositor, _qtyOld, _months);

        // mathematically, this is the condition that must be violated to cause a zero reward increase
        uint192 willRevertQty = uint192(1e18 / (locker.maxRatioArray(_months)));
        // meaning that this should never revert
        uint192 wontRevertQty = willRevertQty + 1;

        assertLe(willRevertQty, MINIMUM_INCREASE_QTY);

        deposit.transfer(_depositor, wontRevertQty);

        vm.startPrank(_depositor);
        {
            deposit.approve(address(locker), wontRevertQty);

            vm.expectRevert("IA: 0 veShares");
            locker.increaseAmount(willRevertQty);

            // finally, check that we don't revert by increasing by just 1 wei
            locker.increaseAmount(wontRevertQty);
        }
        vm.stopPrank();
    }

    /// ===== SIGNATURES =====

    function testFuzz_CanIncreaseQtyWithSig(
        uint128 _depositorPk,
        uint128 _qtyOld,
        uint128 _qtyNew,
        uint8 _monthsOld,
        uint256 _deadline,
        uint32 _warpTo
    ) public {
        vm.assume(_qtyNew > MINIMUM_INCREASE_QTY);
        vm.assume(_depositorPk > 0);
        vm.assume(_warpTo < _monthsOld * AVG_SECONDS_MONTH);
        vm.assume(_deadline > _warpTo);

        address _depositor = vm.addr(_depositorPk);

        _makeDeposit(_depositor, _qtyOld, _monthsOld);
        vm.warp(_warpTo);

        uint256 rewardBalanceOld = reward.balanceOf(_depositor);
        deposit.transfer(_depositor, _qtyNew);

        bytes32 permitMessage =
            EIP712HashBuilder.generateTypeHashPermit(_depositor, address(locker), _qtyNew, _deadline, deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_depositorPk, permitMessage);

        vm.prank(_depositor);
        locker.increaseAmountWithSignature(_qtyNew, _deadline, v, r, s);

        uint256 rewardBalanceNew = reward.balanceOf(_depositor);
        // the expected reward balance at the end of this should be:
        // current reward balance + (new token * current multiplier)
        uint256 expectedRewardBalance = rewardBalanceOld + (_qtyNew * locker.maxRatioArray(_monthsOld) / 1e18);

        // reward increases as expected
        assertEq(rewardBalanceNew, expectedRewardBalance);
        assertEq(locker.getLock(_depositor).lockedAt, _warpTo);
    }

    /// ======= Rounding =======


    // how many deposits to make
    uint private constant RUNS = 50;

    /**
     * @dev make repeated small increaseAmounts and check how rounding errors stack up
     */
    function testFuzz_repeatedIncreasesDoNotCauseRoundingErrors(
        address _depositor,
        uint128 _qtyOld,
        uint8 _months,
        uint128[RUNS] memory _qtyNews
    ) public {
        // bound the qtyNews to be at least the minimum increase
        for (uint q; q < _qtyNews.length; q++) {
            if(_qtyNews[q] < MINIMUM_INCREASE_QTY) _qtyNews[q] = uint128(MINIMUM_INCREASE_QTY);
        }
        vm.assume(_qtyOld > 0);
        vm.assume(_months < locker.maxLockDuration() / AVG_SECONDS_MONTH);

        _makeDeposit(_depositor, _qtyOld, _months);
        // the expected reward balance at the end of this should be:
        uint256 expectedRewardBalanceOld = ((_qtyOld) * locker.maxRatioArray(_months)) / 1e18;

        // reward increases as expected
        assertEq(reward.balanceOf(_depositor), expectedRewardBalanceOld);

        deposit.transfer(_depositor, deposit.balanceOf(address(this)));
        uint total;
        vm.startPrank(_depositor);
        {
            // increase the amount
            deposit.approve(address(locker), type(uint256).max);
            for (uint q; q < _qtyNews.length; q++) {
                total += _qtyNews[q];
                locker.increaseAmount(_qtyNews[q]);
            }
        }
        vm.stopPrank();

        // reward increases as expected
        uint256 expectedRewardBalance =  ((_qtyOld + total) * locker.maxRatioArray(_months)) / 1e18;

        // delta shoud not exceed the number of runs
        assertApproxEqAbs(reward.balanceOf(_depositor), expectedRewardBalance, RUNS);
    }


    /**
     * @dev make repeated small increaseUnlockDurations and check how rounding errors stack up
     */
    function testFuzz_repeatedIncreasesDurationDoNotCauseRoundingErrors(
        address _depositor,
        uint128 _qty
    ) public {

        vm.assume(_qty > 0);

        _makeDeposit(_depositor, _qty, 6);
        // the expected reward balance at the end of this should be:
        uint256 expectedRewardBalanceOld = ((_qty) * locker.maxRatioArray(6)) / 1e18;

        // reward increases as expected
        assertEq(reward.balanceOf(_depositor), expectedRewardBalanceOld);

        deposit.transfer(_depositor, deposit.balanceOf(address(this)));

        vm.startPrank(_depositor);
        {
            // increase the amount by 1 month at a time
            for (uint q = 1; q < 30; q++) {
                locker.increaseByMonths(1);
                uint256 expectedRewardBalance =  ((_qty) * locker.maxRatioArray(q+6)) / 1e18;
                assertEq(reward.balanceOf(_depositor), expectedRewardBalance);
            }
        }
        vm.stopPrank();
    }

    /**
     * @dev use random boolean array to sequentially increase both amount and duration and see how rounding errors stack up
     */
    uint private constant RUNS_2 = 50;
    function testFuzz_repeatedIncreasesInBothDoesntCauseIssues(
        address _depositor,
        uint128 _qtyOld,
        uint128[RUNS_2] memory _qtyNews,
        bool[RUNS_2] memory _increaseAmount
    ) public {
        // bound the qtyNews to be at least the minimum increase
        for (uint q; q < _qtyNews.length; q++) {
            if(_qtyNews[q] < MINIMUM_INCREASE_QTY) _qtyNews[q] = uint128(MINIMUM_INCREASE_QTY);
        }
        vm.assume(_qtyOld > 0);

        _makeDeposit(_depositor, _qtyOld, 6);
        // the expected reward balance at the end of this should be:
        uint256 expectedRewardBalanceOld = ((_qtyOld) * locker.maxRatioArray(6)) / 1e18;

        // reward increases as expected
        assertEq(reward.balanceOf(_depositor), expectedRewardBalanceOld);

        deposit.transfer(_depositor, deposit.balanceOf(address(this)));

        // random walk through increasing the amount and duration
        // should not revert
        uint total;
        uint months = 6;
        vm.startPrank(_depositor);
        {
            deposit.approve(address(locker), type(uint256).max);
            for (uint q; q < _qtyNews.length; q++) {
                if (q > 29 || _increaseAmount[q]) {
                    total += _qtyNews[q];
                    locker.increaseAmount(_qtyNews[q]);
                }
                else {
                    months += 1;
                    locker.increaseByMonths(1);
                }
            }
        }
        vm.stopPrank();

        // reward increases as expected
        uint256 expectedRewardBalance =  ((_qtyOld + total) * locker.maxRatioArray(months)) / 1e18;

        // delta shoud not exceed the number of runs
        assertApproxEqAbs(reward.balanceOf(_depositor), expectedRewardBalance, RUNS_2);
    }
}
