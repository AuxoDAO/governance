pragma solidity 0.8.16;

import "@forge-std/Test.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20Upgradeable as IERC20} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {PRV} from "@prv/PRV.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {RollStaker as RollStakerNoUpgrade, IRollStaker} from "./RollStakerNoUpgrade.sol";
import {Bitfields} from "@prv/bitfield.sol";

import "@test/utils.sol";
import {MockRewardsToken as MockERC20} from "@mocks/Token.sol";
import {RollStakerTestInitializer, MockRollStaker} from "../RollStakerTestInitializer.sol";

/**
 * @dev invariant tests assert that the state of a contract never deviates from some
 *      specific conditions ("invariants") that are expected to hold true at all times.
 *
 *      We setup the initial conditions, then foundry will randomise sequences of function
 *      calls and check that the invariants hold true after each call.
 *
 *      Reverts, by default, will not fail the invariant test, so we need to take care that
 *      the initial state is properly setup.
 *
 *      More details on invariant testing: https://github.com/N0xMare/foundry-invariants/tree/main/test
 */
contract RollStakerInvariantTest is RollStakerTestInitializer {
    using Bitfields for Bitfields.Bitfield;

    address internal testUser = address(1);
    address internal testUser2 = address(2);
    address internal testOperator = address(3);

    /// @dev selectors for transactions in the staker
    bytes4[] internal rollSelectors;
    RollStakerNoUpgrade internal rollNoUpgrade;

    function setUp() public override {
        super.setUp();

        rollNoUpgrade = new RollStakerNoUpgrade(address(mockToken));

        vm.label(testUser, "User");
        vm.label(testOperator, "Operator");

        rollNoUpgrade.grantRole(rollNoUpgrade.OPERATOR_ROLE(), testOperator);

        // for the first user, give them some tokens
        mockToken.transfer(testUser, type(uint128).max);
        mockToken.transfer(testUser2, type(uint128).max);

        // then approve the rollstaker on their behalf
        vm.prank(testUser);
        mockToken.approve(address(rollNoUpgrade), type(uint256).max);

        vm.prank(testUser2);
        mockToken.approve(address(rollNoUpgrade), type(uint256).max);

        // check that they will be "active" next round
        assert(!rollNoUpgrade.userIsActive(testUser));

        /// @dev now we need to setup the invariant conditions

        // we target the rollstaker and the deposit token
        targetContract(address(mockToken));
        targetContract(address(rollNoUpgrade));

        // we also need to target the users and the operator
        // the latter is so we can see what happens if the epochs change
        targetSender(testUser);
        targetSender(testUser2);
        targetSender(testOperator);

        // We can also limit targets just to specific functions
        // this is useful to reduce the percentage of reverts or calls to getters
        rollSelectors.push(rollNoUpgrade.deposit.selector);
        rollSelectors.push(rollNoUpgrade.withdraw.selector);
        rollSelectors.push(rollNoUpgrade.quit.selector);
        rollSelectors.push(rollNoUpgrade.depositFor.selector);
        rollSelectors.push(rollNoUpgrade.depositWithSignature.selector);
        rollSelectors.push(rollNoUpgrade.depositForWithSignature.selector);
        rollSelectors.push(rollNoUpgrade.activateNextEpoch.selector);

        targetSelector(FuzzSelector(address(rollNoUpgrade), rollSelectors));
    }

    /**
     * A critical assumption/invariant that must hold is that, if a user has a balance
     * of zero xAUXO in the RollStaker, they MUST be inactive from the current epoch onwards
     */
    function invariantTestZeroBalanceEqInactive() public view {
        uint256 userBalanceInContract = rollNoUpgrade.getTotalBalanceForUser(testUser);
        uint8 currentEpoch = rollNoUpgrade.currentEpochId();
        bool userIsActiveNextEpoch = rollNoUpgrade.userIsActiveForEpoch(testUser, currentEpoch + 1);
        bool userIsActive = rollNoUpgrade.userIsActive(testUser);

        if (userBalanceInContract == 0) {
            assert(!userIsActive);
            assert(!userIsActiveNextEpoch);
        }
    }

    /**
     * This is pretty simple, the user should only ever have an active balance if they are active
     * and should only be inactive if their active balance is zero
     */
    function invariantTestActiveBalanceEqActive() public view {
        uint256 userActiveBalanceInContract = rollNoUpgrade.getActiveBalanceForUser(testUser);
        bool userIsActive = rollNoUpgrade.userIsActive(testUser);

        if (userActiveBalanceInContract > 0) {
            assert(userIsActive);
        } else {
            assert(!userIsActive);
        }
    }

    /**
     * If a user is active next epoch, but not this epoch
     * They must have made a deposit this month, but not have anything carried over
     * Therefore their full balance must be pending
     */
    function invariantTestNotActiveThisEpochActiveNextEqPendingBalanceEqTotal() public view {
        uint256 userTotalBalance = rollNoUpgrade.getTotalBalanceForUser(testUser);
        uint256 userPendingBalance = rollNoUpgrade.getPendingBalanceForUser(testUser);

        uint8 currentEpoch = rollNoUpgrade.currentEpochId();

        bool userIsActiveNextEpoch = rollNoUpgrade.userIsActiveForEpoch(testUser, currentEpoch + 1);
        bool userIsActiveThisEpoch = rollNoUpgrade.userIsActive(testUser);

        if (userIsActiveNextEpoch) {
            assert(userTotalBalance > 0);

            // if the user is active next epoch, but not this epoch
            // they must have a pending balance == total
            if (!userIsActiveThisEpoch) {
                assert(userPendingBalance == userTotalBalance);
            }
        }
    }

    /**
     * Assert that the user's total Locked qty is ALWAYS the sum of their active and pending deposits
     */
    function invariantTestActivePlusPendingIsAlwaysEqDeposited() public view {
        uint256 userTotal = rollNoUpgrade.getTotalBalanceForUser(testUser);
        uint256 userActive = rollNoUpgrade.getActiveBalanceForUser(testUser);
        uint256 userPending = rollNoUpgrade.getPendingBalanceForUser(testUser);

        assert(userTotal == userActive + userPending);
    }

    /**
     * Assert that the total locked by users is always less than or equal to the amount locked in the contract
     * We cannot assert strict equality because users can deposit on behalf of others,
     * and we don't know those addresses ahead of time
     */
    function invariantTestTotalInContractAlwaysGeUserTotal() public view {
        uint256 user1Total = rollNoUpgrade.getTotalBalanceForUser(testUser);
        uint256 user2Total = rollNoUpgrade.getTotalBalanceForUser(testUser2);
        uint256 contractTokenLocked = rollNoUpgrade.getProjectedNextEpochBalance();

        assert(user1Total + user2Total <= contractTokenLocked);
    }

    /**
     * Internal balance of the contract should never exceed the external balance
     * The opposite can be true if users send tokens to the contract directly
     */
    function invariantTestTokenBalanceContactGEContractLocked() public view {
        uint256 contractExternalBalance = mockToken.balanceOf(address(rollNoUpgrade));
        uint256 contractInternalBalance = rollNoUpgrade.getProjectedNextEpochBalance();

        assert(contractExternalBalance >= contractInternalBalance);
    }

    /**
     * Assert that the total pending balance is always less than or equal to the amount pending in the contract for all users
     * We cannot assert strict equality because users can deposit on behalf of others,
     * and we don't know those addresses ahead of time
     */
    function invariantTestEpochPendingGEPendingDeposits() public view {
        uint256 contractPending = rollNoUpgrade.epochPendingBalance();
        uint256 user1Pending = rollNoUpgrade.getPendingBalanceForUser(testUser);
        uint256 user2Pending = rollNoUpgrade.getPendingBalanceForUser(testUser2);

        assert(contractPending >= user1Pending + user2Pending);
    }
}
