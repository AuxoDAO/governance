# DelegationRegistry
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/rewards/DelegationRegistry.sol)

**Inherits:**
Ownable

simple, permissioned delegation registry that can be added to another contract to add delegation.

*this contract inherits the OZ Upgradeable Ownable contract.
`__Ownable_init()` must therefore be called in the intializer of the inheriting contract.*


## State Variables
### delegations
user address => delegate address


```solidity
mapping(address => address) public delegations;
```


### whitelistedDelegates
list of addresses that are eligible for delegation


```solidity
mapping(address => bool) public whitelistedDelegates;
```


## Functions
### onlyWhitelisted


```solidity
modifier onlyWhitelisted(address _userFor);
```

### setWhitelisted

the owner must allow addresses to be delegates before they can be added


```solidity
function setWhitelisted(address _delegate, bool _whitelist) external onlyOwner;
```

### setRewardsDelegate

set a new delegate or override an existing delegate


```solidity
function setRewardsDelegate(address _delegate) external;
```

### removeRewardsDelegate

sender removes the current delegate


```solidity
function removeRewardsDelegate() external;
```

### hasDelegatedRewards

has the user any active delegations


```solidity
function hasDelegatedRewards(address _user) external view returns (bool);
```

### isRewardsDelegate

is the passed delegate whitelisted to collect rewards on behalf of the user


```solidity
function isRewardsDelegate(address _user, address _delegate) public view returns (bool);
```

## Events
### DelegateAdded

```solidity
event DelegateAdded(address indexed user, address indexed delegate);
```

### DelegateRemoved

```solidity
event DelegateRemoved(address indexed user, address indexed delegate);
```

### DelegateWhitelistChanged

```solidity
event DelegateWhitelistChanged(address indexed delegate, bool whitelisted);
```

## Errors
### NotWhitelistedForUser

```solidity
error NotWhitelistedForUser(address user, address delegate);
```

