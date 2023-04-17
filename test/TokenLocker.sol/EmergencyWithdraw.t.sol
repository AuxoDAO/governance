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

contract TestlockerEmergencyWithdraw is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    function testEmergencyReverts() public {
        locker.triggerEmergencyUnlock();

        vm.expectRevert("emergency unlocked");
        locker.depositByMonths(1e27, 36, vm.addr(1));

        vm.expectRevert("emergency unlocked");
        locker.increaseAmount(0);

        vm.expectRevert("emergency unlocked");
        locker.increaseByMonths(0);

        vm.expectRevert("emergency unlocked");
        locker.boostToMax();

        vm.expectRevert("EU: already triggered");
        locker.triggerEmergencyUnlock();
    }

    function testEmergencyWithdraw(address _depositor, uint128 _qty, uint8 _months) public {
        _makeDeposit(_depositor, _qty, _months);
        vm.expectRevert("Lock !expired");
        vm.prank(_depositor);
        locker.withdraw();

        uint256 lockerBalancePre = deposit.balanceOf(address(locker));

        locker.triggerEmergencyUnlock();
        vm.prank(_depositor);
        locker.withdraw();

        assertEq(deposit.balanceOf(address(_depositor)), _qty);
        assertEq(deposit.balanceOf(address(locker)), lockerBalancePre - _qty);
        assertEq(reward.balanceOf(address(_depositor)), 0);
    }
}
