// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import "@forge-std/Test.sol";

contract TestARVNoBoostValidLocks is TestUpgradoorIntegrationSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    function testFuzz_VeAuxoNoBoostValidLocks(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary
    ) public {
        _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);

        (uint256 total, uint256 longestLockMonths, uint32 longestLockedAt, uint32 longestDuration) =
            _initLocks(_depositor, _months, _amounts);

        uint256 previewBoosted = UP.previewAggregateAndBoost(_depositor);
        assertEq(previewBoosted, total / 100);

        uint256 previewVeAuxoNonBoosted = UP.previewAggregateARV(_depositor);

        // test nextLongestLock Is correct for aggregates, all valid
        {
            (, uint32 nextLongestLockedAt, uint32 nextLongestDuration,) = UP.getNextLongestLock(_depositor);

            assertEq(nextLongestDuration / AVG_SECONDS_MONTH, longestLockMonths);
            assertEq(nextLongestDuration, longestDuration);
            assertEq(nextLongestLockedAt, longestLockedAt);

            _logMonthsPassed(longestLockedAt);

            console2.log("longestLockedAt: %d, longestDuration: %d", longestLockedAt, longestDuration);
        }

        // test previewNonBoosted == expected
        {
            uint256 adjustedMonths = UP.getMonthsNewLock(longestLockedAt, longestDuration);
            uint256 expectedQty = ((total / 100) * tokenLocker.maxRatioArray(adjustedMonths)) / (10 ** 18);
            console2.log("\n  Adjusted Months %d", adjustedMonths);
            console2.log("Current Timestamp %d", block.timestamp);

            console2.log(
                "\nNon-boosted: 0.%d veAUXO, Boosted: %d veAUXO, Manual: 0.%d veAUXO\n",
                previewVeAuxoNonBoosted / 1e16,
                previewBoosted / 1e18,
                expectedQty / 1e16
            );
            assertEq(previewVeAuxoNonBoosted, expectedQty);
        }

        // test non boosted < boosted unless max lock less than 1m passed
        {
            // if and only if zero months have passed on the longest lock at max length, boosted will be equal to preview
            if (longestLockMonths == 36 && longestLockedAt == block.timestamp) {
                assertEq(previewVeAuxoNonBoosted, previewBoosted);
            } else {
                assertLt(previewVeAuxoNonBoosted, previewBoosted);
            }
        }

        /// test xauxo preview
        {
            uint256 previewXAuxo = UP.previewAggregateToPRV(_depositor);
            assertEq(previewXAuxo, total/100);
        }
    }
}
