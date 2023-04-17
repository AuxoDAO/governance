# MerkleDistributor
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/rewards/MerkleDistributor.sol)

**Inherits:**
Ownable, Pausable, ReentrancyGuard, [DelegationRegistry](/src/modules/rewards/DelegationRegistry.sol/abstract.DelegationRegistry.md), [IMerkleDistributorCore](/src/modules/rewards/MerkleDistributor.sol/interface.IMerkleDistributorCore.md)

Allows an owner to distribute any reward ERC20 to claimants according to Merkle roots. The owner can specify
multiple Merkle roots distributions with customized reward currencies.

*The Merkle trees are not validated in any way, so the system assumes the contract owner behaves honestly.*


## State Variables
### merkleWindows
incrementing index for each window


```solidity
mapping(uint256 => Window) public merkleWindows;
```


### claimedBitMap
Track which accounts have claimed for each window index.

*windowIndex => accountIndex => bitMap. Allows 256 claims to be recorded per word stored.*


```solidity
mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;
```


### nextCreatedIndex
Index of next created Merkle root.


```solidity
uint256 public nextCreatedIndex;
```


### lockBlock
Block until when the distributor is locked


```solidity
uint256 public lockBlock;
```


## Functions
### notLocked

===== MODIFIERS ======


```solidity
modifier notLocked();
```

### constructor

====== INITIALIZER ======

*prevent initializer being called in implementation contract*


```solidity
constructor();
```

### initialize

Initializer for the contract


```solidity
function initialize() public initializer;
```

### pause

====== ADMIN FUNCTIONS ======

see openzepplin docs for more info on pausable


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

### setWindow

Set merkle root for the next available window index and seed allocations.

*we do not check tokens deposited cover all claims for the window, it is assumed this has been checked by the caller.
Deposits are not segregated by window, so users may start claiming reward tokens still pending for other users in previous windows.*


```solidity
function setWindow(uint256 _rewardAmount, address _rewardToken, bytes32 _merkleRoot, string memory _ipfsHash)
    external
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardAmount`|`uint256`|total rewards across all users|
|`_rewardToken`|`address`|the token that will reward users|
|`_merkleRoot`|`bytes32`|for merkle tree generated for this window|
|`_ipfsHash`|`string`|pointing to the merkle tree|


### setLock

Set block to lock the contract

*Callable only by owner.*


```solidity
function setLock(uint256 _lock) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lock`|`uint256`|block number until when the contract should be locked|


### deleteWindow

Delete merkle root at window index.

*Callable only by owner. Likely to be followed by a withdrawRewards call to clear contract state.*


```solidity
function deleteWindow(uint256 _windowIndex) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_windowIndex`|`uint256`|merkle root index to delete.|


### withdrawRewards

Emergency method that transfers rewards out of the contract if the contract was configured improperly.

*Callable only by owner.*


```solidity
function withdrawRewards(address _rewardToken, uint256 _amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardToken`|`address`|to withdraw from contract.|
|`_amount`|`uint256`|amount of rewards to withdraw.|


### claim

====== PUBLIC FUNCTIONS ======

Claim rewards for account, as described by Claim input object.

*unrecognised reward tokens in the claim, or those with zero value, will be ignored*


```solidity
function claim(Claim memory _claim) external notLocked nonReentrant;
```

### claimMulti

Batch claims to reduce gas versus individual submitting all claims.

*Method will fail if any individual claims within the batch would fail,
or if multiple accounts or rewards are being claimed for*


```solidity
function claimMulti(Claim[] memory claims) external notLocked nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claims`|`Claim[]`|array of claims to claim. Sender must always be the claimant|


### claimMultiDelegated

Makes multiple claims for users and sends to the delegate. Delegate must be whitelisted first.

*All claims must be made for the same reward token
Most efficient is to have contiguous claims in passed array for the same account.
We only check that the sender is whitelisted, we do not check that they are specifically whitelisted
for a given user.*


```solidity
function claimMultiDelegated(Claim[] memory claims) external whenNotPaused notLocked nonReentrant onlyWhitelisted;
```

### claimDelegated


```solidity
function claimDelegated(Claim memory _claim)
    external
    whenNotPaused
    notLocked
    nonReentrant
    onlyWhitelisted
    onlyWhitelistedFor(_claim.account);
```

### _processClaim


```solidity
function _processClaim(Claim memory _claim, address _receiver) internal;
```

### _verifyAndMarkClaimed

*Verify claim is valid and mark it as completed in this contract.*


```solidity
function _verifyAndMarkClaimed(Claim memory _claim) private;
```

### _setClaimed

*Mark claim as completed for account with assigned `accountIndex`*


```solidity
function _setClaimed(uint256 _windowIndex, uint256 _accountIndex) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_windowIndex`|`uint256`|to claim against|
|`_accountIndex`|`uint256`|assigned when MerkleTree generated|


### isClaimed

====== VIEWS ======

Returns True if the claim for `accountIndex` has already been completed for the Merkle root at `windowIndex`.

*This method will only work as intended if all `accountIndex`'s are unique for a given `windowIndex`*


```solidity
function isClaimed(uint256 _windowIndex, uint256 _accountIndex) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_windowIndex`|`uint256`|merkle root to check.|
|`_accountIndex`|`uint256`|account index to check within window index.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if claim has been executed already, False otherwise.|


### verifyClaim

Returns True if leaf described by {account, accountIndex, windowIndex, amount, token} is stored in Merkle root at given window index.

*order matters when hashing the leaf - including for struct parameters. Must align with merkle tree.*


```solidity
function verifyClaim(Claim memory _claim) public view returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_claim`|`Claim`|claim object describing rewards, accountIndex, account, window index, and merkle proof.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if leaf exists.|


### getWindow

fetch the window object as a struct


```solidity
function getWindow(uint256 _windowIndex) external view returns (Window memory);
```

