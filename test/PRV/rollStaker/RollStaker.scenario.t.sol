pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {RollStaker, IRollStaker} from "@prv/RollStaker.sol";
import {Bitfields} from "@prv/bitfield.sol";

import "@test/utils.sol";
import {MockRewardsToken as MockERC20} from "@mocks/Token.sol";
import {RollStakerTestInitializer, MockRollStaker} from "./RollStakerTestInitializer.sol";

/**
 * @dev this is a more complex test of the rollstaker that should combine the other elements.
 *  In this scenario, we have 2 users across N Epochs
 *  Both users will make deposits and withdrawals across the epochs, and we will test the running totals
 */
contract RollStakerScenarioTest is RollStakerTestInitializer {
    using Bitfields for Bitfields.Bitfield;

    function setUp() public override {
        super.setUp();
    }

    // keep user test data in a struct to avoid stack depth errors
    // @dev 96 bit integer is to avoid getting overflows, it's still a hefty enough number
    // for this kind of test (eq. to each person making billion auxo deposits at a time)
    struct MockUser {
        uint256 pk;
        address addr;
        uint96[10] depositSchedule;
        uint120 currentBalance;
        uint120 initialBalance;
        uint8 firstDepositEpoch;
        uint8 lastDepositEpoch;
        uint120 lastBalance;
        uint8 lastActiveEpoch;
        bool hasMadeFirstDeposit;
    }

    function _initMockUser(
        uint96[10] calldata _depositScheduleTony, /* use 128 bit to prevent overflows */
        uint96[10] calldata _depositScheduleManny
    ) internal returns (MockUser memory tony, MockUser memory manny) {
        // setup a deposit schedule and totals for the guys
        for (uint256 s; s < 10; s++) {
            tony.initialBalance += _depositScheduleTony[s];
            /// @dev uncomment for debug
            // console2.log(_depositScheduleTony[s]);
            manny.initialBalance += _depositScheduleManny[s];
        }

        // we want a sensible amount of deposits
        vm.assume(tony.initialBalance > 1 ether);
        vm.assume(manny.initialBalance > 1 ether);

        tony.pk = 1;
        manny.pk = 2;

        // get the addresses from the PKs
        tony.addr = vm.addr(tony.pk);
        manny.addr = vm.addr(manny.pk);
        vm.label(tony.addr, "TONY");
        vm.label(manny.addr, "MANNY");

        // send the cash over
        mockToken.transfer(tony.addr, tony.initialBalance);
        mockToken.transfer(manny.addr, manny.initialBalance);

        return (tony, manny);
    }

    function testKitchenSink(
        uint8 _startEpoch,
        uint96[10] calldata _depositScheduleTony, /* use 128 bit to prevent overflows */
        uint96[10] calldata _depositScheduleManny
    ) public {
        vm.assume(_startEpoch < 10);
        (MockUser memory tony, MockUser memory manny) = _initMockUser(_depositScheduleTony, _depositScheduleManny);

        // couple of epochs pass with no deposits
        for (uint256 e; e <= _startEpoch; e++) {
            roll.activateNextEpoch();
            vm.warp(block.timestamp + MONTH);
        }

        // pass the first 9 epochs making deposits if the guys have any
        for (uint8 a; a < _depositScheduleTony.length - 1; a++) {
            uint256 tonyDeposit = _depositScheduleTony[a];
            uint256 mannyDeposit = _depositScheduleManny[a];

            uint256 tonyBalancePre = mockToken.balanceOf(tony.addr);
            uint256 mannyBalancePre = mockToken.balanceOf(manny.addr);

            // tony needs to approve
            if (tonyDeposit > 0) {
                vm.startPrank(tony.addr);
                mockToken.approve(address(roll), tonyDeposit);
                roll.deposit(tonyDeposit);
                vm.stopPrank();

                // if first deposit, should not be currently active
                if (!tony.hasMadeFirstDeposit) {
                    assertEq(roll.userIsActive(tony.addr), false);
                    assertEq(roll.lastEpochUserWasActive(tony.addr), 0);
                    tony.firstDepositEpoch = a + _startEpoch;
                    tony.hasMadeFirstDeposit = true;
                }
                assertEq(roll.userIsActiveForEpoch(tony.addr, roll.currentEpochId() + 1), true);
                tony.lastDepositEpoch = _startEpoch + a;
                tony.lastBalance = uint120(roll.getTotalBalanceForUser(tony.addr));
            }

            // manny is a chad and uses the sig
            if (mannyDeposit > 0) {
                uint256 dl = block.timestamp + MONTH;
                bytes32 permitMessage = EIP712HashBuilder.generateTypeHashPermit(
                    manny.addr, address(roll), mannyDeposit, dl, IERC20Permit(address(mockToken))
                );
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(manny.pk, permitMessage);
                vm.prank(manny.addr);
                roll.depositWithSignature(mannyDeposit, dl, v, r, s);

                // if first deposit, should not be currently active
                if (!manny.hasMadeFirstDeposit) {
                    assertEq(roll.userIsActive(manny.addr), false);
                    assertEq(roll.lastEpochUserWasActive(manny.addr), 0);
                    manny.firstDepositEpoch = a + _startEpoch;
                    manny.hasMadeFirstDeposit = true;
                }
                assertEq(roll.userIsActiveForEpoch(manny.addr, roll.currentEpochId() + 1), true);
                manny.lastDepositEpoch = _startEpoch + a;
                manny.lastBalance = uint120(roll.getTotalBalanceForUser(manny.addr));
            }

            // run some checks each epoch
            {
                tony.currentBalance = uint120(mockToken.balanceOf(tony.addr));
                manny.currentBalance = uint120(mockToken.balanceOf(manny.addr));

                assertEq(tony.currentBalance, tonyBalancePre - tonyDeposit);
                assertEq(tony.initialBalance - tony.currentBalance, roll.getTotalBalanceForUser(tony.addr));

                assertEq(manny.currentBalance, mannyBalancePre - mannyDeposit);
                assertEq(manny.initialBalance - manny.currentBalance, roll.getTotalBalanceForUser(manny.addr));
            }

            // go ahead to next epoch
            roll.activateNextEpoch();
            vm.warp(block.timestamp + MONTH);
        }

        // tony attempts to withdraw without reverting - fails
        vm.startPrank(tony.addr);
        {
            uint256 tonyDeposit = tony.depositSchedule[tony.depositSchedule.length - 1];
            if (tonyDeposit > 0) {
                roll.deposit(tonyDeposit);

                // can't withdraw > deposit
                vm.expectRevert(abi.encodeWithSelector(InvalidWithdrawalAmount.selector, tony.addr, tonyDeposit + 1));
                roll.withdraw(tonyDeposit + 1);

                // then succeeds a partial withdraw
                roll.withdraw(tonyDeposit - 1);

                // still active tho
                assertEq(roll.userIsActive(tony.addr), true);
                assertEq(roll.userIsActiveForEpoch(tony.addr, roll.currentEpochId() + 1), true);
            }
        }
        vm.stopPrank();

        // go ahead to next epoch
        roll.activateNextEpoch();
        vm.warp(block.timestamp + MONTH);

        // tony quits by withdrawing his full balacne
        vm.startPrank(tony.addr);
        {
            uint256 tonyWithdraw = roll.getActiveBalanceForUser(tony.addr);
            if (tonyWithdraw > 0) {
                roll.withdraw(tonyWithdraw);
                tony.lastActiveEpoch = roll.currentEpochId() - 1;
            }
        }
        vm.stopPrank();

        // 2 years
        uint8 MOVE_AHEAD_1 = 24;

        for (uint256 e; e <= MOVE_AHEAD_1; e++) {
            roll.activateNextEpoch();
            vm.warp(block.timestamp + MONTH);
        }

        // manny quits after 2 years
        vm.startPrank(manny.addr);
        {
            if (manny.hasMadeFirstDeposit) {
                roll.quit();
                // we quit this epoch, so were active last epoch only
                manny.lastActiveEpoch = roll.currentEpochId() - 1;
            }
        }
        vm.stopPrank();

        // check both inactive and have full balance
        assertEq(mockToken.balanceOf(tony.addr), tony.initialBalance);
        assertEq(mockToken.balanceOf(manny.addr), manny.initialBalance);

        assertEq(roll.getActiveBalanceForUser(tony.addr), 0);
        assertEq(roll.getActiveBalanceForUser(manny.addr), 0);

        // check histories
        // check last active correct
        // check the first active deposit is correct
        uint8 MOVE_AHEAD_2 = 12;
        for (uint256 e; e <= MOVE_AHEAD_2; e++) {
            roll.activateNextEpoch();
            vm.warp(block.timestamp + MONTH);

            assertEq(roll.userIsActive(tony.addr), false);
            assertEq(roll.userIsActive(manny.addr), false);
        }

        assertEq(roll.lastEpochUserWasActive(tony.addr), tony.lastActiveEpoch);
        assertEq(roll.lastEpochUserWasActive(manny.addr), manny.lastActiveEpoch);

        /// @dev uncomment for some debugging
        // console2.log("\n Tony \n");

        // uint[] memory tonyBalances = roll.getUserBalances(tony.addr);
        // for (uint t; t < tonyBalances.length; t++) {
        //     console2.log("[%d]: %d",t, tonyBalances[t]);
        // }

        // console2.log("\n Manny \n");
        // uint[] memory mannyBalances = roll.getUserBalances(manny.addr);
        // for (uint m; m < mannyBalances.length; m++) {
        //     console2.log("[%d]: %d",m, mannyBalances[m]);
        // }
        // if (tony.initialBalance > 10 ether) assert(false);
    }
}
