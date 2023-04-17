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

contract TestlockerDeposits is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ =======

    // test can deposit
    function testFuzz_SuccessfulDeposit(address _depositor, uint128 _qty, uint8 _months, uint24 _secondsToTimeTravel)
        public
        notAdmin(_depositor)
    {
        vm.warp(_secondsToTimeTravel);
        _makeDeposit(_depositor, _qty, _months);

        uint256 multiplier = locker.maxRatioArray(_months);
        uint256 expectedRewardTokens = (_qty * multiplier) / 1e18;

        assertEq(reward.balanceOf(_depositor), expectedRewardTokens);

        (uint256 amount, uint32 lockedAt, uint32 lockDuration) = locker.lockOf(_depositor);
        assertEq(amount, _qty);
        assertEq(lockedAt, _secondsToTimeTravel);
        assertEq(lockDuration, _months * AVG_SECONDS_MONTH);
    }

    //TODO this test needs to make sure the depositor cannot have 2 locks
    function testFuzz_CannotDepositTwice(address _depositor, uint128 _qty, uint8 _months) public notAdmin(_depositor) {
        _makeDeposit(_depositor, _qty, _months);
        vm.prank(_depositor);
        vm.expectRevert("Lock exist");
        locker.depositByMonths(_qty, _months, _depositor);
    }

    // but not too short nor too long
    function testFuzz_DepositRevertsOutOfRangeMonths(
        address _depositor,
        uint128 _qty,
        uint8 _months,
        uint8 _min,
        uint8 _max
    ) public notAdmin(_depositor) {
        vm.assume(_max > _min);
        vm.assume(_months > _max || _months < _min);
        vm.assume(_depositor.isEOA());
        vm.assume(_qty >= locker.minLockAmount());

        // only set max and min in constructor so deploy a new instance
        TokenLocker newlocker = _deployLocker(
            deposit, IERC20MintableBurnable(address(reward)), AVG_SECONDS_MONTH * _min, AVG_SECONDS_MONTH * _max, 0
        );

        deposit.transfer(_depositor, _qty);

        // overload to set tx.origin
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(newlocker), _qty);
        vm.expectRevert("GLM: Duration incorrect");
        newlocker.depositByMonths(_qty, _months, _depositor);

        vm.stopPrank();
    }

    // but not too little
    function testFuzz_DepositRevertsBelowMin(address _depositor, uint192 _qty, uint8 _months, uint192 _min)
        public
        notAdmin(_depositor)
    {
        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_qty < _min);
        vm.assume(_depositor.isEOA());

        deposit.transfer(_depositor, _qty);
        locker.setMinLockAmount(_min);

        // overload to set tx.origin
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(locker), _qty);
        vm.expectRevert("Deposit: too low");
        locker.depositByMonths(_qty, _months, _depositor);

        vm.stopPrank();
    }

    // test cannot deposit if not EOA
    function testFuzz_CannotDepositToContractUnlessWhitelisted(address _depositor, uint128 _qty, uint8 _months)
        public
        notAdmin(_depositor)
    {
        // setup the depositor contract - do this before checking EOA
        DelegateDeposit depositor = new DelegateDeposit();

        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_depositor.isEOA());
        vm.assume(_qty >= locker.minLockAmount());

        deposit.transfer(address(depositor), _qty);

        // overload to set tx.origin and call from a legit depositor
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(locker), _qty);

        // should fail first time round
        vm.expectRevert("Not EOA or WL");
        depositor.proxyDeposit(locker, _qty, _months, address(depositor), deposit);

        vm.stopPrank();

        // whitelist the account
        locker.setWhitelisted(address(depositor), true);

        // try again
        vm.prank(_depositor, _depositor);
        depositor.proxyDeposit(locker, _qty, _months, address(depositor), deposit);

        uint256 multiplier = locker.maxRatioArray(_months);
        uint256 expectedRewardTokens = (_qty * multiplier) / 1e18;
        // note: tokens now in the contract
        assertEq(reward.balanceOf(address(depositor)), expectedRewardTokens);
    }

    function testFuzz_CannotDepositOnBehalfOfAnotherUnlessWhitelisted(
        address _depositor,
        uint128 _qty,
        uint8 _months,
        address _recipient
    ) public notAdmin(_depositor) {
        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_depositor.isEOA());
        vm.assume(_qty >= locker.minLockAmount());
        vm.assume(_depositor != _recipient);
        vm.assume(_recipient != address(0));

        // setup the depositor contract
        deposit.transfer(address(_depositor), _qty);

        // overload to set tx.origin and call from a legit depositor
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(locker), _qty);

        // should fail first time round
        vm.expectRevert("sender != receiver or WL");
        locker.depositByMonths(_qty, _months, _recipient);

        vm.stopPrank();

        // whitelist the account to make delegated deposits
        locker.setWhitelisted(_depositor, true);

        // try again
        vm.prank(_depositor, _depositor);
        locker.depositByMonths(_qty, _months, _recipient);

        uint256 multiplier = locker.maxRatioArray(_months);
        uint256 expectedRewardTokens = (_qty * multiplier) / 1e18;
        // note: tokens now with the recipient
        assertEq(reward.balanceOf(address(_recipient)), expectedRewardTokens);
    }

    function testFuzz_HasLock(address _depositor, uint128 _qty, uint8 _months) public notAdmin(_depositor) {
        assertEq(locker.hasLock(_depositor), false);

        _makeDeposit(_depositor, _qty, _months);
        if (_qty == 0) {
            assertEq(locker.hasLock(_depositor), false);
        } else {
            assertEq(locker.hasLock(_depositor), true);
        }
    }

    /// ===== SIGNATURES =====

    function testFuzz_DepositWithSignature(
        uint128 _depositorPk,
        uint128 _qty,
        uint8 _months,
        uint24 _secondsToTimeTravel,
        uint256 _deadline
    ) public {
        vm.warp(_secondsToTimeTravel);
        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_qty >= locker.minLockAmount());
        vm.assume(_depositorPk > 0);
        vm.assume(_deadline > _secondsToTimeTravel);

        address _depositor = vm.addr(_depositorPk);
        vm.assume(_depositor.isEOA());

        deposit.transfer(_depositor, _qty);

        bytes32 permitMessage =
            EIP712HashBuilder.generateTypeHashPermit(_depositor, address(locker), _qty, _deadline, deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_depositorPk, permitMessage);

        // overload to set tx.origin
        vm.prank(_depositor, _depositor);
        locker.depositByMonthsWithSignature(_qty, _months, _depositor, _deadline, v, r, s);

        uint256 multiplier = locker.maxRatioArray(_months);
        uint256 expectedRewardTokens = (_qty * multiplier) / 1e18;

        assertEq(reward.balanceOf(_depositor), expectedRewardTokens);

        (uint256 amount, uint32 lockedAt, uint32 lockDuration) = locker.lockOf(_depositor);
        assertEq(amount, _qty);
        assertEq(lockedAt, _secondsToTimeTravel);
        assertEq(lockDuration, _months * AVG_SECONDS_MONTH);
    }

    function testFuzz_DepositWithSignatureToExternalReceiver(
        uint128 _depositorPk,
        address _receiver,
        uint128 _qty,
        uint8 _months,
        uint24 _secondsToTimeTravel,
        uint256 _deadline
    ) public notAdmin(_receiver) {
        vm.warp(_secondsToTimeTravel);
        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_qty >= locker.minLockAmount());
        vm.assume(_depositorPk > 0);
        vm.assume(_deadline > _secondsToTimeTravel);
        vm.assume(_receiver != address(0));
        // ensure the receiver is not the depositor
        // once whitelisted, we can remove EOA restriction
        address _depositor = vm.addr(_depositorPk);
        vm.assume(_receiver != _depositor);
        locker.setWhitelisted(_depositor, true);
        deposit.transfer(_depositor, _qty);

        // add in separate scope to prevent stack too deep errors
        {
            bytes32 permitMessage =
                EIP712HashBuilder.generateTypeHashPermit(_depositor, address(locker), _qty, _deadline, deposit);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_depositorPk, permitMessage);

            // overload to set tx.origin
            vm.prank(_depositor, _depositor);
            locker.depositByMonthsWithSignature(_qty, _months, _receiver, _deadline, v, r, s);

            uint256 multiplier = locker.maxRatioArray(_months);
            uint256 expectedRewardTokens = (_qty * multiplier) / 1e18;

            assertEq(reward.balanceOf(_receiver), expectedRewardTokens);
        }

        (uint256 amount, uint32 lockedAt, uint32 lockDuration) = locker.lockOf(_receiver);
        assertEq(amount, _qty);
        assertEq(lockedAt, _secondsToTimeTravel);
        assertEq(lockDuration, _months * AVG_SECONDS_MONTH);
    }
}
