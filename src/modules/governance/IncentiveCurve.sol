// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

abstract contract IncentiveCurve {
    uint256 internal constant AVG_SECONDS_MONTH = 2628000;

    /**
     * @notice incentivises longer lock times with higher rewards
     * @dev Mapping of coefficient for the staking curve y=x/k*log(x)
     *      - where `x` is the staking time in months
     *      - `k` is a constant 56.0268900276223
     *      - Converges on 1e18
     * @dev do not initialize non-constants in upgradeable contracts, use the initializer below
     */
    uint256[37] public maxRatioArray;

    /**
     * @dev in theory this should be restricted to 'onlyInitializing' but all it will do is set
     *      the same array, so it's not an issue.
     *
     * @dev when performing reward calculations based on the incentive curve
     *      we use a calculation `amount * multiplier / 1e18`
     *      However, with very small amounts of wei (<13 for 6 months), this can result in 0 rewards
     *      You should check to ensure that calculations using the curve account for this
     */
    function __IncentiveCurve_init() internal {
        maxRatioArray = [
            1,
            2,
            3,
            4,
            5,
            6,
            83333333333300000, // 6
            105586554548800000, // 7
            128950935744800000, // 8
            153286798191400000, // 9
            178485723463700000, // 10
            204461099502300000, // 11
            231142134539100000, // 12
            258469880674300000, // 13
            286394488282000000, // 14
            314873248847800000, // 15
            343869161986300000, // 16
            373349862059400000, // 17
            403286798191400000, // 18
            433654597035900000, // 19
            464430560048100000, // 20
            495594261536300000, // 21
            527127223437300000, // 22
            559012649336100000, // 23
            591235204823000000, // 24
            623780834516600000, // 25
            656636608405400000, // 26
            689790591861100000, // 27
            723231734933100000, // 28
            756949777475800000, // 29
            790935167376600000, // 30
            825178989697100000, // 31
            859672904965600000, // 32
            894409095191000000, // 33
            929380216424000000, // 34
            964579356905500000, // 35
            1000000000000000000 // 36
        ];
    }

    function getDuration(uint256 months) public pure returns (uint32) {
        return uint32(months * AVG_SECONDS_MONTH);
    }

    function getSecondsMonths() public pure returns (uint256) {
        return AVG_SECONDS_MONTH;
    }
}
