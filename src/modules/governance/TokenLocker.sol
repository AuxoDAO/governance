// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {AccessControlEnumerableUpgradeable as AccessControlEnumerable} from "@oz-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@oz/token/ERC20/extensions/IERC20Permit.sol";
import {IncentiveCurve} from "@governance/IncentiveCurve.sol";
import "@interfaces/IERC20MintableBurnable.sol";
import "@interfaces/IPRV.sol";
import "./Migrator.sol";
import "./EarlyTermination.sol";

interface ITokenLockerEvents {
    event MinLockAmountChanged(uint192 newLockAmount);
    event WhitelistedChanged(address indexed account, bool indexed whitelisted);
    event Deposited(uint192 amount, uint32 lockDuration, address indexed owner);
    event Withdrawn(uint192 amount, address indexed owner);
    event BoostedToMax(uint192 amount, address indexed owner);
    event IncreasedAmount(uint192 amount, address indexed owner);
    event IncreasedDuration(uint192 amount, uint32 lockDuration, uint32 lockedAt, address indexed owner);
    event Ejected(uint192 amount, address indexed owner);
    event EjectBufferUpdated(uint32 newEjectBuffer);
    event PRVAddressChanged(address prv);
}

contract TokenLocker is IncentiveCurve, ITokenLockerEvents, AccessControlEnumerable, Migrateable, Terminatable {
    /// ==================================
    /// ========     Modifiers    ========
    /// ==================================

    modifier lockNotExpired(Lock memory lock) {
        require(isLockExpired(lock) == false, "Lock expired");
        _;
    }

    modifier lockExists(address user) {
        require(hasLock(user) == true, "Lock !exist");
        _;
    }

    modifier noPreviousLock(address user) {
        require(hasLock(user) == false, "Lock exist");
        _;
    }

    modifier lockIsExpiredOrEmergency(Lock memory lock) {
        require(block.timestamp > lock.lockedAt + lock.lockDuration || emergencyUnlockTriggered, "Lock !expired");
        _;
    }

    modifier emergencyOff() {
        require(!emergencyUnlockTriggered, "emergency unlocked");
        _;
    }

    modifier onlyEOAorWL(address _receiver) {
        // only allow whitelisted contracts or EOAS
        require(tx.origin == _msgSender() || whitelisted[_msgSender()], "Not EOA or WL");
        // only allow whitelisted addresses to deposit to another address
        require(_msgSender() == _receiver || whitelisted[_msgSender()], "sender != receiver or WL");
        _;
    }

    modifier migrationIsOn() {
        require(migrationEnabled, "!migrationEnabled");
        require(migrator != address(0), "!migrator");
        _;
    }

    modifier onlyMigrator() {
        require(_msgSender() == migrator, "not migrator");
        _;
    }

    /// ==================================
    /// ======== Public Variables ========
    /// ==================================

    /// @notice token locked in the contract in exchange for reward tokens
    IERC20 public depositToken;

    /// @notice the token that will be returned to the user in exchange for depositToken
    IERC20MintableBurnable public veToken;

    /// @notice minimum timestamp for tokens to be locked (i.e. block.timestamp + 6 months)
    uint32 public minLockDuration;

    /// @notice maximum timetamp for tokens to be locked (i.e. block.timestamp + 36 months)
    uint32 public maxLockDuration;

    /// @notice minimum quantity of deposit tokens that must be locked in the contract
    uint192 public minLockAmount;

    /// @notice additional time period after lock has expired after which anyone can remove timelocked tokens on behalf of another user
    uint32 public ejectBuffer;

    /// @notice callable by the admin to allow early release of locked tokens
    bool public emergencyUnlockTriggered;

    /// @notice address of the Liquid Staking Derivative
    address public PRV;

    struct Lock {
        uint192 amount;
        uint32 lockedAt;
        uint32 lockDuration;
    }

    /// @notice lock details by address
    mapping(address => Lock) public lockOf;

    /// @notice whitelisted addresses can deposit on behalf of other accounts and be sent reward tokens if not EOAs
    mapping(address => bool) public whitelisted;

    /// @notice Compounder role can increment amounts for many accounts at once
    bytes32 public constant COMPOUNDER_ROLE = keccak256("COMPOUNDER_ROLE");

    /// ======== Gap ========

    /// @dev reserved storage slots for upgrades + inheritance
    uint256[50] private __gap;

    /// ======== Initializer ========

    /// @dev prevent initializer from being called on implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @dev deposit and veTokens are not checked for return values - make sure they return a boolean
    function initialize(
        IERC20 _depositToken,
        IERC20MintableBurnable _veToken,
        uint32 _minLockDuration,
        uint32 _maxLockDuration,
        uint192 _minLockAmount
    ) public initializer {
        __IncentiveCurve_init();
        __AccessControl_init();

        // admin is deployer & has all operator capabilities
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        veToken = _veToken;
        depositToken = _depositToken;
        require(_minLockDuration < _maxLockDuration, "Initialze: min>=max");
        minLockDuration = _minLockDuration;
        maxLockDuration = _maxLockDuration;
        minLockAmount = _minLockAmount;
        ejectBuffer = 7 days;

        emit MinLockAmountChanged(_minLockAmount);
        emit EjectBufferUpdated(ejectBuffer);
    }

    /// ===============================
    /// ======== Admin Setters ========
    /// ===============================

    /**
     * @notice updates the minimum lock amount that can be locked
     */
    function setMinLockAmount(uint192 minLockAmount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minLockAmount = minLockAmount_;
        emit MinLockAmountChanged(minLockAmount_);
    }

    /**
     * @notice allows a contract address to receieve tokens OR allows depositing on behalf of another user
     * @param _user address of the account to whitelist
     */
    function setWhitelisted(address _user, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelisted[_user] = _isWhitelisted;
        emit WhitelistedChanged(_user, _isWhitelisted);
    }

    /**
     * @notice if triggered, existing timelocks can be exited before the lockDuration has passed
     */
    function triggerEmergencyUnlock() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!emergencyUnlockTriggered, "EU: already triggered");
        emergencyUnlockTriggered = true;
    }

    /**
     * @notice sets the time allowed after a lock expires before anyone can exit a lock on behalf of a user
     */
    function setEjectBuffer(uint32 _buffer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ejectBuffer = _buffer;
        emit EjectBufferUpdated(_buffer);
    }

    /**
     * @notice Sets address the Early termination will use
     * @dev    not checked for return values - ensure the token returns a boolean
     */
    function setPRV(address _prv) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PRV = _prv;
        emit PRVAddressChanged(_prv);
    }

    /// ====================================
    /// ======== External Functions ========
    /// ====================================

    /**
     * @notice allows user to exit if their timelock has expired, transferring deposit tokens back to them and burning rewardTokens
     */
    function withdraw() external lockExists(_msgSender()) lockIsExpiredOrEmergency(lockOf[_msgSender()]) {
        Lock memory lock = lockOf[_msgSender()];

        // we can burn all shares since only one lock exists
        delete lockOf[_msgSender()];
        veToken.burn(_msgSender(), veToken.balanceOf(_msgSender()));
        require(depositToken.transfer(_msgSender(), lock.amount), "Withdraw: transfer failed");

        emit Withdrawn(lock.amount, _msgSender());
    }

    /**
     * @notice Any user can remove another from staking by calling the eject function, after the eject buffer has passed.
     * @dev Other stakers are incentivised to do so to because it gives them a bigger share of the voting and reward weight.
     * @param _lockAccounts array of addresses corresponding to the lockId we want to eject
     */
    function eject(address[] calldata _lockAccounts) external {
        for (uint256 i = 0; i < _lockAccounts.length; i++) {
            address account = _lockAccounts[i];
            Lock memory lock = lockOf[account];

            // skip if lockId is invalid or not expired
            if (lock.amount == 0 || lock.lockedAt + lock.lockDuration + ejectBuffer > uint32(block.timestamp)) {
                continue;
            }

            // remove the lock and exit the position
            delete lockOf[account];

            // burn the veToken in the ejectee's wallet
            veToken.burn(account, veToken.balanceOf(account));
            require(depositToken.transfer(account, lock.amount), "Eject: transfer failed");

            emit Ejected(lock.amount, account);
        }
    }

    /**
     * @notice depositing requires prior approval of this contract to spend the user's depositToken
     *         This method encodes the approval signature into the deposit call, allowing an offchain approval.
     * @param _deadline the latest timestamp the signature is valid
     * @dev params v,r,s are the ECDSA signature slices from signing the EIP-712 Permit message with the user's pk
     */
    function depositByMonthsWithSignature(
        uint192 _amount,
        uint256 _months,
        address _receiver,
        uint256 _deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(depositToken)).permit(_msgSender(), address(this), _amount, _deadline, v, r, s);
        depositByMonths(_amount, _months, _receiver);
    }

    /**
     * @notice locks depositTokens into the contract on behalf of a receiver
     * @dev unless whitelisted, the receiver MUST be the caller and an EOA
     * @param _amount the number of tokens to deposit
     * @param _months the number of whole months to deposit for
     * @param _receiver address where reward tokens will be sent
     */
    function depositByMonths(uint192 _amount, uint256 _months, address _receiver)
        public
        emergencyOff
        noPreviousLock(_receiver)
        onlyEOAorWL(_receiver)
    {
        require(_amount >= minLockAmount, "Deposit: too low");
        _deposit(_receiver, _amount, getDuration(_months));
    }

    /**
     * @notice depositing requires prior approval of this contract to spend the user's depositToken
     *         This method encodes the approval signature into the deposit call, allowing an offchain approval.
     * @param _deadline the latest timestamp the signature is valid
     * @dev params v,r,s are the ECDSA signature slices from signing the EIP-712 Permit message with the user's pk
     */
    function increaseAmountWithSignature(uint192 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external {
        IERC20Permit(address(depositToken)).permit(_msgSender(), address(this), _amount, _deadline, v, r, s);
        increaseAmount(_amount);
    }

    /**
     * @notice adds new tokens to an existing lock and restarts the lock. Duration is unchanged.
     * @param  _amountNewTokens the number of new deposit tokens to add to the user's lock
     */
    function increaseAmount(uint192 _amountNewTokens)
        public
        emergencyOff
        lockExists(_msgSender())
        lockNotExpired(lockOf[_msgSender()])
    {
        require(_amountNewTokens > 0, "IA: amount == 0");
        _increaseAmount(_amountNewTokens);
    }

    /**
     * @notice sets a new number of months to lock deposits for, up to the max lock duration.
     * @param  _months months to increase lock by
     */
    function increaseByMonths(uint256 _months)
        external
        emergencyOff
        lockExists(_msgSender())
        lockNotExpired(lockOf[_msgSender()])
    {
        require(_months > 0, "IBM: 0 Months");
        _increaseUnlockDuration(getDuration(_months));
    }

    /**
     * @notice adds new tokens to an array of existing locks from a spender address. Duration is unchanged.
     * @param receivers array or address to receive new tokens
     * @param _amountNewTokens array of amounts to add to the receiver's lock with the same index
     * @dev receiver needs to have an existing lock
     */
    function increaseAmountsForMany(address[] calldata receivers, uint192[] calldata _amountNewTokens)
        external
        emergencyOff
        onlyRole(COMPOUNDER_ROLE)
    {
        require(receivers.length == _amountNewTokens.length, "IA: Array legth mismatch");

        uint256 total = 0;
        for (uint256 i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            uint192 amount = _amountNewTokens[i];

            require(amount > 0, "IA: amount == 0");
            require(hasLock(receiver), "IA: Lock not found");
            Lock memory lock = lockOf[receiver];
            require(isLockExpired(lock) == false, "IA: Lock Expired");

            // compute the new veTokens to mint based on the current lock duration
            uint256 newVeShares = uint256(amount) * getLockMultiplier(lock.lockDuration) / 1e18;
            // for very low amounts of wei, newVeShares can be zero even with a positive deposit.
            require(newVeShares > 0, "IA: 0 veShares");

            // adjust the lock
            lockOf[receiver].amount += amount;
            total += uint256(amount);

            // transfer deposit tokens and mint more veTokens
            veToken.mint(receiver, newVeShares);
        }

        require(depositToken.transferFrom(_msgSender(), address(this), total), "IA: transfer failed");
    }

    /**
     * @notice takes the user's existing lock and replaces it with a new lock for the maximum duration, starting now.
     * @dev    In the event that the new lock duration longer than the old, additional reward tokens are minted
     */
    function boostToMax() external emergencyOff lockExists(_msgSender()) {
        Lock storage lock = lockOf[_msgSender()];

        // update the lock
        lock.lockedAt = uint32(block.timestamp);

        // if the user's lock is not maxed out, send them some new tokens
        if (lock.lockDuration != maxLockDuration) {
            // set lock duration to max
            lock.lockDuration = maxLockDuration;

            // calculate new ARV to be distributed, if so, mint new tokens
            uint256 maxDurationRewardShares = (lock.amount * getLockMultiplier(maxLockDuration) / 1e18);
            uint256 newRewardShares =  maxDurationRewardShares - veToken.balanceOf(_msgSender());
            if (newRewardShares > 0) veToken.mint(_msgSender(), newRewardShares);
        }

        emit BoostedToMax(lock.amount, _msgSender());
    }

    /**
     * @notice exits user's lock before expiration and mints PRV tokens in exchange, a termination fee may be applied.
     * @dev    the PRV contract must be set to enable early termination. Underlying assets are transferred to this address.
     */
    function terminateEarly()
        external
        override
        emergencyOff
        lockExists(_msgSender())
        lockNotExpired(lockOf[_msgSender()])
    {
        require(address(PRV) != address(0), "TE: disabled");
        uint256 amountToExit = 0;
        uint256 penaltyAmount = 0;

        Lock memory lock = lockOf[_msgSender()];

        // calculate the LSD amount the user will receive
        // if early exit fee is set, this will be net after the penalty
        if (earlyExitFee > 0 && penaltyBeneficiary != address(0)) {
            penaltyAmount = lock.amount * earlyExitFee / (10 ** 18);
            amountToExit = lock.amount - penaltyAmount;
        } else {
            amountToExit = lock.amount;
        }

        // Delete lock and burn the user's veTokens
        delete lockOf[_msgSender()];
        veToken.burn(_msgSender(), veToken.balanceOf(_msgSender()));

        // Deposit on the staking derivative
        require(depositToken.approve(PRV, amountToExit), "TE: approve failed");
        IPRV(PRV).depositFor(_msgSender(), amountToExit);

        // this should transfer the remainder of the user's balance to the beneficiary
        if (penaltyAmount > 0) {
            require(depositToken.transfer(penaltyBeneficiary, penaltyAmount), "TE: transfer failed");
        }

        emit EarlyExit(_msgSender(), amountToExit);
    }

    /**
     * @notice user can to transfer funds to a migrator contract once migration is enabled
     * @dev the migrator contract must handle the reinstantiation of locks
     */
    function migrate(address _staker)
        external
        override
        emergencyOff
        migrationIsOn
        onlyMigrator
        lockExists(_staker)
        lockNotExpired(lockOf[_staker])
    {
        Lock memory lock = lockOf[_staker];

        delete lockOf[_staker];

        veToken.burn(_staker, veToken.balanceOf(_staker));
        require(depositToken.transfer(migrator, lock.amount), "Migrate: transfer failed");
        emit Migrated(_staker, lock.amount);
    }

    /// ====================================
    /// ======== Internal Functions ========
    /// ====================================

    /**
     * @dev   actions the deposit for a numerical duration
     * @param _duration timestamp in seconds to lock for
     */
    function _deposit(address _receiver, uint192 _amount, uint32 _duration) internal {
        uint256 multiplier = getLockMultiplier(_duration);
        uint256 veShares = (_amount * multiplier) / 1e18;

        lockOf[_receiver] = Lock({amount: _amount, lockedAt: uint32(block.timestamp), lockDuration: _duration});

        require(depositToken.transferFrom(_msgSender(), address(this), _amount), "deposit: transfer failed");
        veToken.mint(_receiver, veShares);

        emit Deposited(_amount, _duration, _receiver);
    }

    /**
     * @dev   deposit additional tokens for the sender without modifying the unlock time
     *        the lock is restarted to avoid governance hijacking attacks.
     * @param _amountNewTokens how many new tokens to deposit
     */
    function _increaseAmount(uint192 _amountNewTokens) internal {
        address sender = _msgSender();

        // compute the new veTokens to mint based on the current lock duration
        uint256 newVeShares = (uint256(_amountNewTokens) * getLockMultiplier(lockOf[sender].lockDuration)) / 1e18;
        require(newVeShares > 0, "IA: 0 veShares");

        // increase the lock amount and reset the lock start time
        lockOf[sender].amount += _amountNewTokens;
        lockOf[sender].lockedAt = uint32(block.timestamp);

        // transfer deposit tokens and mint more veTokens
        require(depositToken.transferFrom(sender, address(this), _amountNewTokens), "IA: transfer failed");
        veToken.mint(sender, newVeShares);

        emit IncreasedAmount(_amountNewTokens, sender);
    }

    /**
     * @dev checks the passed duration is valid and mints new tokens in compensation.
     */
    function _increaseUnlockDuration(uint32 _duration) internal {
        Lock memory lock = lockOf[_msgSender()];

        uint32 newDuration = _duration + lock.lockDuration;
        require(newDuration <= maxLockDuration, "IUD: Duration > Max");

        // tokens are non-transferrable so the user must this many in their account
        uint256 veShares = (lock.amount * getLockMultiplier(lock.lockDuration)) / 1e18;
        uint256 newVeShares = (uint256(lock.amount) * getLockMultiplier(newDuration)) / 1e18;

        // Restart the lock by overriding
        lockOf[_msgSender()].lockDuration = newDuration;

        // send the user the difference in tokens
        veToken.mint(_msgSender(), newVeShares - veShares);

        emit IncreasedDuration(lock.amount, newDuration, lock.lockedAt, _msgSender());
    }

    /// =========================
    /// ======== Getters ========
    /// =========================

    /**
     * @notice checks if the passed account has an existing timelock
     * @dev    depositByMonths should only be called if this returns false, else use increaseLock
     */
    function hasLock(address _account) public view returns (bool) {
        return lockOf[_account].amount > 0;
    }

    /**
     * @notice fetches the reward token multiplier for a timelock duration
     * @param _duration in seconds of the timelock, will be converted to the nearest whole month
     * @return multiplier the %age (0 - 100%) of veToken per depositToken earned for a given duration
     */
    function getLockMultiplier(uint32 _duration) public view returns (uint256 multiplier) {
        require(_duration >= minLockDuration && _duration <= maxLockDuration, "GLM: Duration incorrect");
        uint256 month = uint256(_duration) / AVG_SECONDS_MONTH;
        multiplier = maxRatioArray[month];
        return multiplier;
    }

    /**
     * @return if current timestamp has passed the lock expiry date
     */
    function isLockExpired(Lock memory lock) public view returns (bool) {
        // upcasting is safer than downcasting
        return uint256(lock.lockedAt + lock.lockDuration) < block.timestamp;
    }

    /**
     * @notice overload to allow user to pass depositor address to check lock expiration
     */
    function isLockExpired(address _depositor) public view returns (bool) {
        Lock memory lock = lockOf[_depositor];
        // upcasting is safer than downcasting
        return uint256(lock.lockedAt + lock.lockDuration) < block.timestamp;
    }

    /**
     * @return lock the lock of a depositor.
     * @dev    accessing via the mapping returns a tuple. Struct is a bit easier to work with in some scenarios.
     */
    function getLock(address _depositor) public view returns (Lock memory lock) {
        lock = lockOf[_depositor];
    }

    /**
     * @notice checks if it's possible to exit a lock on behalf of another user
     * @param _account to check locks for
     * @dev   there is an additional `ejectBuffer` that must have passed beyond the lockDuration before ejection is possible
     */
    function canEject(address _account) external view returns (bool) {
        Lock memory lock = lockOf[_account];
        if (lock.amount == 0) return false;
        return uint256(lock.lockedAt + lock.lockDuration + ejectBuffer) <= block.timestamp;
    }

    /**
     * @notice allows a user to preview the amount of veTokens they will receive for a new deposit
     * @dev    will not work if the receiver already has a lock
     * @param _amount of deposit tokens
     * @param _months of lock duration
     * @param _receiver the address to be credited with the depoist and receive reward tokens
     */
    function previewDepositByMonths(uint192 _amount, uint256 _months, address _receiver)
        external
        view
        returns (uint256)
    {
        if (_amount <= minLockAmount) return 0;
        if (lockOf[_receiver].amount != 0) return 0;
        uint256 multiplier = getLockMultiplier(getDuration(_months));
        uint256 veShares = (_amount * multiplier) / 1e18;
        return veShares;
    }

    /**
     * @notice fetches the first DEFAULT_ADMIN_ROLE member who has control over admininstrative functions.
     * @dev    it's possible to have multiple admin roles, this just returns the first as a convenience.
     */
    function getAdmin() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }
}
