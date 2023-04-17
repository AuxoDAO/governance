# PRV
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/PRV.sol)

**Inherits:**
ERC20, ERC20Permit, ReentrancyGuard, [IPRVEvents](/src/modules/PRV/PRV.sol/interface.IPRVEvents.md)

**Author:**
alexintosh, jordaniza

PRV has the following key properties:
1) Implements the full ERC20 standard, including optional fields name, symbol and decimals
2) Is upgradeable
3) PRV only be minted in exchange for deposits in AUXO tokens
4) PRV can be burned to withdraw underlying AUXO back in return, a withdrawal manager contract can be defined
to add additional withdrawal logic.
5) Has admin functions managed by a governor address
6) Implements the ERC20Permit standard for offchain approvals.


## State Variables
### MAX_FEE
====== PUBLIC VARIABLES ======

max entry fee from AUXO -> PRV is 10%


```solidity
uint256 public constant MAX_FEE = 10 ** 17;
```


### AUXO
the deposit token required to mint PRV


```solidity
address public AUXO;
```


### fee
express as a % of the deposit token and sent to the fee beneficiary.


```solidity
uint256 public fee;
```


### feeBeneficiary
entry fees will be sent to this address for each token minted.


```solidity
address public feeBeneficiary;
```


### governor
governor retains admin control over the contract.


```solidity
address public governor;
```


### withdrawalManager
external contract to determine if a user is eligible to withdraw.


```solidity
address public withdrawalManager;
```


### __gap
====== GAP ======

*gap for future storage variables in upgrades with inheritance*


```solidity
uint256[10] private __gap;
```


## Functions
### onlyGovernance

====== MODIFIERS ======


```solidity
modifier onlyGovernance();
```

### constructor

====== Initializer ======


```solidity
constructor();
```

### initialize


```solidity
function initialize(address _auxo, uint256 _fee, address _feeBeneficiary, address _governor, address _withdrawalManager)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auxo`|`address`|address of the AUXO token contract. Cannot be changed after deployment.|
|`_fee`|`uint256`|for withdrawing AUXO back to PRV, can be set to zero to disable fees.|
|`_feeBeneficiary`|`address`|address to send fees to - if set to zero, fees will not be charged.|
|`_governor`|`address`|address of the governor that has admin control over the contract. Only the governor can change the governor.|
|`_withdrawalManager`|`address`|contract to apply additional withdrawal steps. If set to zero, no restrictions will be applied to withdrawals.|


### depositFor

Allows a user to deposit and stake a specific token (AUXO) to a specified account.


```solidity
function depositFor(address _account, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Ethereum address of the account to deposit and stake the token to.|
|`_amount`|`uint256`|uint256 representing the amount of token to deposit and stake.|


### depositForWithSignature

Allows a user to deposit using ERC20 permit method.

*See ERC20-Permit for details on the ECDSA params v,r,s*


```solidity
function depositForWithSignature(address _account, uint256 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`||
|`_amount`|`uint256`||
|`_deadline`|`uint256`|uint256 representing the deadline for the signature to be valid.|
|`v`|`uint8`||
|`r`|`bytes32`||
|`s`|`bytes32`||


### withdraw

redeems PRV for AUXO. A withdrawal fee may be applied.

*if the withdrawal manager is set, it will be called to validate the withdrawal request.*


```solidity
function withdraw(uint256 _amount, bytes memory _data) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|of PRV to redeem for AUXO.|
|`_data`|`bytes`|to pass to withdrawal manager for withdrawal validation|


### _calcFee

====== INTERNAL ======

*calculates the fee to be charged - if the beneficiary is not set, no fee is charged.*


```solidity
function _calcFee(uint256 _amount) internal view returns (uint256, uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(the amount of auxo after the fee has been deducted, the fee amount deducted)|
|`<none>`|`uint256`||


### _chargeFee

*calculates the entry fee in auxo and sends to the fee beneficiary.*


```solidity
function _chargeFee(uint256 _amount) internal returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the amount of auxo after the fee has been deducted.|


### _deposit

*takes a deposit, in auxo from the sender and mints PRV*


```solidity
function _deposit(address _account, uint256 _amount) internal;
```

### previewWithdraw

====== VIEWS ======


```solidity
function previewWithdraw(uint256 _amount) external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the amount of AUXO that will be redeemed for the given amount of PRV, minus any exit fees|


### setFee

====== ADMIN FUNCTIONS ======

This function sets the exit fee for the contract. Only the governor can call this function.


```solidity
function setFee(uint256 _fee) public onlyGovernance;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fee`|`uint256`|uint256 value of the exit fee, bounded at 10%.|


### setFeeBeneficiary

sets the beneficiary address for the contract's entry fee. Only the governor can call this function.


```solidity
function setFeeBeneficiary(address _beneficiary) public onlyGovernance;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_beneficiary`|`address`|address of the beneficiary for the entry fee.|


### setFeePolicy

utility function to set fee and beneficiary in one call.

*we do not need to check for governance as this is checked in the setters.*


```solidity
function setFeePolicy(uint256 _fee, address _beneficiary) external;
```

### setGovernor

allows the existing governor to transfer ownership to a new address.


```solidity
function setGovernor(address _governor) external onlyGovernance;
```

### setWithdrawalManager

allows the existing governor to set a withdrawal manager
this is a contract that will verify the validity of a withdrawal and amount

*set the manager to address(0) to disable any additional withdrawal logic*


```solidity
function setWithdrawalManager(address _withdrawalManager) external onlyGovernance;
```

