// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.16;

import {OwnableUpgradeable as Ownable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title  DelegationRegistry
 * @notice simple, permissioned delegation registry that can be added to another contract to add delegation.
 * @dev    this contract inherits the OZ Upgradeable Ownable contract.
 *         `__Ownable_init()` must therefore be called in the intializer of the inheriting contract.
 */
abstract contract DelegationRegistry is Ownable {
    event DelegateAdded(address indexed user, address indexed delegate);
    event DelegateRemoved(address indexed user, address indexed delegate);
    event DelegateWhitelistChanged(address indexed delegate, bool whitelisted);

    /// @notice user address => delegate address
    mapping(address => address) public delegations;

    /// @notice list of addresses that are eligible for delegation
    mapping(address => bool) public whitelistedDelegates;

    /// @dev is the sender whitelisted to collect rewards on behalf of the passed user
    modifier onlyWhitelistedFor(address _userFor) {
        require(isRewardsDelegate(_userFor, _msgSender()), "!whitelisted for user");
        _;
    }

    /// @dev is the sender a whitelisted address for delegation
    modifier onlyWhitelisted() {
        require(whitelistedDelegates[_msgSender()], "!whitelisted");
        _;
    }

    /// @notice the owner must allow addresses to be delegates before they can be added
    function setWhitelisted(address _delegate, bool _whitelist) external onlyOwner {
        whitelistedDelegates[_delegate] = _whitelist;
        emit DelegateWhitelistChanged(_delegate, _whitelist);
    }

    /// @notice set a new delegate or override an existing delegate
    function setRewardsDelegate(address _delegate) external {
        require(whitelistedDelegates[_delegate], "!whitelisted");
        delegations[_msgSender()] = _delegate;
        emit DelegateAdded(_msgSender(), _delegate);
    }

    /// @notice sender removes the current delegate
    function removeRewardsDelegate() external {
        address delegate = delegations[_msgSender()];
        delegations[_msgSender()] = address(0);
        emit DelegateRemoved(_msgSender(), delegate);
    }

    /// @notice has the user any active delegations
    function hasDelegatedRewards(address _user) external view returns (bool) {
        return delegations[_user] != address(0);
    }

    /// @notice is the passed delegate whitelisted to collect rewards on behalf of the user
    function isRewardsDelegate(address _user, address _delegate) public view returns (bool) {
        return delegations[_user] == _delegate;
    }
}
