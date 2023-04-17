# Auxo
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/AUXO.sol)

**Inherits:**
ERC20, AccessControl, ERC20Permit

Auxo has the following key properties:
1) Implements the full ERC20 standard, including optional fields name, symbol and decimals
2) Implements gasless approval via EIP-712 and the `.permit` method
3) Can be minted only by accounts with the MINTER_ROLE
4) Has a DEFAULT_ADMIN_ROLE that can grant additional accounts MINTER_ROLE
5) Unless revoked, grants DEFAULT_ADMIN and MINTER roles to the deployer of the contract


## State Variables
### MINTER_ROLE
contract that handles locks of staked AUXO tokens, in exchange for ARV


```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


## Functions
### constructor


```solidity
constructor() ERC20("Auxo", "AUXO") ERC20Permit("Auxo");
```

### mint


```solidity
function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE);
```

