/// ===============================
/// ===== Audit: NOT IN SCOPE =====
/// ===============================

pragma solidity 0.8.16;

import "./policies/DecayPolicy.sol";

/// @notice Simple oracle calculating the mothly decay for ARV locks
/// @dev The queue is processed in descending order, meaning the last index will be withdrawn from first.
contract SimpleDecayOracle is DecayPolicy {
    constructor(address _locker) DecayPolicy(_locker) {}

    function balanceOf(address _staker) external view returns (uint256) {
        (uint256 amount, uint32 lockedAt, uint32 duration) = locker.lockOf(_staker);
        return compute(amount, lockedAt, duration, 0);
    }
}
