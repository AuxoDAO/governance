# PRVRouter
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/PRV/PRVRouter.sol)


## State Variables
### AUXO

```solidity
address public immutable AUXO;
```


### PRV

```solidity
address public immutable PRV;
```


### Staker

```solidity
address public immutable Staker;
```


## Functions
### constructor


```solidity
constructor(address _auxo, address _prv, address _staker);
```

### convertAndStake


```solidity
function convertAndStake(uint256 amount) external;
```

### convertAndStake


```solidity
function convertAndStake(uint256 amount, address _receiver) external;
```

### convertAndStakeWithSignature


```solidity
function convertAndStakeWithSignature(
    uint256 amount,
    address _receiver,
    uint256 _deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```

