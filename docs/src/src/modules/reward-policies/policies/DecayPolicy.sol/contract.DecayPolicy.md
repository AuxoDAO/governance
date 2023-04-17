# DecayPolicy
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/reward-policies/policies/DecayPolicy.sol)

**Inherits:**
[IPolicy](/src/interfaces/IPolicy.sol/interface.IPolicy.md)

===============================
===== Audit: NOT IN SCOPE =====
===============================


## State Variables
### locker

```solidity
ITokenLocker public immutable locker;
```


### AVG_SECONDS_MONTH

```solidity
uint256 public immutable AVG_SECONDS_MONTH;
```


### exclusive

```solidity
bool public exclusive = false;
```


### VERSION
API version.


```solidity
string public constant VERSION = "0.1";
```


## Functions
### constructor


```solidity
constructor(address _locker);
```

### isExclusive


```solidity
function isExclusive() external view returns (bool);
```

### getDecayMultiplier


```solidity
function getDecayMultiplier(uint32 lockedAt, uint32 lockDuration) public view returns (uint256);
```

### compute


```solidity
function compute(uint256 amount, uint32 lockedAt, uint32 duration, uint256 balance) public view returns (uint256);
```

