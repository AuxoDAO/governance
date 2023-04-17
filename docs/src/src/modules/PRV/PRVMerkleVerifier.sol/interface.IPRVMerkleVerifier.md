# IPRVMerkleVerifier
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/PRVMerkleVerifier.sol)

**Inherits:**
[IWithdrawalManager](/src/interfaces/IWithdrawalManager.sol/interface.IWithdrawalManager.md)


## Events
### CreatedWindow

```solidity
event CreatedWindow(uint256 indexed windowIndex, uint256 maxAmount, uint32 startBlock, uint32 endBlock);
```

### DeletedWindow

```solidity
event DeletedWindow(uint256 indexed windowIndex, address indexed sender);
```

### PRVSet

```solidity
event PRVSet(address indexed prv, address indexed auxo);
```

### BudgetUpdated

```solidity
event BudgetUpdated(uint256 indexed windowIndex, uint256 oldBudget, uint256 newBudget);
```

### LockSet

```solidity
event LockSet(uint256 indexed lockBlock);
```

## Structs
### Claim
represents the maximum quantity of PRV that can be redeemed in a given window.

*this is computed off chain based on a snapshot at a previous block.*


```solidity
struct Claim {
    uint256 windowIndex;
    uint256 amount;
    bytes32[] merkleProof;
    address account;
}
```

### Window
stores a merkle root of claims which are valid between a start and end block.


```solidity
struct Window {
    uint256 maxAmount;
    uint256 totalRedeemed;
    uint32 startBlock;
    uint32 endBlock;
    bytes32 merkleRoot;
}
```

