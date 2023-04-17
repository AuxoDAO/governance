// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@oz/access/Ownable.sol";

interface ITerminatableEvents {
    event EarlyExit(address lockOwner, uint256 amount);
    event EarlyExitFeeChanged(uint256 afterFee);
    event PenaltyBeneficiaryChanged(address _newBeneficiary);
}

/**
 * @dev override the `terminateEarly` function in the inheriting contract
 */
abstract contract Terminatable is Ownable, ITerminatableEvents {
    uint256 public constant HUNDRED_PERCENT = 10 ** 18;

    /// @notice Penalty Wallet Receiver
    address public penaltyBeneficiary;

    /// @notice Percentage penalty to be paid when early exiting the lock
    /// 10 ** 17; // 10%
    uint256 public earlyExitFee;

    /**
     * @notice Sets the percentage penalty to be paind when early exiting the lock
     * 10 ** 17; // 10%
     */
    function setPenalty(uint256 _penaltyPercentage) external onlyOwner {
        require(_penaltyPercentage < HUNDRED_PERCENT, "setPenalty: Fee to big");
        earlyExitFee = _penaltyPercentage;
        emit EarlyExitFeeChanged(_penaltyPercentage);
    }

    /**
     * @notice Sets benificiary for the penalty
     */
    function setPenaltyBeneficiary(address _beneficiary) external onlyOwner {
        penaltyBeneficiary = _beneficiary;
        emit PenaltyBeneficiaryChanged(_beneficiary);
    }

    /**
     * @notice contract must override this to determine the Termination logic
     */
    function terminateEarly() external virtual {
        emit EarlyExit(msg.sender, 0);
    }
}
