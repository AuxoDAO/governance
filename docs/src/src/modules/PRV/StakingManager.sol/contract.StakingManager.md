# StakingManager
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/StakingManager.sol)

**Inherits:**
AccessControl, [IStakingManagerEvents](/src/modules/PRV/StakingManager.sol/interface.IStakingManagerEvents.md)

**Author:**
alexintosh

Tokens are staked in perpetuity, no coming back

*The StakingManager deposits AUXO and holds ARV on behalf of PRV holders.
Rewards accrued by the StakingManager are distributed to PRV holders.
These rewards are calculated separately.
Anyone can increase the StakingManager's deposit quantity, or boost it's position to the maximum duration
Note: anyone can send AUXO to the staking manager, not necessarily just via. PRV, therefore the staking
manager's locked balance does not necessarily reflect the amount of PRV locked.*


## State Variables
### GOVERNOR_ROLE

```solidity
bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
```


### AUXO
*these variables have no setters so cannot be changed
they are not marked as immutable due to constraints with upgradeability*


```solidity
address public AUXO;
```


### ARV

```solidity
address public ARV;
```


### tokenLocker
the locker holds AUXO and mints new ARV to the staking manager


```solidity
ITokenLocker public tokenLocker;
```


### MAXIMUM_DEPOSIT_MONTHS
====== PRIVATE VARIABLES ======


```solidity
uint8 internal constant MAXIMUM_DEPOSIT_MONTHS = 36;
```


### __gap
*this provides reserved storage slots for upgrades with inherited contracts*


```solidity
uint256[50] private __gap;
```


## Functions
### constructor

====== INITIALIZER ======


```solidity
constructor();
```

### initialize

Initializes the contract with the necessary addresses.


```solidity
function initialize(address _auxo, address _arv, address _tokenLocker, address _governor) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auxo`|`address`|Address of the AUXO ERC20 token that is deposited into the locker|
|`_arv`|`address`|Address of the governance token that is held by the staking manager.|
|`_tokenLocker`|`address`|Address of the token locker contract that the staking manager interacts with|
|`_governor`|`address`|will be given the GOVERNOR_ROLE for this contract|


### transferGovernance

===========================
===== ADMIN FUNCTIONS =====
===========================

governor relinquishes their role and transfers it to another address


```solidity
function transferGovernance(address _governor) external onlyRole(GOVERNOR_ROLE);
```

### approveAuxo

============================
===== PUBLIC FUNCTIONS =====
============================


```solidity
function approveAuxo() external;
```

### stake

creates the initial deposit for the staking manager.

*this function can only be called once and will revert otherwise.
we would expect to call it as part of deployment. Use increase() otherwise.*


```solidity
function stake() external;
```

### increase

deposits any AUXO in this contract that is not currently staked, into active vault.


```solidity
function increase() external;
```

### boostToMax

boosts the staked balance of the stakingManager to the full length

*this prevents other users ejecting the staking manager.*


```solidity
function boostToMax() external;
```

