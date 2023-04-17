# Terminatable
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/governance/EarlyTermination.sol)

**Inherits:**
Ownable, [ITerminatableEvents](/src/modules/governance/EarlyTermination.sol/contract.ITerminatableEvents.md)

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
function setPenalty(uint256 _penaltyPercentage) external onlyOwner;
```

### setPenaltyBeneficiary

Sets benificiary for the penalty


```solidity
function setPenaltyBeneficiary(address _beneficiary) external onlyOwner;
```

### terminateEarly

contract must override this to determine the Termination logic


```solidity
function terminateEarly() external virtual;
```

