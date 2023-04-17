// SPDX-License-Identifier: MIT

/// ===============================
/// ===== Audit: NOT IN SCOPE =====
/// ===============================

pragma solidity 0.8.16;

import "@interfaces/IPolicy.sol";
import "@interfaces/ITokenLocker.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract PolicyManager {
    struct Lock {
        uint192 amount;
        uint32 lockedAt;
        uint32 lockDuration;
    }

    /// @notice An ordered array of strategies representing the withdrawal queue.
    IPolicy[] public policyQueue;
    ITokenLocker public immutable locker;
    IERC20 public immutable veAUXO;

    string public constant VERSION = "0.1";

    // -----------------
    // ----- Events ----
    // -----------------

    /// @notice Emitted when the PolicyQueue is updated.
    /// @param newQueue The new IPolicy array.
    event PolicyQueueSet(IPolicy[] newQueue);

    constructor(address _locker, address _veAUXO) {
        locker = ITokenLocker(_locker);
        veAUXO = IERC20(_veAUXO);
    }

    /// @dev the queue matters a lot
    function computeFor(address user) external returns (uint256) {
        (uint256 amount, uint32 lockedAt, uint32 duration) = locker.lockOf(user);
        uint256 mem = veAUXO.balanceOf(user);

        for (uint256 i = 0; i < policyQueue.length; i++) {
            // Applies the policy and stores the resulting balance
            mem = policyQueue[i].compute(amount, lockedAt, duration, mem);

            // Exclusive policies cannot be combined with other policies, they should be on top of the queue.
            if (policyQueue[i].isExclusive()) break;
        }

        return mem;
    }

    function getQueue() external view returns (IPolicy[] memory) {
        return policyQueue;
    }

    // -----------------
    // -----  Admin ----
    // -----------------

    /// @notice Set the policy queue.
    /// @param newQueue The new  queue.
    /// @dev There are no sanity checks on the `newQueue` argument so they should be done off-chain.
    ///      Currently there are no checks for duplicated Queue items.
    function setPolicyQueue(IPolicy[] calldata newQueue) external {
        // Replace the withdrawal queue.
        policyQueue = newQueue;
        emit PolicyQueueSet(newQueue);
    }
}
