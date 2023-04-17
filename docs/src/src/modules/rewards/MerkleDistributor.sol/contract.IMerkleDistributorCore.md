# IMerkleDistributorCore
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/modules/rewards/MerkleDistributor.sol)

events and structs used in the MerkleDistributor contract


## Events
### Claimed

```solidity
event Claimed(
    address indexed caller, uint256 indexed windowIndex, address indexed account, uint256 accountIndex, Reward rewards
);
```

### ClaimDelegated

```solidity
event ClaimDelegated(
    address indexed delegatee,
    uint256 indexed windowIndex,
    address indexed account,
    uint256 accountIndex,
    Reward rewards
);
```

### ClaimLimited

```solidity
event ClaimLimited(
    address indexed caller,
    uint256 indexed windowIndex,
    address indexed account,
    uint256 accountIndex,
    Reward rewards,
    bool[] forfeitRewardTokens
);
```

### CreatedWindow

```solidity
event CreatedWindow(uint256 indexed windowIndex, address indexed owner, Reward reward);
```

### WithdrawRewards

```solidity
event WithdrawRewards(address indexed owner, uint256 amount, address indexed currency);
```

### DeleteWindow

```solidity
event DeleteWindow(uint256 indexed windowIndex, address indexed owner);
```

### LockSet

```solidity
event LockSet(uint256 indexed lockBlock);
```

## Structs
### Reward
groups a reward token and quantity into a single entry.


```solidity
struct Reward {
    uint256 amount;
    address token;
}
```

### Claim
groups reward data for a given account in the window

*Assigned off chain. Allows for efficiently tracking claimants using a bitmap.*


```solidity
struct Claim {
    uint256 windowIndex;
    uint256 accountIndex;
    Reward rewards;
    bytes32[] merkleProof;
    address account;
}
```

### Window
A Window is created by a trusted operator for each round of rewards, to be distrubted according to a predefined merkle tree

*stored as string to query the ipfs data without needing to reconstruct multihash - go to https://cloudflare-ipfs.com/ipfs/<IPFS-HASH>.*


```solidity
struct Window {
    bytes32 merkleRoot;
    Reward totalRewards;
    string ipfsHash;
}
```

