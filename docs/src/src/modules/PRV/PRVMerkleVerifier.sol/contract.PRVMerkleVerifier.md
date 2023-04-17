# PRVMerkleVerifier
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/PRVMerkleVerifier.sol)

**Inherits:**
Ownable, Pausable, [IPRVMerkleVerifier](/src/modules/PRV/PRVMerkleVerifier.sol/interface.IPRVMerkleVerifier.md)

restricts PRV -> Auxo redemption based on limits set in a merkle tree

*snapshotting PRV holders and restricting redemptions ensures that PRV redemptions (which may be constrained by budget)
are more open to all PRV holders, and less susceptible to frontrunning attacks.*


## State Variables
### nextWindowIndex
Index of most next window to be created


```solidity
uint256 public nextWindowIndex;
```


### windows
windowIndex => Window


```solidity
mapping(uint256 => Window) public windows;
```


### amountWithdrawnFromWindow

```solidity
mapping(uint256 => mapping(address => uint256)) private amountWithdrawnFromWindow;
```


### PRV
the address of the PRV contract


```solidity
address public PRV;
```


### lockBlock
Block until when the distributor is locked


```solidity
uint256 public lockBlock;
```


### AUXO
*the address of the AUXO token - is fetched from the PRV contract*


```solidity
address private AUXO;
```


### __gap
*reserved storage slots for upgrades*


```solidity
uint256[10] private __gap;
```


## Functions
### onlyPRV

====== MODIFIERS ========

only the PRV contract can call this function


```solidity
modifier onlyPRV();
```

### windowOpen

claim must be for the current window, and the window must be open

*if the window has been deleted this will revert as block.number > (endBlock = 0)*


```solidity
modifier windowOpen(bytes calldata _data);
```

### inBudget

the passed amount must be less than the max amount for the window

*requires that the first window has been set or will revert
if the window has been deleted this will revert if amount > 0*


```solidity
modifier inBudget(uint256 _amount);
```

### minLengthClaimData

claim data that is too short may not revert with a meaningful
error message once decoded, this checks explicitly bytes data is min length

*this doesn't validate the content of the data, it just ensures it is long enough
that we can decode it without reverting - field validation happens later.
Additionally, data that is too long will not necessarily be possible to decode, so will just revert.*


```solidity
modifier minLengthClaimData(bytes memory _data);
```

### constructor

====== INITIALIZER ========


```solidity
constructor();
```

### initialize


```solidity
function initialize(address _prv) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_prv`|`address`|the address of the PRV contract - must implement IPRV as Auxo address will be fetched from it|


### pause

======== ADMIN FUNCTIONS ========

see openzeppelin docs for more info on pausable


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

### setPRV

whitelists the process withdrawal function to just the PRV contract

*Auxo address will be fetched from the PRV contract and updated*


```solidity
function setPRV(address _prv) external onlyOwner;
```

### setWindow

instantiates a new window with a given merkle root and max amount, bounded by start and end blocks.

*the previous window is deleted - this will disable claims until the new window begins.*

*there must be sufficient AUXO in the PRV contract to cover this amount or the tx will revert*


```solidity
function setWindow(uint256 _maxAmount, bytes32 _merkleRoot, uint32 _startBlock, uint32 _endBlock) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxAmount`|`uint256`|the maximum amount of PRV that can be redeemed in the window|
|`_merkleRoot`|`bytes32`|the merkle root of the claims in the window|
|`_startBlock`|`uint32`|the block number at which the window starts|
|`_endBlock`|`uint32`|the block number at which the window ends. Must be greater than _startBlock|


### deleteWindow

Delete window at the specified index if it exists.

*Callable only by owner.*


```solidity
function deleteWindow(uint256 _windowIndex) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_windowIndex`|`uint256`|to delete.|


### _deleteWindow

*internal method that avoids ownable modifier.
setWindow ensures that we can rely on an endBlock of zero to only be present if the window has no data*


```solidity
function _deleteWindow(uint256 _windowIndex) internal;
```

### verify

======== WITHDRAWAL ========

takes a request to redeem some amount of PRV and verifies that it is both valid and within the budget.

*we allow repeated claims so long as the total amount claimed is less than the amount in the merkle tree.*


```solidity
function verify(uint256 _amount, address _account, bytes calldata _data)
    external
    whenNotPaused
    onlyPRV
    minLengthClaimData(_data)
    windowOpen(_data)
    inBudget(_amount)
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|the amount of PRV to redeem, can be less than the claim amount if the user is only redeeming part of the claim|
|`_account`|`address`|the address of the user who is redeeming the PRV|
|`_data`|`bytes`|encoded claim data as bytes.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the claim is valid, false otherwise|


### verifyClaim

======== VIEW FUNCTIONS ========

Returns True if leaf described by {account, windowIndex, amount} is stored in Merkle root at given window index.


```solidity
function verifyClaim(Claim memory _claim) public view virtual returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_claim`|`Claim`|claim object describing rewards, accountIndex, account, window index, and merkle proof.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if leaf exists.|


### withdrawn


```solidity
function withdrawn(address _account, uint256 _windowIndex) public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the amount of PRV that has been withdrawn by the user for a given window|


### availableToWithdrawInClaim


```solidity
function availableToWithdrawInClaim(Claim memory _claim) public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the amount of PRV that the user can still withdraw for a given window|


### canWithdraw


```solidity
function canWithdraw(Claim memory _claim) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whether the user can still withdraw for a given window|


### budgetRemaining


```solidity
function budgetRemaining(uint256 _windowIndex) public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the amount of PRV that can still be withdrawn in the window|


### getWindow


```solidity
function getWindow(uint256 _windowIndex) external view returns (Window memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Window`|the window at a given index, encoded as a struct|


### windowIsOpen


```solidity
function windowIsOpen(uint256 _windowIndex) public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whether the passed window index is currently accepting withdrawals|


