// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "../../utils.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {MockRewardsToken} from "../../mocks/Token.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {RollStaker} from "@prv/RollStaker.sol";
import {PRVRouter} from "@prv/PRVRouter.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

/**
 * @dev this contract uses foundry fuzzing to simulate migrating a user with multiple veDOUGH locks.
 */
contract TestUpgradoorIntegrationSetup is Test, UpgradeDeployer {
    using IsEOA for address;

    // constants & immutables
    uint32 public constant AVG_SECONDS_MONTH = 2628000;
    address public immutable GOV = address(this);

    /// @dev the number of locks to create for the imaginary user
    uint8 public constant LOCKS_PER_USER = 5;

    /// @dev max rounding error (in wei) of calculating expected vs actual tokens
    uint256 public constant MAX_DELTA = 1;

    // mocks
    MockRewardsToken public mockDOUGH;
    MockRewardsToken public veDOUGH;

    // admin contracts for proxies
    address public adminLocker;
    address public adminOld;

    // actual contracts
    SharesTimeLock public OLD;
    Upgradoor public UP;
    TokenLocker public tokenLocker;
    ARV public veauxo;
    Auxo public auxo;
    PRV public lsd;
    PRVRouter public router;
    RollStaker roll;

    modifier notAdmin(address _who) {
        vm.assume(!isAdmin(_who));
        _;
    }

    /// ===== SETUP =====

    function prepareSetup() public {
        mockDOUGH = new MockRewardsToken();
        veDOUGH = new MockRewardsToken();

        OLD = _deploySharesTimelock();
        tokenLocker = _deployLockerUninitialized();

        adminOld = proxies[SHARES_TIMELOCK].proxy.getProxyOwner();
        adminLocker = proxies[TOKEN_LOCKER].proxy.getProxyOwner();

        // setup the auxo and veauxo tokens
        auxo = new Auxo();
        auxo.mint(address(this), type(uint128).max);
        veauxo = new ARV(address(tokenLocker));

        tokenLocker.initialize(
            auxo, IERC20MintableBurnable(address(veauxo)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 0.0001 ether
        );

        OLD.initialize(
            address(mockDOUGH),
            IERC20MintableBurnable(address(veDOUGH)),
            6 * AVG_SECONDS_MONTH, // min lock
            36 * AVG_SECONDS_MONTH, // max lock
            1 ether // 1 DOUGH token
        );

        // configure the staking manager and xAUXO
        lsd = _deployPRV(address(auxo));

        roll = _deployRollStaker(address(lsd));
        router = new PRVRouter(address(auxo), address(lsd), address(roll));

        // ---- Setting Upgrador ------

        // Deploy upgradoor
        UP =
        new Upgradoor(address(OLD), address(auxo), address(mockDOUGH), address(tokenLocker), address(lsd), address(veDOUGH), address(router));

        // Set the migrator on the old timelock && enable migration
        OLD.setMigratoor(address(UP));
        OLD.setMigrationON();

        // We whitelist the Upgradoor contract to auxo on the tokenlocker
        tokenLocker.setWhitelisted(address(UP), true);

        // We give minting role to the Upgradoor
        auxo.grantRole(auxo.MINTER_ROLE(), address(UP));
    }

    /// ===== Test Helpers =====

    /// @dev creates an actual lock in the old sharestimelock contract with the passed values
    function _addMockLock(uint8 _months, address _receiver, uint128 _amount) internal {
        vm.assume(_receiver.isEOA());
        vm.assume(_amount >= OLD.minLockAmount());
        vm.assume(_months <= 36 && _months >= 6);

        mockDOUGH.mint(_receiver, _amount);

        vm.startPrank(_receiver, _receiver);
        mockDOUGH.approve(address(OLD), _amount);
        OLD.depositByMonths(_amount, _months, _receiver);
        vm.stopPrank();
    }

    /// @dev setup the xAUXO contract with a random entry fee and beneficiary
    function _initXAuxo(uint256 _xAuxoEntryFee, address _beneficiary) internal {
        vm.assume(_xAuxoEntryFee <= lsd.MAX_FEE());
        vm.assume(_beneficiary != address(0));
        lsd.setFeePolicy(_xAuxoEntryFee, _beneficiary);
    }

    /// @dev logging and time travel
    /// @param _fastForward move forward by this many seconds.
    function _warpTo(uint64 _fastForward) internal {
        uint256 warpTo = block.timestamp + _fastForward;
        console2.log(
            "\nWarping to %d by fastforwarding %d months (%d seconds)\n",
            warpTo,
            _fastForward / AVG_SECONDS_MONTH,
            _fastForward
        );
        vm.warp(warpTo);
    }

    /// @dev pass a timestamp to see how many months have passed `_since` that timestamp
    function _logMonthsPassed(uint256 _since) internal view {
        console2.log("\nCurrent Timestamp %d", block.timestamp);
        console2.log("\nMonths Passed %d\n", (block.timestamp - _since) / AVG_SECONDS_MONTH);
    }

    /**
     * @dev sets up LOCKS_PER_USER locks with 1 month in between each.
     * @dev returns a tuple containing:
     *       - total DOUGH in all locks
     *       - (months locked, lockedAt timestamp, lockDuration) for longest lock
     *       NB if multiple equal use the first instance
     */
    function _initLocks(
        address _depositor,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) internal returns (uint256 total, uint256 longestLockMonths, uint32 longestLockedAt, uint32 longestLockDuration) {
        uint256 longestLockIdx;
        for (uint256 i; i < _amounts.length; i++) {
            // using vm.assume will cause tests to fail with too many rejects.
            // It's easier to just overwrite invalid entries with valid - especially given that we are not testing lock logic
            if (_months[i] > 36) _months[i] = 36;
            if (_months[i] < 6) _months[i] = 6;
            // Auxo is converted 100:1 from DOUGH, this limit is just to make logging more readable
            if (_amounts[i] < 100 ether) _amounts[i] = 100 ether;

            // Space out locks with 1 month in between. With 5 test cases, this means none will have expired by default.
            vm.warp(block.timestamp + AVG_SECONDS_MONTH + 100);

            total += _amounts[i];

            // note if the lock is the longest we have seen, save it
            if (_months[i] > longestLockMonths) {
                longestLockMonths = _months[i];
                longestLockedAt = uint32(block.timestamp);
                longestLockIdx = i;
            }

            // save initial dough and vedough balances of the user
            uint256 doughBalanceBefore = mockDOUGH.balanceOf(address(OLD));
            uint256 vedoughBalanceBefore = veDOUGH.balanceOf(_depositor);

            // add the lock
            console2.log(
                "Adding Lock at %d. Months %d Amount %d DOUGH", block.timestamp, _months[i], _amounts[i] / 1e18
            );
            _addMockLock(_months[i], _depositor, _amounts[i]);

            uint256 expectedVeDoughBalance =
                (_amounts[i] * OLD.maxRatioArray(_months[i])) / 10 ** 18 + vedoughBalanceBefore;

            // quick check to see things add up
            assertEq(mockDOUGH.balanceOf(address(OLD)), doughBalanceBefore + _amounts[i]);
            assertEq(veDOUGH.balanceOf(_depositor), expectedVeDoughBalance);
        }

        // Add some logging and validate the logs have loaded correctly
        _logMonthsPassed(longestLockedAt);

        SharesTimeLock.Lock[] memory locks = OLD.getLocks(_depositor);

        // optional, goes through the locks and logs to console for inspection
        // we get the longestLockDuration directly from the lock array instead of calculating manually
        for (uint256 lk; lk < locks.length; lk++) {
            SharesTimeLock.Lock memory lock = locks[lk];

            uint32 expiresAt = lock.lockedAt + lock.lockDuration;
            bool hasExpired = expiresAt < block.timestamp;

            console2.log("[Lock %d] Expires: %d", lk, expiresAt);

            if (lk == longestLockIdx) {
                longestLockDuration = lock.lockDuration;
                console2.log(
                    "^^^^^^^^ Lock %d selected for longest Duration at %d = %d months",
                    lk,
                    longestLockDuration,
                    longestLockDuration / AVG_SECONDS_MONTH
                );
            }
            assert(!hasExpired);
        }
        assertEq(mockDOUGH.balanceOf(address(OLD)), total);
    }

    /**
     * @dev returns a tuple containing:
     *    - amountValid: total DOUGH inside non-expired locks
     *    - longestValidLock: longest lock that has not yet expired (will return first found if there is a tie)
     *    - foundValidLock: are any locks still valid, or are all expired?
     *    NB: we could check longestValidLock for uninitialized properties but this is more explicit
     */
    function _getLongestValidLock(address _depositor)
        internal
        view
        returns (
            uint256 amountValid,
            SharesTimeLock.Lock memory longestValidLock,
            bool foundValidLock,
            uint256 numberOfValidLocks
        )
    {
        uint256 longestValidLockId;
        SharesTimeLock.Lock[] memory locks = OLD.getLocks(_depositor);

        for (uint256 lk; lk < locks.length; lk++) {
            SharesTimeLock.Lock memory lock = locks[lk];
            uint32 expiresAt = lock.lockedAt + lock.lockDuration;
            bool hasExpired = expiresAt <= block.timestamp;
            console2.log("[Lock %d] Expires: %d, Expired: %s", lk, expiresAt, hasExpired);

            if (!hasExpired) {
                foundValidLock = true;
                amountValid += lock.amount;
                numberOfValidLocks++;
                if (lock.lockDuration > longestValidLock.lockDuration) {
                    longestValidLock = lock;
                    longestValidLockId = lk;
                }
            }
        }

        console2.log(
            "LongestValidLock %d now has longest Duration at %d = %d months",
            longestValidLockId,
            longestValidLock.lockDuration,
            longestValidLock.lockDuration / AVG_SECONDS_MONTH
        );
    }

    function _calculateVeAuxo(SharesTimeLock.Lock memory _lock) internal view returns (uint256) {
        uint256 adjustedMonths = UP.getMonthsNewLock(_lock.lockedAt, _lock.lockDuration);
        console2.log("[Lock] Amount: %d, LockedAt: %d, Duration: %d", _lock.amount, _lock.lockedAt, _lock.lockDuration);
        uint256 adjustedLockAmount = _lock.amount / 100;
        uint256 expected = (adjustedLockAmount * tokenLocker.maxRatioArray(adjustedMonths)) / (10 ** 18);
        console2.log(
            "[Lock] Multiplier: %d, Months: %d, Expected: %d",
            tokenLocker.maxRatioArray(adjustedMonths),
            adjustedMonths,
            expected
        );
        return expected;
    }

    function _getValidReceiver(address _receiver, address _depositor, uint256 _nonce) internal returns (address) {
        // we can't add duplicate locks, so this attempts to create
        // a duplicate then sets a new receiving address
        if (tokenLocker.hasLock(_receiver)) {
            vm.expectRevert("Lock exist");
            vm.prank(_depositor);
            UP.upgradeSingleLockARV(_receiver);

            // hash the address to more-or-less guarantee a unique new address
            _receiver = address(bytes20(keccak256(abi.encodePacked(_receiver, _nonce))));
        }
        console2.log("Receiver %s", _receiver);
        vm.assume(_receiver.isEOA());

        return _receiver;
    }

    function _getNextLongestLockAsLock(address _depositor) internal view returns (SharesTimeLock.Lock memory) {
        SharesTimeLock.Lock[] memory locks = OLD.getLocks(_depositor);
        (,,, uint256 nextLongestLockIndex) = UP.getNextLongestLock(_depositor);
        return locks[nextLongestLockIndex];
    }
}
