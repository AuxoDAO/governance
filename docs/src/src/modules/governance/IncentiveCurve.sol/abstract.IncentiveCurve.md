# IncentiveCurve
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/IncentiveCurve.sol)


## State Variables
### AVG_SECONDS_MONTH

```solidity
uint256 internal constant AVG_SECONDS_MONTH = 2628000;
```


### maxRatioArray
incentivises longer lock times with higher rewards

*Mapping of coefficient for the staking curve y=x/k*log(x)
- where `x` is the staking time in months
- `k` is a constant 56.0268900276223
- Converges on 1e18*

*do not initialize non-constants in upgradeable contracts, use the initializer below*


```solidity
uint256[37] public maxRatioArray;
```


## Functions
### __IncentiveCurve_init

*in theory this should be restricted to 'onlyInitializing' but all it will do is set
the same array, so it's not an issue.*

*when performing reward calculations based on the incentive curve
we use a calculation `amount * multiplier / 1e18`
However, with very small amounts of wei (<13 for 6 months), this can result in 0 rewards
You should check to ensure that calculations using the curve account for this*


```solidity
function __IncentiveCurve_init() internal;
```

### getDuration


```solidity
function getDuration(uint256 months) public pure returns (uint32);
```

### getSecondsMonths


```solidity
function getSecondsMonths() public pure returns (uint256);
```

