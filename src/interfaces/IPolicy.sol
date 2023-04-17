pragma solidity 0.8.16;

interface IPolicy {
    function compute(uint256 amount, uint32 lockedAt, uint32 duration, uint256 startingBalance)
        external
        returns (uint256 balance);
    function isExclusive() external returns (bool);
}
