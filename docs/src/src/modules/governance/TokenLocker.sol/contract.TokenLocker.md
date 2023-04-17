# TokenLocker
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/TokenLocker.sol)

**Inherits:**
[IncentiveCurve](/src/modules/governance/IncentiveCurve.sol/abstract.IncentiveCurve.md), [ITokenLockerEvents](/src/modules/governance/TokenLocker.sol/interface.ITokenLockerEvents.md), AccessControlEnumerable, [Migrateable](/src/modules/governance/Migrator.sol/abstract.Migrateable.md), [Terminatable](/src/modules/governance/EarlyTermination.sol/abstract.Terminatable.md)


## State Variables
### depositToken
==================================
======== Public Variables ========
==================================

token locked in the contract in exchange for reward tokens


```solidity
IERC20 public depositToken;
```


### veToken
the token that will be returned to the user in exchange for depositToken


```solidity
IERC20MintableBurnable public veToken;
```


### minLockDuration
minimum timestamp for tokens to be locked (i.e. block.timestamp + 6 months)


```solidity
uint32 public minLockDuration;
```


### maxLockDuration
maximum timetamp for tokens to be locked (i.e. block.timestamp + 36 months)


```solidity
uint32 public maxLockDuration;
```


### minLockAmount
minimum quantity of deposit tokens that must be locked in the contract


```solidity
uint192 public minLockAmount;
```


### ejectBuffer
additional time period after lock has expired after which anyone can remove timelocked tokens on behalf of another user


```solidity
uint32 public ejectBuffer;
```


### emergencyUnlockTriggered
callable by the admin to allow early release of locked tokens


```solidity
bool public emergencyUnlockTriggered;
```


### PRV
address of the Liquid Staking Derivative


```solidity
address public PRV;
```


### lockOf
lock details by address


```solidity
mapping(address => Lock) public lockOf;
```


### whitelisted
whitelisted addresses can deposit on behalf of other accounts and be sent reward tokens if not EOAs


```solidity
mapping(address => bool) public whitelisted;
```


### COMPOUNDER_ROLE
Compounder role can increment amounts for many accounts at once


```solidity
bytes32 public constant COMPOUNDER_ROLE = keccak256("COMPOUNDER_ROLE");
```


### __gap
======== Gap ========

*reserved storage slots for upgrades + inheritance*


```solidity
uint256[50] private __gap;
```


## Functions
### lockNotExpired

==================================
========     Modifiers    ========
==================================


```solidity
modifier lockNotExpired(Lock memory lock);
```

### lockExists


```solidity
modifier lockExists(address user);
```

### noPreviousLock


```solidity
modifier noPreviousLock(address user);
```

### lockIsExpiredOrEmergency


```solidity
modifier lockIsExpiredOrEmergency(Lock memory lock);
```

### emergencyOff


```solidity
modifier emergencyOff();
```

### onlyEOAorWL


```solidity
modifier onlyEOAorWL(address _receiver);
```

### migrationIsOn


```solidity
modifier migrationIsOn();
```

### onlyMigrator


```solidity
modifier onlyMigrator();
```

### constructor

======== Initializer ========

*prevent initializer from being called on implementation contract*


```solidity
constructor();
```

### initialize

*deposit and veTokens are not checked for return values - make sure they return a boolean*


```solidity
function initialize(
    IERC20 _depositToken,
    IERC20MintableBurnable _veToken,
    uint32 _minLockDuration,
    uint32 _maxLockDuration,
    uint192 _minLockAmount
) public initializer;
```

### setMinLockAmount

===============================
======== Admin Setters ========
===============================

updates the minimum lock amount that can be locked


