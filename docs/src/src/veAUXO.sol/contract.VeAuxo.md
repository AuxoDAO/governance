# VeAuxo
[Git Source](https://github.com/Alexintosh/auxo-governance/blob/bcf5f08a7131cdcb04a94e985ffb6537e6b575d7/src/veAUXO.sol)

**Inherits:**
ERC20, ERC20Votes

veAUXO has the following key properties:
1) Implements the full ERC20 standard, including optional fields name, symbol and decimals
2) Is non-transferrable
3) Can only be minted via staking AUXO tokens for a lock period
4) Can only be burned via unstaking AUXO tokens at the end of the lock period
5) Each veAUXO token represents 1 unit of voting power in the Auxo DAO Governor contract.
6) Implements the OpenZeppelin IVotes interface, including EIP-712 for gasless vote delegation.


## State Variables
### tokenLocker
contract that handles locks of staked AUXO tokens, in exchange for veAUXO


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
constructor(address _tokenLocker) ERC20("Voting Escrow Auxo", "veAUXO") ERC20Permit("Voting Escrow Auxo");
```

### mint

supply of veAUXO (minting and burning) is entirely controlled
by the tokenLocker contract and therefore the stacking mechanism


```solidity
function mint(address to, uint256 amount) public onlyTokenLocker;
```

### burn


```solidity
function burn(address to, uint256 amount) public onlyTokenLocker;
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

