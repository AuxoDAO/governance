// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import "../utils.sol";
import {
    TokenLocker, IERC20MintableBurnable, ITokenLockerEvents, IMigrateableEvents
} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {MockRewardsToken} from "../mocks/Token.sol";

import {PRV} from "@prv/PRV.sol";
import {Migrateable} from "@governance/Migrator.sol";
import {Terminatable} from "@governance/EarlyTermination.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

contract TestlockerSetup is Test, ITokenLockerEvents, IMigrateableEvents, UpgradeDeployer {
    using IsEOA for address;

    TokenLocker public locker;
    ARV public reward;
    Auxo public deposit;
    PRV public lsd;

    uint32 internal constant AVG_SECONDS_MONTH = 2628000;
    address internal GOV = address(1);

    /**
     * @dev when performing reward calculations based on the incentive curve
     *      we use a calculation `amount * multiplier / 1e18`
     *      However, with very small amounts of wei (<13 for 6 months), this can result in 0 rewards
     *      We need to set this here to ensure fuzz tests don't fail due to zero veShare errors
     *      but equally should check that all functions correctly test for this
     */
    uint256 internal constant MINIMUM_INCREASE_QTY = 13 wei;

    function prepareSetup() public {
        // setup the deposit and reward tokens
        deposit = new Auxo();
        deposit.mint(address(this), type(uint256).max);

        locker = _deployLockerUninitialized();
        reward = new ARV(address(locker));

        lsd = _deployPRV(address(deposit));

        // initialize
        locker.initialize(
            deposit, IERC20MintableBurnable(address(reward)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 100
        );

        locker.setPRV(address(lsd));
    }

    /// ===== HELPER FUNCTIONS ====

    function _fetchLock(address _account) internal view returns (TokenLocker.Lock memory lock) {
        (uint192 amount, uint32 lockedAt, uint32 lockDuration) = locker.lockOf(_account);
        lock = TokenLocker.Lock({amount: amount, lockedAt: lockedAt, lockDuration: lockDuration});
    }

    modifier notAdmin(address _account) {
        vm.assume(!isAdmin(_account));
        _;
    }

    function _makeDeposit(address _depositor, uint128 _qty, uint8 _months) internal notAdmin(_depositor) {
        vm.assume(
            _months <= locker.maxLockDuration() / AVG_SECONDS_MONTH
                && _months >= locker.minLockDuration() / AVG_SECONDS_MONTH
        );
        vm.assume(_depositor.isEOA());
        vm.assume(_qty >= locker.minLockAmount());

        deposit.transfer(_depositor, _qty);

        // overload to set tx.origin
        vm.startPrank(_depositor, _depositor);

        deposit.approve(address(locker), _qty);
        locker.depositByMonths(_qty, _months, _depositor);

        vm.stopPrank();
    }
}

// minimal contract that is used to test delegation
contract DelegateDeposit {
    function proxyDeposit(TokenLocker _locker, uint192 _amount, uint256 _months, address _receiver, ERC20 _token)
        external
    {
        _token.approve(address(_locker), _amount);
        _locker.depositByMonths(_amount, _months, _receiver);
    }
}

// minimal contract that is used to test migration
contract TestLocker is Migrateable, Terminatable {
    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function migrate(address staker) external override {
        revert("Not Implemented");
    }
}
