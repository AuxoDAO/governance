# Bitfields
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/LSD/bitfield.sol)

a library for efficiently setting epoch ranges as bitfields.

*solidity uses 8 bits as its smallest 'native' type, and working with these in arrays
is expensive. This library relies on some assumptions about epochs:
1. Active users in epoch t are active in epochs t + k => k = 1...., K (unless they deactivate)
2. Deactivated users in epoch t remain deactivated until they reactivate
3. The user of this library has an awareness of the current epoch
4. Time moves strictly forward.
A bitfield is a 256 bit integer, indicating a user is active (1) or inactive (0) for epoch i.
Assuming a 1 month epoch, this allows us to store just over 21 years of activation history
in a single storage slot.
Initialize the array when activating the user for the first time, indicating what epoch they have
started from.
Activate or deactivate the user at specific epochs.
- Activating will set all subsequent epochs to active (1)
- Deactivating will set all subsequent epochs to inactive (0)
Check if a particular epoch is active or not using the `isActivated` function.
Finally, you can iterate back from the current epoch to check when was the last time the user
is activated.
Note: do not start from the last possible epoch (255) as 'activated' users will have all epochs by default
set to active (1). Instead, start from the current epoch.
TODO: experiment with a 'pure' version of the library for (possible) gas savings
(This one plays with storage so may be a bit more expensive)*


## State Variables
### MAX_BITMASK

```solidity
uint256 private constant MAX_BITMASK = type(uint256).max;
```


## Functions
### bitmask

creates an array of bits set to one up to the position len

*if trying to create a full word bitmask, use the maxBitmask constant*


```solidity
function bitmask(uint8 len) internal pure returns (uint256);
```

### initialize

creates new bitfield with all values starting at _epochFrom set to one


```solidity
function initialize(uint8 _epochFrom) public pure returns (Bitfield memory);
```

### deactivateFrom

takes an existing bifield, and zeroes out all bits starting at _epochFrom


```solidity
function deactivateFrom(Bitfield storage self, uint8 _epochFrom) public;
```

### activateFrom

takes an existing bitfield, and sets all values starting at _epochFrom to one


```solidity
function activateFrom(Bitfield storage self, uint8 _epochFrom) public;
```

### isActive

returns whether the passed epoch is active or not in the bitfield

*we do not require the bitfield to be persistent in storage to check it here*


```solidity
function isActive(Bitfield calldata self, uint8 _epoch) public pure returns (bool);
```

### isEmpty

checks if the private value variable is empty


```solidity
function isEmpty(Bitfield calldata self) public pure returns (bool);
```

### lastActive

starts from the passed epoch to find the first activated epoch

*if the user has never been activated, this will return epoch zero*

*do not start from an epoch in the future - activated users will be 'lastActivated' until epoch 255*

*we do not require the bitfield to be persistent in storage to check it here*


```solidity
function lastActive(Bitfield calldata self, uint8 _latestEpoch) public pure returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Bitfield`||
|`_latestEpoch`|`uint8`|an active user will have all bits flipped to one for the whole bitmask this parameter indicates where to start looking back from|


## Structs
### Bitfield
*The _value variable is designed not to be directly accessed*


```solidity
struct Bitfield {
    uint256 _value;
}
```

