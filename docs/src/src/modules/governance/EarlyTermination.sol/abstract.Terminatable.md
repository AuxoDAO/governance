# Terminatable
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/EarlyTermination.sol)

**Inherits:**
AccessControlEnumerable, [ITerminatableEvents](/src/modules/governance/EarlyTermination.sol/interface.ITerminatableEvents.md)

*override the `terminateEarly` function in the inheriting contract*


## State Variables
### HUNDRED_PERCENT

```solidity
uint256 public constant HUNDRED_PERCENT = 10 ** 18;
```


### penaltyBeneficiary
Penalty Wallet Receiver


```solidity
address public penaltyBeneficiary;
```


### earlyExitFee
Percentage penalty to be paid when early exiting the lock
10 ** 17; // 10%


```solidity
uint256 public earlyExitFee;
```


## Functions
### setPenalty

Sets the percentage penalty to be paind when early exiting the lock
10 ** 17; // 10%


```solidity
function setPenalty(uint256 _penaltyPercentage) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### setPenaltyBeneficiary

Sets benificiary for the penalty


```solidity
function setPenaltyBeneficiary(address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### terminateEarly

contract must override this to determine the Termination logic


```solidity
function terminateEarly() external virtual;
```

