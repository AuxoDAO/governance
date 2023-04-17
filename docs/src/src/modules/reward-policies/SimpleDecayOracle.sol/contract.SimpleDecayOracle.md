# SimpleDecayOracle
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/reward-policies/SimpleDecayOracle.sol)

**Inherits:**
[DecayPolicy](/src/modules/reward-policies/policies/DecayPolicy.sol/contract.DecayPolicy.md)

===============================
===== Audit: NOT IN SCOPE =====
===============================

Simple oracle calculating the mothly decay for ARV locks

*The queue is processed in descending order, meaning the last index will be withdrawn from first.*


## Functions
### constructor


```solidity
constructor(address _locker) DecayPolicy(_locker);
```

### balanceOf


```solidity
function balanceOf(address _staker) external view returns (uint256);
```

