# PolicyManager
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/reward-policies/PolicyManager.sol)

===============================
===== Audit: NOT IN SCOPE =====
===============================


## State Variables
### policyQueue
An ordered array of strategies representing the withdrawal queue.


```solidity
IPolicy[] public policyQueue;
```


### locker

```solidity
ITokenLocker public immutable locker;
```


### veAUXO

```solidity
IERC20 public immutable veAUXO;
```


### VERSION

```solidity
string public constant VERSION = "0.1";
```


## Functions
### constructor


```solidity
constructor(address _locker, address _veAUXO);
```

### computeFor

*the queue matters a lot*


```solidity
function computeFor(address user) external returns (uint256);
```

### getQueue


```solidity
function getQueue() external view returns (IPolicy[] memory);
```

### setPolicyQueue

Set the policy queue.

*There are no sanity checks on the `newQueue` argument so they should be done off-chain.
Currently there are no checks for duplicated Queue items.*


```solidity
function setPolicyQueue(IPolicy[] calldata newQueue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newQueue`|`IPolicy[]`|The new  queue.|


## Events
### PolicyQueueSet
Emitted when the PolicyQueue is updated.


```solidity
event PolicyQueueSet(IPolicy[] newQueue);
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

