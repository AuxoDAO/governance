# IMerkleDistributorCore
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/rewards/MerkleDistributor.sol)

events and structs used in the MerkleDistributor contract


## Events
### Claimed

```solidity
event Claimed(
    address indexed caller,
    uint256 indexed windowIndex,
    address indexed account,
    uint256 accountIndex,
    uint256 rewardAmount,
    address rewardToken
);
```

### ClaimDelegated

```solidity
event ClaimDelegated(
    address indexed delegatee,
    uint256 indexed windowIndex,
    address indexed account,
    uint256 accountIndex,
    uint256 rewardAmount,
    address rewardToken
);
```

### ClaimDelegatedMulti
compressed event data for delegated batch claims.

*`accountIndexes` and `windowIndexes` are index aligned and can be used
as a composite key to find the full claim data off-chain.*

*limited to 255 windows which is approx 21 years for 1 month windows*


```solidity
event ClaimDelegatedMulti(
    address indexed delegate, address indexed token, uint8[] windowIndexes, uint16[] accountIndexes
);
```

### CreatedWindow

```solidity
event CreatedWindow(
    uint256 indexed windowIndex, address indexed owner, uint256 rewardAmount, address indexed rewardToken
);
```

### WithdrawRewards

```solidity
event WithdrawRewards(address indexed owner, uint256 amount, address indexed token);
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
### Claim
groups reward data for a given account in the window

*Assigned off chain. Allows for efficiently tracking claimants using a bitmap.*


```solidity
struct Claim {
    uint256 windowIndex;
    uint256 accountIndex;
    uint256 amount;
    address token;
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
    uint256 rewardAmount;
    address rewardToken;
    string ipfsHash;
}
```

