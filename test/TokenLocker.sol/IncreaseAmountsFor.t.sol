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

contract TestlockerIncreaseAmountFor is TestlockerSetup {
    using IsEOA for address;

    /// @dev use to set test arrays
    uint8 private constant ARRAY_LENGTH = 5;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    function testFuzz_CannotHaveDifferentLenghtParam(address[] calldata _receivers, uint192[] calldata _qtyNew)
        public
    {
        vm.assume(_receivers.length != _qtyNew.length);
        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));

        vm.expectRevert("IA: Array legth mismatch");
        locker.increaseAmountsForMany(_receivers, _qtyNew);
    }

    function testFuzz_CanIncreaseAmountForMany(
        uint120 _startPk,
        uint128[ARRAY_LENGTH] calldata _arr,
        uint8[ARRAY_LENGTH] memory _months
    ) public {
        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));

        vm.assume(_startPk > 0);
        address[] memory _depositors = nonZeroUniqueAddressArray(uint128(_startPk), ARRAY_LENGTH);

        uint8[] memory months = new uint8[](ARRAY_LENGTH);
        for (uint256 m; m < _months.length; m++) {
            uint8 month = _months[m];
            if (month > locker.maxLockDuration()) months[m] = uint8(locker.maxLockDuration() / AVG_SECONDS_MONTH);
            else if (month < locker.minLockDuration()) months[m] = uint8(locker.minLockDuration() / AVG_SECONDS_MONTH);
            else months[m] = month;
        }

        // this is annoying but fixed size arrays are diff types
        uint128[] memory arr = new uint128[](ARRAY_LENGTH);
        for (uint256 a; a < _arr.length; a++) {
            arr[a] = _arr[a];
        }

        uint128[] memory qtysOld = aboveMinUint128Array(arr, ARRAY_LENGTH, locker.minLockAmount());
        uint128[] memory qtysNew = aboveMinUint128Array(arr, ARRAY_LENGTH, locker.minLockAmount());
        uint128[] memory rewardsOld = aboveMinUint128Array(arr, ARRAY_LENGTH, locker.minLockAmount());

        for (uint256 i = 0; i < _depositors.length; i++) {
            address depositor = _depositors[i];
            vm.assume(depositor.isEOA());

            uint192 qty = qtysOld[i];
            deposit.transfer(depositor, qty);

            vm.startPrank(depositor, depositor);
            {
                deposit.approve(address(locker), qty);
                locker.depositByMonths(qty, months[i], depositor);
            }
            rewardsOld[i] = uint128(reward.balanceOf(depositor));
            vm.stopPrank();
        }

        TokenLocker.Lock[] memory lockPres = new TokenLocker.Lock[](ARRAY_LENGTH);
        uint192[] memory rewardBalancePre = new uint192[](ARRAY_LENGTH);
        for (uint256 d; d < _depositors.length; d++) {
            rewardBalancePre[d] = uint192(reward.balanceOf(_depositors[d]));
            lockPres[d] = _fetchLock(_depositors[d]);
        }

        deposit.approve(address(locker), type(uint256).max);
        locker.increaseAmountsForMany(_depositors, castArray128To192(qtysNew));

        for (uint256 d; d < _depositors.length; d++) {
            address depositor = _depositors[d];
            uint256 rewardBalanceOld = rewardsOld[d];
            uint256 qtyNew = uint256(qtysNew[d]);
            uint256 qtyOld = uint256(qtysOld[d]);
            uint256 month = months[d];

            // get post deposit balances
            uint256 rewardBalanceNew = reward.balanceOf(depositor);
            uint256 expectedNewTokens = uint256(qtyNew) * locker.maxRatioArray(month) / 1e18;
            uint256 expectedBalanceNew = expectedNewTokens + rewardBalanceOld;

            // check rewards
            assertEq(expectedBalanceNew, rewardBalanceNew);

            TokenLocker.Lock memory lockPre = lockPres[d];
            TokenLocker.Lock memory lockPost = _fetchLock(depositor);

            assertEq(lockPre.amount, qtyOld);
            assertEq(lockPost.amount, uint(qtyOld) + uint(qtyNew));
            // rest of lock stays the same
            assertEq(lockPre.lockDuration, lockPost.lockDuration);
            assertEq(lockPre.lockedAt, lockPost.lockedAt);
        }
    }

    function testFuzz_AllReceiversNeedALock(uint120 _startPk, uint184[ARRAY_LENGTH] calldata _arr) public {
        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));

        vm.assume(_startPk > 0);
        address[] memory _depositors = nonZeroUniqueAddressArray(uint128(_startPk), ARRAY_LENGTH);
        address[] memory _receivers = nonZeroUniqueAddressArray(uint128(_startPk) + ARRAY_LENGTH, ARRAY_LENGTH);

        // this is annoying but fixed size arrays are diff types
        uint192[] memory arr = new uint192[](ARRAY_LENGTH);
        for (uint256 a; a < _arr.length; a++) {
            arr[a] = _arr[a];
        }
        uint192[] memory qtyNews = nonZeroUint192Array(arr, ARRAY_LENGTH);

        for (uint256 i = 0; i < _depositors.length; i++) {
            _makeDeposit(_depositors[i], uint128(locker.minLockAmount()), 36);
        }

        deposit.approve(address(locker), type(uint256).max);

        vm.expectRevert("IA: Lock not found");
        locker.increaseAmountsForMany(_receivers, qtyNews);
    }

    function testFuzz_CannotHaveAZeroAmount(uint120 _startPk, uint128[ARRAY_LENGTH] memory _arr) public {
        vm.assume(_startPk > 0);
        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));
        address[] memory _depositors = nonZeroUniqueAddressArray(uint128(_startPk), ARRAY_LENGTH);

        bool zeroFound = false;
        for (uint256 i = 0; i < _depositors.length; i++) {
            _makeDeposit(_depositors[i], uint128(locker.minLockAmount()), 36);

            // force a zero as the last element of the array if none has been generated automatically
            if (_arr[i] == 0) zeroFound = true;
            bool endOfArray = i == _depositors.length - 1;
            if (endOfArray && !zeroFound) _arr[i] = 0;
        }

        uint192[] memory arr = new uint192[](ARRAY_LENGTH);
        for (uint256 a; a < _arr.length; a++) {
            arr[a] = _arr[a];
        }

        deposit.approve(address(locker), type(uint256).max);
        vm.expectRevert("IA: amount == 0");
        locker.increaseAmountsForMany(_depositors, arr);
    }

    function testFuzz_CannotIncreaseAmountForExpiredLock(address _depositor, uint128 _deposit, uint8 _month) public {
        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));
        address[] memory depositors = new address[](1);
        depositors[0] = _depositor;

        uint192[] memory qtyNews = new uint192[](1);
        qtyNews[0] = _deposit;

        _makeDeposit(_depositor, _deposit, _month);

        // Expiring lock
        vm.warp(block.timestamp + (_month * AVG_SECONDS_MONTH) + 1);

        deposit.approve(address(locker), type(uint256).max);
        vm.expectRevert("IA: Lock Expired");
        locker.increaseAmountsForMany(depositors, qtyNews);
    }

    function testFuzz_DepositorCanUseIncreaseAmount(address _depositor, uint128 _deposit, uint8 _months) public {
        _makeDeposit(_depositor, _deposit, _months);

        deposit.transfer(_depositor, _deposit);
        vm.startPrank(_depositor);
        deposit.approve(address(locker), type(uint256).max);
        locker.increaseAmount(_deposit);
        vm.stopPrank();

        assertEq(locker.getLock(_depositor).amount, uint192(_deposit) * 2);
    }

    function testFuzz_DepositorCannotUseIncreaseAmountForMany(address _depositor, uint128 _deposit, uint8 _months)
        public
    {
        address[] memory depositors = new address[](1);
        depositors[0] = _depositor;

        uint192[] memory qtyNews = new uint192[](1);
        qtyNews[0] = _deposit;
        _makeDeposit(_depositor, _deposit, _months);

        deposit.transfer(_depositor, _deposit);
        vm.startPrank(_depositor);
        deposit.approve(address(locker), type(uint256).max);

        bytes memory revertMessage = bytes(accessControlRevertString(_depositor, locker.COMPOUNDER_ROLE()));
        vm.expectRevert(revertMessage);
        locker.increaseAmountsForMany(depositors, qtyNews);
        vm.stopPrank();
    }

    function testFuzz_CannotIncreaseAmountForManyBelowMin(address _receiver, uint128 _qtyOld, uint8 _months) public {
        // 36 months will never revert because of division by 1
        vm.assume(_months < locker.maxLockDuration() / AVG_SECONDS_MONTH);

        locker.grantRole(locker.COMPOUNDER_ROLE(), address(this));

        _makeDeposit(_receiver, _qtyOld, _months);

        // mathematically, this is the condition that must be violated to cause a zero reward increase
        uint192 willRevertQty = uint192(1e18 / (locker.maxRatioArray(_months)));
        // meaning that this should never revert
        uint192 wontRevertQty = willRevertQty + 1;
        assertLe(willRevertQty, MINIMUM_INCREASE_QTY);

        address[] memory depositors = new address[](1);
        depositors[0] = _receiver;

        uint192[] memory qtyNews = new uint192[](1);
        qtyNews[0] = willRevertQty;

        deposit.approve(address(locker), wontRevertQty);

        vm.expectRevert("IA: 0 veShares");
        locker.increaseAmountsForMany(depositors, qtyNews);

        // finally, check that we don't revert by increasing by just 1 wei
        qtyNews[0] = wontRevertQty;
        locker.increaseAmountsForMany(depositors, qtyNews);

        vm.stopPrank();
    }
}
