// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {TokenLocker} from "@governance/TokenLocker.sol";

contract TestMigrateToPRV is TestUpgradoorIntegrationSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    function testFuzz_ExitToXAuxo(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary
    ) public {
        _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);
        (uint256 total,,,) = _initLocks(_depositor, _months, _amounts);

        uint PRVExpected = total / 100;

        vm.prank(_depositor);
        UP.aggregateToPRV();

        (uint192 amount, uint32 lockedAt, uint32 lockDuration) = tokenLocker.lockOf(_depositor);

        assertEq(amount, 0);
        assertEq(lockedAt, 0);
        assertEq(lockDuration, 0);

        assertEq(veauxo.balanceOf(_depositor), 0);
        assertEq(lsd.balanceOf(_depositor), PRVExpected);
        assertEq(auxo.balanceOf(_feeBeneficiary), 0);

        assertEq(veDOUGH.balanceOf(_depositor), 0);
        assertEq(mockDOUGH.balanceOf(address(UP)), total);
    }

    function testFuzz_ExitToXAuxoWithExpiry(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint64 _fastForward,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary
    ) public notAdmin(_feeBeneficiary) {
        _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);

        (uint256 total,,,) = _initLocks(_depositor, _months, _amounts);
        _warpTo(_fastForward);

        (uint256 amountValid,, bool foundValidLock,) = _getLongestValidLock(_depositor);

        if (!foundValidLock) {
            vm.expectRevert("SharesTimeLock: Lock expired");
            vm.prank(_depositor);
            UP.aggregateToPRV();
        } else {
            vm.prank(_depositor);
            UP.aggregateToPRV();

            assertEq(tokenLocker.getLock(_depositor).amount, 0);
            assertEq(tokenLocker.getLock(_depositor).lockedAt, 0);

            uint256 expectedxAuxo = amountValid / 100;

            assertEq(veauxo.balanceOf(_depositor), 0);
            assertEq(lsd.balanceOf(_depositor), expectedxAuxo);
            assertEq(auxo.balanceOf(_feeBeneficiary), 0);

            if (total == amountValid) {
                assertEq(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            } else {
                assertGt(veDOUGH.balanceOf(_depositor), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), amountValid);
            }
        }
    }
}
