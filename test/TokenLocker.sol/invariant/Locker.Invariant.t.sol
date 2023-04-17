// pragma solidity 0.8.16;

import "@forge-std/Test.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20Upgradeable as IERC20} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {PRV} from "@prv/PRV.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {TokenLocker as TokenLockerNoUpgrade} from "./LockerNonUpgradeable.sol";
import {Bitfields} from "@prv/bitfield.sol";
import {TestlockerSetup} from "../Setup.t.sol";

import "@test/utils.sol";
import {MockRewardsToken as MockERC20} from "@mocks/Token.sol";

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
contract RollStakerInvariantTest is TestlockerSetup {
    using Bitfields for Bitfields.Bitfield;

    address internal testUser = address(1);
    address internal testUser2 = address(2);
    address internal testAdmin = address(3);

    /// @dev selectors for transactions in the staker
    bytes4[] internal selectors;
    TokenLockerNoUpgrade internal lockerNU;

    function setUp() public {
        // setup the deposit and reward tokens
        deposit = new Auxo();
        deposit.mint(address(this), type(uint256).max);

        lockerNU = new TokenLockerNoUpgrade();
        reward = new ARV(address(lockerNU));
        lsd = _deployPRV(address(deposit));

        // initialize
        lockerNU.initialize(
            deposit, IERC20MintableBurnable(address(reward)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 100
        );

        lockerNU.setPRV(address(lsd));

        vm.label(testUser, "User1");
        vm.label(testUser2, "User2");
        vm.label(testAdmin, "Admin");

        lockerNU.grantRole(lockerNU.COMPOUNDER_ROLE(), testAdmin);
        lockerNU.transferOwnership(testAdmin);

        // give users some tokens
        deposit.transfer(testUser, type(uint128).max);
        deposit.transfer(testUser2, type(uint128).max);

        // then approve the locker on their behalf
        vm.prank(testUser);
        deposit.approve(address(lockerNU), type(uint256).max);

        vm.prank(testUser2);
        deposit.approve(address(lockerNU), type(uint256).max);

        /// @dev now we need to setup the invariant conditions

        // we target the locker
        targetContract(address(lockerNU));

        // we also need to target the users and the operator
        targetSender(testUser);
        targetSender(testUser2);
        targetSender(testAdmin);

        // We can also limit targets just to specific functions
        // this is useful to reduce the percentage of reverts or calls to getters
        // selectors.push(lockerNU.withdraw.selector);
        // targetSelector(FuzzSelector(address(lockerNU), selectors));
    }

    /**
     * We expect the total supply of the reward token to be less than or equal to the amount of deposit tokens
     */
    function invariantTestRewardTotalSupplyLEDepositTokenLocked() public view {
        uint256 totalSupply = reward.totalSupply();
        uint256 locked = deposit.balanceOf(address(lockerNU));

        assert(totalSupply <= locked);
    }

    /**
     * Anyone who does NOT have a lock should NOT have a reward balance
     * Equally, anyone who HAS a lock SHOULD have a reward balance
     */
    function invariantTestNobodyWithoutALockHasARewardBalanceAndViceVersa() public view {
        TokenLockerNoUpgrade.Lock memory lockUser1 = lockerNU.getLock(testUser);

        if (lockUser1.amount == 0) assert(reward.balanceOf(testUser) == 0);

        if (lockUser1.amount > 0) assert(reward.balanceOf(testUser) > 0);
    }

    function _calculateExpectedReward(address _user) internal view returns (uint256) {
        TokenLockerNoUpgrade.Lock memory lockUser = lockerNU.getLock(_user);
        return lockerNU.previewDepositByMonths(lockUser.amount, lockUser.lockDuration, _user);
    }

    /**
     * If the user's lock duration is equal to the maximum lock duration, then the reward token should always be equal to the deposit token
     */
    function invariantTestRewardAlwaysEqExpected() public view {
        TokenLockerNoUpgrade.Lock memory lockUser1 = lockerNU.getLock(testUser);
        TokenLockerNoUpgrade.Lock memory lockUser2 = lockerNU.getLock(testUser);

        uint user1RewardBalance = reward.balanceOf(testUser);
        uint user2RewardBalance = reward.balanceOf(testUser2);

        uint expectedUser1Reward = _calculateExpectedReward(testUser);
        uint expectedUser2Reward = _calculateExpectedReward(testUser2);

        assert(user1RewardBalance == expectedUser1Reward);
        assert(user2RewardBalance == expectedUser2Reward);

        if (lockUser1.lockDuration == lockerNU.maxLockDuration()) assert(lockUser1.amount == reward.balanceOf(testUser));
        if (lockUser2.lockDuration == lockerNU.maxLockDuration()) assert(lockUser2.amount == reward.balanceOf(testUser2));
    }
}
