// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";

contract TestPreviewAggregationIfLocksHaveExpired is TestUpgradoorIntegrationSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    // here we will test with some expired locks
    function testFuzz_CorrectPreviewAggregationIfLocksHaveExpired(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint64 _fastForward,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary
    ) public {
        // initialize
        {
            _initLocks(_depositor, _months, _amounts);
            _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);
            _warpTo(_fastForward);
            // at this point, we are at some stage in the future.
        }

        // We need to check if any of our locks are still valid
        (uint256 amountValid, SharesTimeLock.Lock memory longestValidLock, bool foundValidLock,) =
            _getLongestValidLock(_depositor);

        // test that no valid locks found if we jumped too far forward
        {
            if (longestValidLock.lockDuration + longestValidLock.lockedAt < block.timestamp) {
                assertEq(foundValidLock, false);
            }
        }

        uint256 previewBoosted = UP.previewAggregateAndBoost(_depositor);
        uint256 previewVeAuxoNonBoosted = UP.previewAggregateARV(_depositor);

        // Test to see that amount valid is equal to boosted when normalized.
        // and that amounts are zero if there are no non-expired locks
        {
            if (!foundValidLock) {
                assertEq(previewBoosted, 0);
                assertEq(previewVeAuxoNonBoosted, 0);
                assertEq(amountValid, 0);
            }
            assertEq(amountValid / 100, previewBoosted);
        }

        // test that preview is < boosted except in two special cases
        {
            bool longestLockIsMaxPossible = longestValidLock.lockDuration / AVG_SECONDS_MONTH == 36;
            bool lessThan1monthHasPassed = block.timestamp - longestValidLock.lockedAt < AVG_SECONDS_MONTH;

            if (!foundValidLock || (longestLockIsMaxPossible && lessThan1monthHasPassed)) {
                assertEq(previewVeAuxoNonBoosted, previewBoosted);
            } else {
                assertLt(previewVeAuxoNonBoosted, previewBoosted);
            }
        }

        // test that preview meets expectations
        {
            uint256 adjustedMonths = UP.getMonthsNewLock(longestValidLock.lockedAt, longestValidLock.lockDuration);
            uint256 expectedQty = ((amountValid / 100) * tokenLocker.maxRatioArray(adjustedMonths)) / (10 ** 18);

            console2.log("\n  Adjusted Months %d", adjustedMonths);
            console2.log("Current Timestamp %d", block.timestamp);
            console2.log("AmountValid %d, expectedQty %d", amountValid, expectedQty);

            console2.log(
                "\nNon-boosted: 0.%d veAUXO, Boosted: %d veAUXO, Manual: 0.%d veAUXO\n",
                previewVeAuxoNonBoosted / 1e16,
                previewBoosted / 1e18,
                expectedQty / 1e16
            );
            assertEq(previewVeAuxoNonBoosted, expectedQty);
        }

        // test xAUXO previews
        {
            uint256 previewXAuxo = UP.previewAggregateToPRV(_depositor);
            uint256 expectedxAuxo = amountValid/100;
            if (!foundValidLock) {
                assertEq(previewXAuxo, 0);
            } else {
                assertEq(previewXAuxo, expectedxAuxo);
            }
        }
    }
}
