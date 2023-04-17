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
import "../utils.sol";

contract TestlockerBoost is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ =======

    // test can boostToMax
    function testFuzz_BoostToMax(address _depositor, uint128 _qty, uint8 _months) public {
        _makeDeposit(_depositor, _qty, _months);

        // cache current rewards and data
        uint256 oldRewards = reward.balanceOf(_depositor);
        (uint192 amtBefore,, uint32 lockDurationBefore) = locker.lockOf(_depositor);

        uint256 maxRewards = (locker.getLockMultiplier(locker.maxLockDuration()) * _qty) / 1e18;
        uint256 expectedRewardDiff = maxRewards - (locker.getLockMultiplier(locker.getDuration(_months)) * _qty) / 1e18;

        // execute the boost
        vm.startPrank(_depositor);
        locker.boostToMax();
        vm.stopPrank();

        // determmine max and new rewards
        uint256 newRewards = reward.balanceOf(_depositor);
        (uint192 amtAfter, uint32 lockedAfter, uint32 lockDurationAfter) = locker.lockOf(_depositor);

        // assert expected value for rewards
        assertEq(newRewards, maxRewards);
        assertEq(lockDurationAfter, locker.maxLockDuration());
        assertEq(amtBefore, amtAfter);
        assertEq(lockedAfter, block.timestamp);
        assertEq(newRewards - oldRewards, expectedRewardDiff);

        // 36 month boost to 36 month should see no change
        if (lockDurationBefore == locker.maxLockDuration()) {
            assertEq(newRewards, oldRewards);
            assertEq(lockDurationAfter, lockDurationBefore);
        } else {
            assertGt(newRewards, oldRewards);
            assertGt(lockDurationAfter, lockDurationBefore);
        }
    }

    /**
     * @dev QSP-4: increasing the amount can cause rounding errors in token calculation.
     *      This caused the boostToMax function to revert in the first impelmentation.
     *      This test replicates the bug and tests that new implementations address it.
     */
    function testSmallQtyIncreaseDoesNotBrickBoost(
        address _depositor,
        uint128 _initialDeposit,
        uint128 _secondDeposit,
        uint8 _months
    ) public {
        vm.assume(_secondDeposit > MINIMUM_INCREASE_QTY);
        uint256 totalDeposit = uint256(_initialDeposit) + uint256(_secondDeposit);

        // make the first deposit
        _makeDeposit(_depositor, _initialDeposit, _months);
        (,, uint32 lockDurationBefore) = locker.lockOf(_depositor);

        // transfer before the prank
        deposit.transfer(_depositor, _secondDeposit);

        // increase and then boost to replicate the bug
        uint256 preBoostRewards;
        vm.startPrank(_depositor);
        {
            // increase the amount
            deposit.approve(address(locker), type(uint256).max);
            locker.increaseAmount(_secondDeposit);

            // cache current rewards and data
            preBoostRewards = reward.balanceOf(_depositor);

            // boosting should not revert
            locker.boostToMax();
        }
        vm.stopPrank();

        (uint192 amtAfter, uint32 lockedAfter, uint32 lockDurationAfter) = locker.lockOf(_depositor);

        // determine max and new rewards
        uint256 newRewards = reward.balanceOf(_depositor);
        uint256 maxRewards = (locker.getLockMultiplier(locker.maxLockDuration()) * totalDeposit) / 1e18;
        uint256 expectedRewardDiff = maxRewards - (locker.getLockMultiplier(locker.getDuration(_months)) * totalDeposit) / 1e18;

        // assert expected value for rewards
        assertEq(lockDurationAfter, locker.maxLockDuration());
        assertEq(amtAfter, totalDeposit);
        assertEq(lockedAfter, block.timestamp);
        // assertEq(newRewards - preBoostRewards, expectedRewardDiff);

        /// @dev ALERT: ROUNDING ERROR OF 1 WEI
        assertApproxEqAbs(newRewards, maxRewards, 1);
        assertEq(newRewards, maxRewards);

        if (lockDurationBefore == locker.maxLockDuration()) {
            assertEq(lockDurationAfter, lockDurationBefore);
        } else {
            assertGt(lockDurationAfter, lockDurationBefore);
        }
    }
}
