# xAUXO
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/LSD/xAUXO.sol)

**Inherits:**
ERC20, ERC20Permit

**Author:**
alexintosh

Tokens are stakingManager in perpetuity, no coming back

*Make sure you understand how veAUXO work and the stakingManager contract does.*


## State Variables
### MAX_ENTRY_FEE

```solidity
uint256 public constant MAX_ENTRY_FEE = 10 ** 17;
```


### entryFee

```solidity
uint256 public entryFee;
```


### feeBeneficiary

```solidity
address public feeBeneficiary;
```


### stakingManager

```solidity
address public stakingManager;
```


### governor

```solidity
address public governor;
```


### AUXO

```solidity
address public immutable AUXO;
```


## Functions
### onlyGovernance


```solidity
modifier onlyGovernance();
```

### constructor


```solidity
constructor(address _auxo, address _stakingManager, address _governor, uint256 _entryFee, address _feeBeneficiary)
    ERC20("xAUXO", "xAUXO")
    ERC20Permit("xAUXO");
```

### setup


```solidity
function setup() external;
```

### depositFor

we assume you sent AUXO to stakingManager first

*We mint the first xAUXO here to msg.sender
We do that in order to avoid the complexity of adding
initializer function calling .stake() for the very first time
or having to check every single time that we indeed have a lock*


```solidity
function depositFor(address account, uint256 amount) external;
```

### _calcFee

====================
===== Internal =====
====================


```solidity
function _calcFee(uint256 amount) internal view returns (uint256, uint256);
```

### _chargeFee


```solidity
function _chargeFee(uint256 amount) internal returns (uint256);
```

### _depositAndStake

*takes a deposit, in auxo from the sender and transfers to the staking manager
The staking manager will then deposit the Auxo into the veAUXO locker and mint xAUXO.*


```solidity
function _depositAndStake(address account, uint256 amount) internal;
```

### previewDeposit

=================
===== VIEWS =====
=================

amount after fees is minted 1:1


```solidity
function previewDeposit(uint256 amount) external view returns (uint256);
```

### setEntryFee

===========================
===== ADMIN FUNCTIONS =====
===========================


```solidity
function setEntryFee(uint256 _fee) public onlyGovernance;
```

### setFeeBeneficiary


```solidity
function setFeeBeneficiary(address _beneficiary) public onlyGovernance;
```

### setFeePolicy


```solidity
function setFeePolicy(uint256 _fee, address _beneficiary) external onlyGovernance;
```

## Events
### EntryFeeSet

```solidity
event EntryFeeSet(uint256 fee);
```

### FeeBeneficiarySet

```solidity
event FeeBeneficiarySet(address feeBeneficiary);
```

