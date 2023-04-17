// SPDX-License-Identifier: UNLICENSED
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

contract TestlockerTerminateEarly is TestlockerSetup {
    using IsEOA for address;

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    function testFuzz_TerminateEarly(
        address _depositor,
        uint128 _qty,
        uint8 _months,
        address _beneficiary,
        uint256 _penaltyFee
    ) public notAdmin(_depositor) notAdmin(_beneficiary) {
        vm.assume(_months <= 36 && _months >= 6);
        vm.assume(_penaltyFee < 10 ** 18);
        vm.assume(_depositor.isEOA());
        vm.assume(_qty >= locker.minLockAmount());
        vm.assume(_depositor != _beneficiary);
        vm.assume(_beneficiary != address(0));

        locker.setPenalty(_penaltyFee);
        locker.setPenaltyBeneficiary(_beneficiary);

        deposit.transfer(_depositor, _qty);

        // overload to set tx.origin
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(locker), _qty);
        locker.depositByMonths(_qty, _months, _depositor);
        uint256 penaltyAmount = _qty * locker.earlyExitFee() / (10 ** 18);

        locker.terminateEarly();
        assertEq(reward.balanceOf(_depositor), 0);
        assertEq(deposit.balanceOf(_beneficiary), penaltyAmount);
    }
}
