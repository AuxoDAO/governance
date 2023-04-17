// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";

contract TestGetAmountAndLongestDuration is TestUpgradoorIntegrationSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    /// @dev test the view function `getAmountAndLongestDuration` matches expectations
    function testFuzz_GetAmountAndLongestDuration(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        (uint256 total, uint256 longestLockMonths,,) = _initLocks(_depositor, _months, _amounts);
        (uint32 longestDuration, uint256 totalAmount,) = UP.getAmountAndLongestDuration(_depositor);

        assertEq(total, totalAmount);
        assertEq(longestLockMonths, longestDuration / AVG_SECONDS_MONTH);
    }
}
