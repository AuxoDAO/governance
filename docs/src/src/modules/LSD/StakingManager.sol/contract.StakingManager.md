# StakingManager
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/LSD/StakingManager.sol)

**Author:**
alexintosh

Tokens are staked in perpetuity, no coming back

*Make sure you understand how the Timelock works*


## State Variables
### operators

```solidity
mapping(address => bool) public operators;
```


### MONTHS

```solidity
uint8 internal constant MONTHS = 36;
```


### AUXO

```solidity
address public AUXO;
```


### veAUXO

```solidity
address public veAUXO;
```


### governor

```solidity
address public governor;
```


### tokenLocker

```solidity
ITokenLocker public tokenLocker;
```


## Functions
### onlyOperator


```solidity
modifier onlyOperator();
```

### onlyGovernance


```solidity
modifier onlyGovernance();
```

### constructor

Governor need to be added as operator post deployment


```solidity
constructor(address _auxo, address _veAuxo, address _tokenLocker, address _governor);
```

### approveAuxo

===========================
===== ADMIN FUNCTIONS =====
===========================


```solidity
function approveAuxo(uint256 amount) external onlyGovernance;
```

### delegateTo

veAUXO holders elect the representative


```solidity
function delegateTo(address representative) external onlyGovernance;
```

### addOperator


```solidity
function addOperator(address _operator) external onlyGovernance;
```

### rmOperator


```solidity
function rmOperator(address _operator) external onlyGovernance;
```

### stake

============================
===== PUBLIC FUNCTIONS =====
============================


```solidity
function stake() external;
```

### increase


```solidity
function increase() external;
```

### boostToMax


```solidity
function boostToMax() external;
```

### isOperator

=================
===== VIEWS =====
=================


```solidity
function isOperator(address _operator) external view returns (bool);
```

## Events
### OperatorAdded

```solidity
event OperatorAdded(address operator);
```

### OperatorRemoved

```solidity
event OperatorRemoved(address operator);
```

### RepresentativeChanged

```solidity
event RepresentativeChanged(address delegatee);
```

### AuxoApproval

```solidity
event AuxoApproval(address target, uint256 amount);
```

