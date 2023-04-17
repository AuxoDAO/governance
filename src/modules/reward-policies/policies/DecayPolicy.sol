// SPDX-License-Identifier: MIT

/// ===============================
/// ===== Audit: NOT IN SCOPE =====
/// ===============================

pragma solidity 0.8.16;

import "@interfaces/IPolicy.sol";
import "@interfaces/ITokenLocker.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract DecayPolicy is IPolicy {
    ITokenLocker public immutable locker;
    uint256 public immutable AVG_SECONDS_MONTH;
    bool public exclusive = false;

    /// @notice API version.
    string public constant VERSION = "0.1";

    constructor(address _locker) {
        locker = ITokenLocker(_locker);
        AVG_SECONDS_MONTH = locker.getSecondsMonths();
    }

    function isExclusive() external view returns (bool) {
        return exclusive;
    }

    function getDecayMultiplier(uint32 lockedAt, uint32 lockDuration) public view returns (uint256) {
        // If Lock is already expired return 0
        if (uint256(lockedAt + lockDuration) <= block.timestamp) return 0;

        uint256 diff = block.timestamp - lockedAt;
        uint256 monthDelta = diff / AVG_SECONDS_MONTH;
        uint256 selectedMonth = uint256(lockDuration) / AVG_SECONDS_MONTH;

        if (monthDelta > selectedMonth) return 0;

        if (monthDelta > 0) {
            //If remaining month is < 6 the multiplier stays set at 6 months
            uint32 remainingmonths = uint32(selectedMonth - monthDelta) < 6 ? 6 : uint32(selectedMonth - monthDelta);
            uint32 duration = uint32(remainingmonths * AVG_SECONDS_MONTH);
            uint256 decayedMonthMultiplier = locker.getLockMultiplier(duration);
            return decayedMonthMultiplier;
        }
        return locker.getLockMultiplier(lockDuration);
    }

    function compute(uint256 amount, uint32 lockedAt, uint32 duration, uint256 balance) public view returns (uint256) {
        uint256 dm = getDecayMultiplier(lockedAt, duration);
        return (amount * dm) / 1e18;
    }
}
