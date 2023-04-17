# LowGasSafeMath
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/vedough-bridge/SharesTimeLock.sol)

Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost


## Functions
### add

Returns x + y, reverts if sum overflows uint256


```solidity
function add(uint256 x, uint256 y) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The augend|
|`y`|`uint256`|The addend|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The sum of x and y|


### add

Returns x + y, reverts if sum overflows uint256


```solidity
function add(uint256 x, uint256 y, string memory errorMessage) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The augend|
|`y`|`uint256`|The addend|
|`errorMessage`|`string`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The sum of x and y|


### sub

Returns x - y, reverts if underflows


```solidity
function sub(uint256 x, uint256 y) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The minuend|
|`y`|`uint256`|The subtrahend|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The difference of x and y|


### sub

Returns x - y, reverts if underflows


```solidity
function sub(uint256 x, uint256 y, string memory errorMessage) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The minuend|
|`y`|`uint256`|The subtrahend|
|`errorMessage`|`string`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The difference of x and y|


### mul

Returns x * y, reverts if overflows


```solidity
function mul(uint256 x, uint256 y) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The multiplicand|
|`y`|`uint256`|The multiplier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The product of x and y|


### mul

Returns x * y, reverts if overflows


```solidity
function mul(uint256 x, uint256 y, string memory errorMessage) internal pure returns (uint256 z);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The multiplicand|
|`y`|`uint256`|The multiplier|
|`errorMessage`|`string`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`z`|`uint256`|The product of x and y|