```solidity
function setMinLockAmount(uint192 minLockAmount_) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### setWhitelisted

allows a contract address to receieve tokens OR allows depositing on behalf of another user


```solidity
function setWhitelisted(address _user, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|address of the account to whitelist|
|`_isWhitelisted`|`bool`||


### triggerEmergencyUnlock

if triggered, existing timelocks can be exited before the lockDuration has passed


```solidity
function triggerEmergencyUnlock() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### setEjectBuffer

sets the time allowed after a lock expires before anyone can exit a lock on behalf of a user


```solidity
function setEjectBuffer(uint32 _buffer) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### setPRV

Sets address the Early termination will use

*not checked for return values - ensure the token returns a boolean*


```solidity
function setPRV(address _prv) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### withdraw

====================================
======== External Functions ========
====================================

allows user to exit if their timelock has expired, transferring deposit tokens back to them and burning rewardTokens


```solidity
function withdraw() external lockExists(_msgSender()) lockIsExpiredOrEmergency(lockOf[_msgSender()]);
```

### eject

Any user can remove another from staking by calling the eject function, after the eject buffer has passed.

*Other stakers are incentivised to do so to because it gives them a bigger share of the voting and reward weight.*


```solidity
function eject(address[] calldata _lockAccounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lockAccounts`|`address[]`|array of addresses corresponding to the lockId we want to eject|


### depositByMonthsWithSignature

depositing requires prior approval of this contract to spend the user's depositToken
This method encodes the approval signature into the deposit call, allowing an offchain approval.

*params v,r,s are the ECDSA signature slices from signing the EIP-712 Permit message with the user's pk*


```solidity
function depositByMonthsWithSignature(
    uint192 _amount,
    uint256 _months,
    address _receiver,
    uint256 _deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint192`||
|`_months`|`uint256`||
|`_receiver`|`address`||
|`_deadline`|`uint256`|the latest timestamp the signature is valid|
|`v`|`uint8`||
|`r`|`bytes32`||
|`s`|`bytes32`||


### depositByMonths

locks depositTokens into the contract on behalf of a receiver

*unless whitelisted, the receiver MUST be the caller and an EOA*


```solidity
function depositByMonths(uint192 _amount, uint256 _months, address _receiver)
    public
    emergencyOff
    noPreviousLock(_receiver)
    onlyEOAorWL(_receiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint192`|the number of tokens to deposit|
|`_months`|`uint256`|the number of whole months to deposit for|
|`_receiver`|`address`|address where reward tokens will be sent|


### increaseAmountWithSignature

depositing requires prior approval of this contract to spend the user's depositToken
This method encodes the approval signature into the deposit call, allowing an offchain approval.

*params v,r,s are the ECDSA signature slices from signing the EIP-712 Permit message with the user's pk*


```solidity
function increaseAmountWithSignature(uint192 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint192`||
|`_deadline`|`uint256`|the latest timestamp the signature is valid|
|`v`|`uint8`||
|`r`|`bytes32`||
|`s`|`bytes32`||


### increaseAmount

adds new tokens to an existing lock and restarts the lock. Duration is unchanged.


```solidity
function increaseAmount(uint192 _amountNewTokens)
    public
    emergencyOff
    lockExists(_msgSender())
    lockNotExpired(lockOf[_msgSender()]);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amountNewTokens`|`uint192`|the number of new deposit tokens to add to the user's lock|


### increaseByMonths

sets a new number of months to lock deposits for, up to the max lock duration.


```solidity
function increaseByMonths(uint256 _months)
    external
    emergencyOff
    lockExists(_msgSender())
    lockNotExpired(lockOf[_msgSender()]);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_months`|`uint256`|months to increase lock by|


### increaseAmountsForMany

adds new tokens to an array of existing locks from a spender address. Duration is unchanged.

*receiver needs to have an existing lock*


```solidity
function increaseAmountsForMany(address[] calldata receivers, uint192[] calldata _amountNewTokens)
    external
    emergencyOff
    onlyRole(COMPOUNDER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receivers`|`address[]`|array or address to receive new tokens|
|`_amountNewTokens`|`uint192[]`|array of amounts to add to the receiver's lock with the same index|


### boostToMax

takes the user's existing lock and replaces it with a new lock for the maximum duration, starting now.

*In the event that the new lock duration longer than the old, additional reward tokens are minted*


```solidity
function boostToMax() external emergencyOff lockExists(_msgSender());
```

### terminateEarly

exits user's lock before expiration and mints PRV tokens in exchange, a termination fee may be applied.

*the PRV contract must be set to enable early termination. Underlying assets are transferred to this address.*


```solidity
function terminateEarly()
    external
    override
    emergencyOff
    lockExists(_msgSender())
    lockNotExpired(lockOf[_msgSender()]);
```

### migrate

user can to transfer funds to a migrator contract once migration is enabled

*the migrator contract must handle the reinstantiation of locks*


```solidity
function migrate(address _staker)
    external
    override
    emergencyOff
    migrationIsOn
    onlyMigrator
    lockExists(_staker)
    lockNotExpired(lockOf[_staker]);
```

### _deposit

====================================
======== Internal Functions ========
====================================

*actions the deposit for a numerical duration*


```solidity
function _deposit(address _receiver, uint192 _amount, uint32 _duration) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_receiver`|`address`||
|`_amount`|`uint192`||
|`_duration`|`uint32`|timestamp in seconds to lock for|


### _increaseAmount

*deposit additional tokens for the sender without modifying the unlock time
the lock is restarted to avoid governance hijacking attacks.*


```solidity
function _increaseAmount(uint192 _amountNewTokens) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amountNewTokens`|`uint192`|how many new tokens to deposit|


### _increaseUnlockDuration

*checks the passed duration is valid and mints new tokens in compensation.*


```solidity
function _increaseUnlockDuration(uint32 _duration) internal;
```

### hasLock

=========================
======== Getters ========
=========================

checks if the passed account has an existing timelock

*depositByMonths should only be called if this returns false, else use increaseLock*


```solidity
function hasLock(address _account) public view returns (bool);
```

### getLockMultiplier

fetches the reward token multiplier for a timelock duration


```solidity
function getLockMultiplier(uint32 _duration) public view returns (uint256 multiplier);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_duration`|`uint32`|in seconds of the timelock, will be converted to the nearest whole month|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`multiplier`|`uint256`|the %age (0 - 100%) of veToken per depositToken earned for a given duration|


### isLockExpired


```solidity
function isLockExpired(Lock memory lock) public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|if current timestamp has passed the lock expiry date|


### isLockExpired

overload to allow user to pass depositor address to check lock expiration


```solidity
function isLockExpired(address _depositor) public view returns (bool);
```

### getLock

*accessing via the mapping returns a tuple. Struct is a bit easier to work with in some scenarios.*


```solidity
function getLock(address _depositor) public view returns (Lock memory lock);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lock`|`Lock`|the lock of a depositor.|


### canEject

checks if it's possible to exit a lock on behalf of another user

*there is an additional `ejectBuffer` that must have passed beyond the lockDuration before ejection is possible*


```solidity
function canEject(address _account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|to check locks for|


### previewDepositByMonths

allows a user to preview the amount of veTokens they will receive for a new deposit

*will not work if the receiver already has a lock*


```solidity
function previewDepositByMonths(uint192 _amount, uint256 _months, address _receiver) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint192`|of deposit tokens|
|`_months`|`uint256`|of lock duration|
|`_receiver`|`address`|the address to be credited with the depoist and receive reward tokens|


### getAdmin

fetches the first DEFAULT_ADMIN_ROLE member who has control over admininstrative functions.

*it's possible to have multiple admin roles, this just returns the first as a convenience.*


```solidity
function getAdmin() external view returns (address);
```

## Structs
### Lock

```solidity
struct Lock {
    uint192 amount;
    uint32 lockedAt;
    uint32 lockDuration;
}
```

