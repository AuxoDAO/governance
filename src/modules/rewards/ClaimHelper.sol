// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IMerkleDistributorCore} from "./MerkleDistributor.sol";

interface IMerkleDistributor is IMerkleDistributorCore {
    function claimDelegated(IMerkleDistributorCore.Claim memory _claim) external;
    function claimMultiDelegated(IMerkleDistributorCore.Claim[] memory _claims) external;
}

///@dev Distributors needs to delegate to this contract in order to work.
contract ClaimHelper {
    IMerkleDistributor immutable public ActiveDistributor;
    IMerkleDistributor immutable public PassiveDistributor;
    IERC20 public constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(address _activeDistributorAddress, address _passiveDistributorAddress) {
        ActiveDistributor = IMerkleDistributor(_activeDistributorAddress);
        PassiveDistributor = IMerkleDistributor(_passiveDistributorAddress);
    }

    /// @dev Can only be called by the owner of those claims
    function claim(IMerkleDistributorCore.Claim memory _ActiveClaim, IMerkleDistributorCore.Claim memory _PassiveClaim) external returns(uint256) {
        require(_ActiveClaim.account == _PassiveClaim.account, "Not same account");
        require(_ActiveClaim.account == msg.sender, "Not claim owner");
        uint256 balanceBefore = weth.balanceOf(address(this));
        ActiveDistributor.claimDelegated(_ActiveClaim);
        PassiveDistributor.claimDelegated(_PassiveClaim);
        uint256 balanceAfter = weth.balanceOf(address(this));
        weth.transfer(_ActiveClaim.account, balanceAfter - balanceBefore);
    }

    /// @dev Can only be called by the owner of those claims
    function claimMulti(IMerkleDistributorCore.Claim[] memory _ActiveClaim, IMerkleDistributorCore.Claim[] memory _PassiveClaim) external returns(uint256) {
        for (uint256 i = 0; i < _ActiveClaim.length; i++) require(_ActiveClaim[i].account == msg.sender);
        for (uint256 i = 0; i < _PassiveClaim.length; i++) require(_PassiveClaim[i].account == msg.sender);

        uint256 balanceBefore = weth.balanceOf(address(this));
        ActiveDistributor.claimMultiDelegated(_ActiveClaim);
        PassiveDistributor.claimMultiDelegated(_PassiveClaim);
        uint256 balanceAfter = weth.balanceOf(address(this));
        weth.transfer(msg.sender, balanceAfter - balanceBefore);
    }
}
