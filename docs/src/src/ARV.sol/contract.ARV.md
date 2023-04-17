# ARV
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/ARV.sol)

**Inherits:**
ERC20, ERC20Votes

ARV has the following key properties:
1) Implements the full ERC20 standard, including optional fields name, symbol and decimals
2) Is non-transferrable
3) Can only be minted via staking AUXO tokens for a lock period
4) Can only be burned via unstaking AUXO tokens at the end of the lock period.
Note that, after a grace period, it is possible for users other than the original staker to force a user's exit.
5) Each ARV token represents 1 unit of voting power in the Auxo DAO Governor contract.
6) Implements the OpenZeppelin IVotes interface, including EIP-712 for gasless vote delegation.


## State Variables
### tokenLocker
contract that handles locks of staked AUXO tokens, in exchange for ARV


```solidity
address public immutable tokenLocker;
```


## Functions
### onlyTokenLocker


```solidity
modifier onlyTokenLocker();
```

### constructor


```solidity
constructor(address _tokenLocker) ERC20("Auxo Active Reward Vault", "ARV") ERC20Permit("Auxo Active Reward Vault");
```

### mint

supply of ARV (minting and burning) is entirely controlled
by the tokenLocker contract and therefore the staking mechanism


```solidity
function mint(address to, uint256 amount) external onlyTokenLocker;
```

### burn


```solidity
function burn(address from, uint256 amount) external onlyTokenLocker;
```

### _transfer

*Disables all transfer related functions*


```solidity
function _transfer(address, address, uint256) internal virtual override;
```

### _approve

*Disables all approval related functions*


```solidity
function _approve(address, address, uint256) internal virtual override;
```

### _afterTokenTransfer

*the below overrides are required by Solidity*


```solidity
function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes);
```

### _mint


```solidity
function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes);
```

### _burn


```solidity
function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes);
```

