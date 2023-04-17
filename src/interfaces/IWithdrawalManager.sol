pragma solidity ^0.8.0;

interface IWithdrawalManager {
    function verify(uint256 _amount, address _account, bytes calldata _data) external returns (bool);
}
