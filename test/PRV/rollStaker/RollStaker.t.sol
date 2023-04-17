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
import {RollStakerTestInitializer} from "./RollStakerTestInitializer.sol";

contract RollStakerTest is RollStakerTestInitializer {
    using Bitfields for Bitfields.Bitfield;

    function setUp() public override {
        super.setUp();
    }

    function testDepositRollStaker(uint120 _amount, address _depositor) public notAdmin(_depositor) {
        // because we are splitting into 3 separate deposits
        // this is equivalent to ensuring no deposit is zero
        // which will revert - we already have separate tests for this
        vm.assume((_amount / 3) > 0);
        vm.assume(_amount < type(uint128).max);
        vm.assume(_depositor != address(0) && _depositor != address(this));

        mockToken.transfer(_depositor, _amount);

        uint8 currentEpochId = roll.currentEpochId();
        uint8 nextEpochId = currentEpochId + 1;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);

            roll.deposit(_amount / 3);
            roll.deposit(_amount / 3);
        }
        vm.stopPrank();

        // adding this way will mean the expected should exactly match the contract value
        // otherwise we get rounding errors of 1 wei from doing (_amount * 2) / 3
        uint256 expectedDepositTotal = (_amount / 3) + (_amount / 3);

        // this should equal the remaining balance of the depositor
        // we will check this at the end of the test
        uint256 expectedBalanceRemaining = _amount - expectedDepositTotal;

        // assertions in current epoch
        assertEq(roll.userIsActiveForEpoch(_depositor, currentEpochId), false);
        assertEq(roll.userIsActiveForEpoch(_depositor, nextEpochId), true);
        assertEq(roll.userIsActiveForEpoch(_depositor, nextEpochId + 1), true);

        assertEq(roll.getActiveBalanceForUser(_depositor), 0);
        assertEq(roll.getPendingBalanceForUser(_depositor), expectedDepositTotal);
        assertEq(roll.getTotalBalanceForUser(_depositor), expectedDepositTotal);

        assertEq(roll.getCurrentEpochBalance(), 0);
        assertEq(roll.epochPendingBalance(), expectedDepositTotal);
        assertEq(roll.getProjectedNextEpochBalance(), expectedDepositTotal);
        assertEq(roll.getEpochBalanceWithProjection(currentEpochId), 0);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId), expectedDepositTotal);

        assertEq(mockToken.balanceOf(_depositor), expectedBalanceRemaining);
        assertEq(mockToken.balanceOf(address(roll)), expectedDepositTotal);

        roll.activateNextEpoch();

        vm.prank(_depositor);
        vm.expectEmit(true, true, false, true);
        emit Deposited(_depositor, _depositor, nextEpochId + 1, expectedBalanceRemaining);
        roll.deposit(expectedBalanceRemaining);

        // assertions in next epoch
        assertEq(roll.getActiveBalanceForUser(_depositor), expectedDepositTotal);
        assertEq(roll.getPendingBalanceForUser(_depositor), expectedBalanceRemaining);
        assertEq(roll.getTotalBalanceForUser(_depositor), _amount);

        assertEq(roll.getCurrentEpochBalance(), expectedDepositTotal);
        assertEq(roll.epochPendingBalance(), expectedBalanceRemaining);
        assertEq(roll.getProjectedNextEpochBalance(), _amount);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId), expectedDepositTotal);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId + 1), _amount);

        assertEq(mockToken.balanceOf(_depositor), 0);
        assertEq(mockToken.balanceOf(address(roll)), _amount);
    }

    function testDepositFor(uint120 _amount, address _depositor, address _receiver) public notAdmin(_depositor) {
        // because we are splitting into 3 separate deposits
        // this is equivalent to ensuring no deposit is zero
        // which we already check for
        vm.assume((_amount / 3) > 0);
        vm.assume(_amount < type(uint128).max);
        vm.assume(_depositor != address(0) && _depositor != address(this));
        vm.assume(_receiver != address(0) && _receiver != address(this));
        vm.assume(_receiver != _depositor);

        mockToken.transfer(_depositor, _amount);

        uint8 currentEpochId = roll.currentEpochId();
        uint8 nextEpochId = currentEpochId + 1;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);

            roll.depositFor(_amount / 3, _receiver);
            roll.depositFor(_amount / 3, _receiver);
        }
        vm.stopPrank();

        // see the test above for why we calculate this way
        uint256 expectedDepositTotal = (_amount / 3) + (_amount / 3);
        uint256 expectedBalanceRemaining = _amount - expectedDepositTotal;

        assertEq(roll.userIsActiveForEpoch(_depositor, currentEpochId), false);
        assertEq(roll.userIsActiveForEpoch(_receiver, currentEpochId), false);

        assertEq(roll.userIsActiveForEpoch(_receiver, nextEpochId), true);

        assertEq(roll.getActiveBalanceForUser(_depositor), 0);
        assertEq(roll.getTotalBalanceForUser(_depositor), 0);

        assertEq(roll.getActiveBalanceForUser(_receiver), 0);
        assertEq(roll.getPendingBalanceForUser(_receiver), expectedDepositTotal);
        assertEq(roll.getTotalBalanceForUser(_receiver), expectedDepositTotal);

        assertEq(roll.getCurrentEpochBalance(), 0);
        assertEq(roll.epochPendingBalance(), expectedDepositTotal);
        assertEq(roll.getProjectedNextEpochBalance(), expectedDepositTotal);
        assertEq(roll.getEpochBalanceWithProjection(currentEpochId), 0);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId), expectedDepositTotal);

        assertEq(mockToken.balanceOf(_depositor), expectedBalanceRemaining);
        assertEq(mockToken.balanceOf(address(roll)), expectedDepositTotal);

        roll.activateNextEpoch();

        vm.prank(_depositor);
        vm.expectEmit(true, true, false, true);
        emit Deposited(_depositor, _receiver, nextEpochId + 1, expectedBalanceRemaining);
        roll.depositFor(expectedBalanceRemaining, _receiver);

        assertEq(roll.getActiveBalanceForUser(_receiver), expectedDepositTotal);
        assertEq(roll.getPendingBalanceForUser(_receiver), expectedBalanceRemaining);
        assertEq(roll.getTotalBalanceForUser(_receiver), _amount);

        assertEq(roll.getCurrentEpochBalance(), expectedDepositTotal);
        assertEq(roll.epochPendingBalance(), expectedBalanceRemaining);

        assertEq(roll.getProjectedNextEpochBalance(), _amount);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId), expectedDepositTotal);
        assertEq(roll.getEpochBalanceWithProjection(nextEpochId + 1), _amount);

        assertEq(mockToken.balanceOf(_depositor), 0);
        assertEq(mockToken.balanceOf(address(roll)), _amount);
    }

    function testRevertDeposit(uint120 _amount, address _depositor, uint256 _withdrawAmount)
        public
        notAdmin(_depositor)
    {
        vm.assume(_amount > 0);
        vm.assume(_withdrawAmount > 0 && _withdrawAmount <= _amount);
        vm.assume(_amount < type(uint128).max);

        vm.assume(_depositor != address(0) && _depositor != address(this) && _depositor != address(roll));

        mockToken.transfer(_depositor, _amount);

        uint8 currentEpochId = roll.currentEpochId();
        uint8 nextEpochId = currentEpochId + 1;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(_amount);
        }
        vm.stopPrank();

        assertEq(mockToken.balanceOf(_depositor), 0);
        assertEq(mockToken.balanceOf(address(roll)), _amount);
        assertEq(roll.userIsActiveForEpoch(_depositor, nextEpochId), true);
        assertEq(roll.getActivations(_depositor).isActive(nextEpochId), true);
        assertEq(roll.getActivations(_depositor).isActive(currentEpochId), false);

        vm.prank(_depositor);
        roll.withdraw(_withdrawAmount);

        assertEq(mockToken.balanceOf(_depositor), _withdrawAmount);
        assertEq(mockToken.balanceOf(address(roll)), _amount - _withdrawAmount);
    }

    function testRevertDepositActiveUserStaysActive(uint120 _amount, address _depositor) public notAdmin(_depositor) {
        // splitting into 2 deposits
        vm.assume((_amount / 2) > 0);
        vm.assume(_amount < type(uint128).max);

        mockToken.transfer(_depositor, _amount);

        uint256 firstDeposit = _amount / 2;
        uint256 secondDeposit = _amount - firstDeposit;

        // our initial deposit to activate the user
        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(firstDeposit);
        }
        vm.stopPrank();

        // next epoch moves user to active
        roll.activateNextEpoch();

        // second deposit
        vm.prank(_depositor);
        roll.deposit(secondDeposit);

        // changed my mind
        vm.prank(_depositor);
        roll.withdraw(secondDeposit);

        // user should be active this epoch and onwards, because they reverted
        // an amount previously deposited, and were already active
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId()), true);
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId() + 1), true);
    }

    function testRevertDepositInActiveUserGoesBackToInactive(uint120 _amount, address _depositor)
        public
        notAdmin(_depositor)
    {
        // splitting into 2 deposits
        vm.assume((_amount / 2) > 0);
        vm.assume(_amount < type(uint128).max);

        mockToken.transfer(_depositor, _amount);

        uint256 firstDeposit = _amount / 2;
        uint256 secondDeposit = _amount - firstDeposit;

        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId()), false);
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId() + 1), false);

        // our initial deposit to activate the user
        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(firstDeposit);
        }
        vm.stopPrank();

        // next epoch moves user to active
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId()), false);
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId() + 1), true);

        // second deposit
        vm.prank(_depositor);
        roll.deposit(secondDeposit);

        // changed my mind on that - but I'm still active next epoch because I have some $$ in there
        vm.prank(_depositor);
        roll.withdraw(secondDeposit);

        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId()), false);
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId() + 1), true);

        vm.prank(_depositor);
        roll.withdraw(firstDeposit);

        // user should be active this epoch and onwards, because they
        // activated this epoch and now they are deactivating
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId()), false);
        assertEq(roll.userIsActiveForEpoch(_depositor, roll.currentEpochId() + 1), false);
    }

    function testWithdraw(uint120 _amount, address _depositor, uint256 _withdrawAmount) public notAdmin(_depositor) {
        vm.assume(_amount > 0);
        vm.assume(_withdrawAmount > 0);
        vm.assume(_amount >= _withdrawAmount);
        vm.assume(_amount < type(uint128).max);
        vm.assume(_depositor != address(0) && _depositor != address(this) && _depositor != address(roll));

        mockToken.transfer(_depositor, _amount);

        uint8 currentEpochId = roll.currentEpochId();
        uint8 nextEpochId = currentEpochId + 1;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(_amount);
        }
        vm.stopPrank();

        assertEq(mockToken.balanceOf(_depositor), 0);
        assertEq(mockToken.balanceOf(address(roll)), _amount);
        assertEq(roll.getActiveBalanceForUser(_depositor), 0);
        assertEq(roll.getTotalBalanceForUser(_depositor), _amount);

        roll.activateNextEpoch();

        assertEq(roll.getActiveBalanceForUser(_depositor), _amount);
        assertEq(roll.getTotalBalanceForUser(_depositor), _amount);

        vm.startPrank(_depositor);
        if (_withdrawAmount == _amount) {
            vm.expectEmit(true, true, false, true);
            emit Exited(_depositor, nextEpochId);
        } else {
            vm.expectEmit(true, true, false, true);
            emit Withdrawn(_depositor, nextEpochId, _withdrawAmount);
        }
        roll.withdraw(_withdrawAmount);
        vm.stopPrank();

        uint256 remaining = _amount - _withdrawAmount;

        assertEq(mockToken.balanceOf(_depositor), _withdrawAmount);
        assertEq(mockToken.balanceOf(address(roll)), remaining);
        assertEq(roll.getActiveBalanceForUser(_depositor), remaining);

        // full withdraw should deactivate
        if (remaining == 0) {
            assertEq(roll.getActivations(_depositor).isActive(nextEpochId), false);
            assertEq(roll.getActivations(_depositor).isActive(nextEpochId + 1), false);
        } else {
            assertEq(roll.getActivations(_depositor).isActive(nextEpochId), true);
            assertEq(roll.getActivations(_depositor).isActive(nextEpochId + 1), true);
        }
    }

    function testPendingDepositsUpdateCorrectlyMultipleWithdrawal(
        address _depositor1,
        address _depositor2,
        uint96 _deposit1,
        uint96 _deposit2
    ) public notAdmin(_depositor1) notAdmin(_depositor2) {
        vm.assume(_deposit1 > 0);
        vm.assume(_deposit2 > 0);
        vm.assume(_depositor1 != _depositor2);

        mockToken.transfer(_depositor1, _deposit1);
        mockToken.transfer(_depositor2, _deposit2);

        vm.prank(_depositor1);
        mockToken.approve(address(roll), _deposit1);

        vm.prank(_depositor2);
        mockToken.approve(address(roll), _deposit2);

        vm.prank(_depositor1);
        roll.deposit(_deposit1);

        roll.activateNextEpoch();

        vm.prank(_depositor2);
        roll.deposit(_deposit2);

        vm.prank(_depositor1);
        roll.quit();

        uint256 contractPending = roll.epochPendingBalance();
        uint256 user1Pending = roll.getPendingBalanceForUser(_depositor1);
        uint256 user2Pending = roll.getPendingBalanceForUser(_depositor2);
        assert(contractPending == user1Pending + user2Pending);
    }

    function testQuit(uint120 _amount, address _depositor, uint256 _withdrawAmount) public notAdmin(_depositor) {
        // deposit is split into halves, so we need both to be > 0
        // or the contract will revert
        vm.assume(_amount / 2 > 0);
        vm.assume(_withdrawAmount > 0);
        vm.assume(_amount >= _withdrawAmount);
        vm.assume(_amount < type(uint128).max);
        vm.assume(_depositor != address(0) && _depositor != address(this));

        uint256 firstDeposit = _amount / 2;
        uint256 secondDeposit = _amount - firstDeposit;

        mockToken.transfer(_depositor, _amount);

        uint8 currentEpochId = roll.currentEpochId();
        uint8 nextEpochId = currentEpochId + 1;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(firstDeposit);
        }
        vm.stopPrank();

        assertEq(roll.getActiveBalanceForUser(_depositor), 0);
        assertEq(roll.getPendingBalanceForUser(_depositor), firstDeposit);
        assertEq(roll.getTotalBalanceForUser(_depositor), firstDeposit);

        roll.activateNextEpoch();

        vm.startPrank(_depositor);
        {
            roll.deposit(secondDeposit);
            roll.quit();
        }
        vm.stopPrank();

        assertEq(mockToken.balanceOf(_depositor), _amount);
        assertEq(mockToken.balanceOf(address(roll)), 0);
        // user should be inactive now
        assertEq(roll.getActivations(_depositor).isActive(currentEpochId), false);
        assertEq(roll.getActivations(_depositor).isActive(nextEpochId), false);

        assertEq(roll.epochPendingBalance(), 0);
    }

    function testDepositPermit(uint120 _amount, uint256 _deadline, uint128 _depositorPk) public {
        vm.assume(_depositorPk > 0);
        vm.assume(_deadline > 0);
        vm.assume(_amount > 0);

        address depositor = vm.addr(_depositorPk);
        vm.assume(address(this) != depositor && address(roll) != depositor);

        bytes32 permitMessage = EIP712HashBuilder.generateTypeHashPermit(
            depositor, address(roll), _amount, _deadline, IERC20Permit(address(mockToken))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_depositorPk, permitMessage);

        mockToken.transfer(depositor, _amount);

        vm.prank(depositor);
        roll.depositWithSignature(_amount, _deadline, v, r, s);
        assertEq(roll.getTotalBalanceForUser(depositor), _amount);
    }

    function testEmergencyWithdraw(address _notTheOwner, uint120 _amount) public {
        vm.assume(!roll.hasRole(roll.DEFAULT_ADMIN_ROLE(), _notTheOwner));
        vm.assume(_notTheOwner != address(0) && _notTheOwner != address(this));
        vm.assume(_amount > 0);

        // check we can't use the emergency withdraw
        vm.startPrank(_notTheOwner);
        {
            vm.expectRevert(bytes(accessControlRevertString(_notTheOwner, roll.DEFAULT_ADMIN_ROLE())));
            roll.emergencyWithdraw();
        }
        vm.stopPrank();

        // now check the actual emergency
        mockToken.transfer(_notTheOwner, _amount);

        uint256 balanceBefore = mockToken.balanceOf(address(this));

        vm.startPrank(_notTheOwner);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(_amount);
        }
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdraw(address(this), _amount);
        roll.emergencyWithdraw();

        uint256 balanceNow = mockToken.balanceOf(address(this));
        assertEq(balanceNow - balanceBefore, _amount);
    }

    // test the ownable and pausable functions
    function testOperatorRestrictedFunctions(address _user) public {
        vm.assume(!roll.hasRole(roll.OPERATOR_ROLE(), _user) && !roll.hasRole(roll.DEFAULT_ADMIN_ROLE(), _user));

        bytes memory revertMessage = bytes(accessControlRevertString(_user, roll.OPERATOR_ROLE()));

        vm.startPrank(_user);
        {
            vm.expectRevert(revertMessage);
            roll.activateNextEpoch();

            vm.expectRevert(revertMessage);
            roll.unpause();

            vm.expectRevert(revertMessage);
            roll.pause();
        }
        vm.stopPrank();

        roll.grantRole(roll.OPERATOR_ROLE(), _user);

        vm.prank(_user);
        roll.pause();

        assertEq(roll.paused(), true);
    }

    function testPublicFunctionsPaused(uint120 _amount, address _caller) public notAdmin(_caller) {
        roll.pause();

        vm.startPrank(_caller);
        {
            vm.expectRevert(Errors.PAUSABLE);
            roll.deposit(_amount);

            vm.expectRevert(Errors.PAUSABLE);
            roll.quit();

            vm.expectRevert(Errors.PAUSABLE);
            roll.withdraw(_amount);

            vm.expectRevert(Errors.PAUSABLE);
            roll.withdraw(_amount);
        }
        vm.stopPrank();

        roll.unpause();

        vm.expectRevert(ZeroAmount.selector);
        roll.withdraw(0);
    }

    // test epoch balance correctly rolls forwards and epoch Id lines up
    /// @dev FAIL
    function testActivateNewEpoch(uint128 _currentBalance, uint128 _pendingBalance, uint8 _id, uint256 _warp) public {
        // we're setting the epoch to the _id variable, which can be any number in the range 0 - 255
        // setting it will initialize the next epoch
        // and then we will set another epoch in this test
        // to prevent overflow, this therefore means id can be up to 253
        // note: this is a known limitation of the roll staker - it can only support 254 before
        // the epoch id will overflow
        vm.assume(_id < type(uint8).max - 2);
        vm.warp(_warp);

        _currentBalance = 1;
        _pendingBalance = 2;

        if (_id != 0) roll.setEpoch(_id);

        roll.setEpochBalance(_id, _currentBalance);
        roll.setEpochDelta(_pendingBalance);
        assertEq(roll.getProjectedNextEpochBalance(), _currentBalance + _pendingBalance);

        vm.expectEmit(true, false, false, true);
        emit NewEpoch(_id + 1, block.timestamp);
        roll.activateNextEpoch();

        // _id was set (_id)
        // +we added a next epoch id for the artificial _id (_id + 1)
        // +we activated a new epoch (_id + 2)
        uint8 expectedLength = _id + 2;

        assertEq(roll.currentEpochId(), _id + 1);
        assertEq(roll.getEpochBalances().length, expectedLength);
        assertEq(roll.getCurrentEpochBalance(), _currentBalance + _pendingBalance);
        assertEq(roll.getProjectedNextEpochBalance(), _currentBalance + _pendingBalance);
        assertEq(roll.epochBalances(_id), _currentBalance);
    }

    // ===== GETTERS =====

    // test that getters do not revert if passed an epoch id out of range
    function testGettersDoNotRevert(uint8 _epochId, address _user) public view {
        roll.userIsActiveForEpoch(_user, _epochId);
        roll.getEpochBalanceWithProjection(_epochId);
    }

    function testLastEpochUserWasActive(
        address _user,
        uint8 _activateFrom,
        uint8 _deactivateFrom,
        uint8 _currentEpochId
    ) public notAdmin(_user) {
        // imagine [000000000001111111000001110010100111000]
        // let's activate from X, then deactivate from X + t, then be in t + k
        // we expect last active = X + t

        vm.assume(_activateFrom < _deactivateFrom);
        vm.assume(_deactivateFrom <= _currentEpochId);

        bf = Bitfields.initialize(_activateFrom);
        bf.deactivateFrom(_deactivateFrom);

        roll.setEpoch(_currentEpochId);
        roll.setUserStake(_user, bf, 0, 0);

        uint8 lastActive = roll.lastEpochUserWasActive(_user);

        assertEq(lastActive, _deactivateFrom - 1);
    }

    function testUserStaysActive(
        address _user,
        uint8 _activateFrom,
        uint8 _deactivateFrom,
        uint8 _reactivateFrom
    ) public notAdmin(_user) {
        vm.assume(_activateFrom < _deactivateFrom);
        vm.assume(_deactivateFrom < _reactivateFrom);

        bf = Bitfields.initialize(_activateFrom);
        bf.deactivateFrom(_deactivateFrom);
        bf.activateFrom(_reactivateFrom);

        roll.setUserStake(_user, bf, 0, 0);

        // work forward from reactivateFrom and check the user is active
        for (uint8 i = _reactivateFrom; i <= type(uint8).max - 2; i++) {
            roll.setEpoch(i);

            uint8 lastActive = roll.lastEpochUserWasActive(_user);
            assertEq(lastActive, i);
            assertEq(roll.userIsActiveForEpoch(_user, i), true);
        }
    }

    // test reverts

    function testZeroAmountReverts() public {
        vm.expectRevert(ZeroAmount.selector);
        roll.withdraw(0);

        vm.expectRevert(ZeroAmount.selector);
        roll.deposit(0);

        vm.expectRevert(abi.encodeWithSelector(InvalidWithdrawalAmount.selector, address(this), 1));
        roll.withdraw(1);

        vm.expectRevert(ZeroAmount.selector);
        roll.quit();
    }

    function testCannotWithdrawMoreThanDeposited(uint120 _amount, address _depositor, uint256 _withdrawAmount)
        public
        notAdmin(_depositor)
    {
        vm.assume(_amount > 0);
        vm.assume(_withdrawAmount > _amount);
        vm.assume(_depositor != address(0));

        mockToken.transfer(_depositor, _amount);

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(_amount);
        }
        vm.stopPrank();

        roll.activateNextEpoch();

        vm.prank(_depositor);
        vm.expectRevert(abi.encodeWithSelector(InvalidWithdrawalAmount.selector, _depositor, _withdrawAmount));
        roll.withdraw(_withdrawAmount);
    }

    function testCanWithdrawAcrossMultipleEpochs(uint120 _amount, address _depositor) public notAdmin(_depositor) {
        // deposit is split into halves, so we need both to be > 0
        // or the contract will revert
        vm.assume((_amount / 2) > 0);
        vm.assume(_depositor != address(0));

        mockToken.transfer(_depositor, _amount);

        uint256 firstDeposit = (_amount / 2);
        uint256 secondDeposit = _amount - firstDeposit;

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(firstDeposit);
        }
        vm.stopPrank();

        roll.activateNextEpoch();

        vm.prank(_depositor);
        roll.deposit(secondDeposit);

        roll.activateNextEpoch();

        vm.prank(_depositor);
        roll.withdraw(firstDeposit);

        assertEq(mockToken.balanceOf(_depositor), firstDeposit);
        assertEq(mockToken.balanceOf(address(roll)), secondDeposit);
    }

    function testGettersComputeCorrectlyAfterWithdraw(uint120 _amount, address _depositor)
        public
        notAdmin(_depositor)
    {
        vm.assume((_amount / 2) > 0);
        vm.assume(_depositor != address(0));

        mockToken.transfer(_depositor, _amount);

        vm.startPrank(_depositor);
        {
            mockToken.approve(address(roll), _amount);
            roll.deposit(_amount);
        }
        vm.stopPrank();

        roll.activateNextEpoch();
        roll.activateNextEpoch();

        vm.prank(_depositor);
        roll.withdraw(_amount / 2);

        assertEq(roll.getActiveBalanceForUser(_depositor), _amount - (_amount / 2));
        assertEq(roll.getTotalBalanceForUser(_depositor), _amount - (_amount / 2));
    }
}
