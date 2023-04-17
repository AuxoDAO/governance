// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20 as IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IERC20Permit as IERC20Permit} from "@oz/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20 as SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {AccessControl as AccessControl} from "@oz/access/AccessControl.sol";
import {Pausable as Pausable} from "@oz/security/Pausable.sol";
import {ReentrancyGuard as ReentrancyGuard} from "@oz/security/ReentrancyGuard.sol";
import {SafeCast as SafeCast} from "@oz/utils/math/SafeCast.sol";

import {Bitfields} from "@prv/bitfield.sol";
import {IRollStaker} from "@prv/RollStaker.sol";

import "@forge-std/console2.sol";

/**
 * @dev upgrade free version of RollStaker for use in invariant testing
 */
contract RollStaker is IRollStaker, AccessControl, Pausable, ReentrancyGuard {
    using Bitfields for Bitfields.Bitfield;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /* ===== Public Variables ===== */

    /// @notice operators can increment epochs and pause/unpause the contract
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice the token to be staked in the contract. Set during initializer.
    IERC20 public stakingToken;

    /// @notice the current epoch ID
    uint8 public currentEpochId;

    /// @notice list of historical epoch balances by epoch Id
    uint256[] public epochBalances;

    /// @notice the current quantity of tokens pending activation next epoch
    uint256 public epochPendingBalance;

    /// @notice contains information about each user's staking positions
    mapping(address => UserStake) public userStakes;

    /* ===== Gap ===== */

    /// @dev reserved storage slots for upgrades
    uint256[50] private __gap;

    /* ====== Modifiers ====== */

    modifier nonZero(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    /* ===== Initializer ===== */

    /// @dev disable initializers in implementation contracts
    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);

        // admin is deployer & has all operator capabilities
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());

        // initialize our epochs array with the first and next epoch having zero deposits
        epochBalances.push(0);
        emit NewEpoch(currentEpochId, block.timestamp);
    }

    /* ===== Getters: Contract Queries ===== */

    /**
     * @notice based on current deposits, what will be the number of tokens earning staking rewards starting next epoch.
     * @dev    assumes no further deposits or withdrawals. Use this function instead of fetching next epoch directly.
     */
    function getProjectedNextEpochBalance() public view returns (uint256) {
        return epochBalances[currentEpochId] + epochPendingBalance;
    }

    /// @notice epoch balance of the contract right now
    function getCurrentEpochBalance() external view returns (uint256) {
        return epochBalances[currentEpochId];
    }

    /**
     * @return balance of staking tokens at a given epochId. if passed future epoch, will return a projection.
     */
    function getEpochBalanceWithProjection(uint8 _epochId) external view returns (uint256) {
        if (_epochId > currentEpochId) return getProjectedNextEpochBalance();
        return epochBalances[_epochId];
    }

    /// @notice fetch the epoch balances array 'as-is', with no projections
    function getEpochBalances() external view returns (uint256[] memory) {
        return epochBalances;
    }

    /* ===== Getters: User Queries ===== */

    /// @notice fetches the total user balance locked in the contract, including pending deposits
    function getTotalBalanceForUser(address _user) public view returns (uint256) {
        return uint256(userStakes[_user].pending) + uint256(userStakes[_user].active);
    }

    /**
     * @notice gets staked tokens currently pending and not earning rewards for the user
     * @dev    this will be zero if the last written to epoch is not the current epoch
     */
    function getPendingBalanceForUser(address _user) public view returns (uint256) {
        return (userStakes[_user].epochWritten == currentEpochId) ? userStakes[_user].pending : 0;
    }

    /**
     * @notice gets staked tokens currently active and earning rewards for the user
     * @dev    if the last written to epoch is the current epoch
     *         the user has pending deposits which we exclude.
     */
    function getActiveBalanceForUser(address _user) public view returns (uint256) {
        return (userStakes[_user].epochWritten == currentEpochId)
            ? userStakes[_user].active
            : getTotalBalanceForUser(_user);
    }

    /// @notice fetches the user's stake data into memory
    function getUserStakingData(address _user) public view returns (UserStake memory) {
        return userStakes[_user];
    }

    /// @notice return the bitfield of activations
    function getActivations(address _user) external view returns (Bitfields.Bitfield memory) {
        return userStakes[_user].activations;
    }

    /// @notice is the user currently active
    function userIsActive(address _user) external view returns (bool) {
        return userStakes[_user].activations.isActive(currentEpochId);
    }

    /// @notice was the user active for a particular epoch
    function userIsActiveForEpoch(address _user, uint8 _epoch) external view returns (bool) {
        return userStakes[_user].activations.isActive(_epoch);
    }

    /// @notice starting from current epoch, returns the last epoch in which the user was active
    function lastEpochUserWasActive(address _user) external view returns (uint8) {
        return userStakes[_user].activations.lastActive(currentEpochId);
    }

    /* ===== Public Functions ===== */

    /**
     * @notice lock staking tokens into the contract, can be removed at any time. Must approve a transfer first.
     *         Deposits will be added to the NEXT epoch, and the user will be eligible for rewards at the end of it.
     * @param  _amount the amount of tokens to deposit, must be > 0
     * @dev    will set the user as active for all future epochs if not already, no need to restake.
     */
    function deposit(uint256 _amount) external nonReentrant whenNotPaused nonZero(_amount) {
        _depositFor(_amount, _msgSender());
    }

    /// @notice sender deposits on behalf of another `_receiver`. Tokens are taken from the sender.
    function depositFor(uint256 _amount, address _receiver) external nonReentrant whenNotPaused nonZero(_amount) {
        _depositFor(_amount, _receiver);
    }

    /// @notice make a gasless deposit using EIP-712 compliant permit signature for approvals
    function depositWithSignature(uint256 _amount, uint256 _deadline, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
        whenNotPaused
        nonZero(_amount)
    {
        IERC20Permit(address(stakingToken)).permit(_msgSender(), address(this), _amount, _deadline, v, r, s);
        _depositFor(_amount, _msgSender());
    }

    /// @notice sender deposits on behalf of another `_receiver`. Tokens are taken from the sender.
    function depositForWithSignature(
        uint256 _amount,
        address _receiver,
        uint256 _deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused nonZero(_amount) {
        IERC20Permit(address(stakingToken)).permit(_msgSender(), address(this), _amount, _deadline, v, r, s);
        _depositFor(_amount, _receiver);
    }

    /// @dev actions the deposit for the receiver on behalf of the sender
    function _depositFor(uint256 _amount, address _receiver) internal {
        // fetch the user and update their active balances if needed
        UserStake storage u = userStakes[_receiver];
        _resetPendingIfEpochHasPassed(u);

        // deposits are valid from next epoch onwards
        uint8 nextEpochId = currentEpochId + 1;

        // initialize the bitfield in the event this is a new user
        if (u.activations.isEmpty()) u.activations = Bitfields.initialize(nextEpochId);

        // if the user is not activated, we actvate them
        if (!u.activations.isActive(nextEpochId)) u.activations.activateFrom(nextEpochId);

        // add to the user's pending deposits for this epoch
        u.pending += _amount.toUint120();
        u.epochWritten = currentEpochId;

        // finally update the contract pending balance
        epochPendingBalance += _amount;

        stakingToken.safeTransferFrom(_msgSender(), address(this), _amount);
        emit Deposited(_msgSender(), _receiver, nextEpochId, _amount);
    }

    /// @notice removes the user's staked tokens from the contract, including pending deposits next epoch.
    function quit() external {
        UserStake memory u = userStakes[_msgSender()];
        withdraw(uint256(u.pending) + uint256(u.active));
    }

    /**
     * @notice withdraw tokens from the contract. This can only be called by the depositor.
     * @param  _amount amount to withdraw, cannot be zero and must be <= user's total deposits
     * @dev    If withdrawing all tokens, the user will be set as inactive
     */
    function withdraw(uint256 _amount) public nonReentrant whenNotPaused nonZero(_amount) {
        // fetch the user and their total balance
        UserStake storage user = userStakes[_msgSender()];

        uint256 total = uint256(user.pending) + uint256(user.active);
        // note amount is checked to be > 0, so in the event that a user
        // has nothing to withdraw (no pending an no active), this will revert
        if (_amount > total) revert InvalidWithdrawalAmount(_msgSender(), _amount);

        _amount == total ? _exit(user) : _withdraw(_amount, user);
    }

    /**
     * @dev reset user's position, deactivate and transfer all tokens
     */
    function _exit(UserStake storage _u) internal {
        // update the state before exiting
        _resetPendingIfEpochHasPassed(_u);

        // remove from the contract
        epochPendingBalance -= _u.pending;
        epochBalances[currentEpochId] -= _u.active;

        // save the total, and reset the state
        uint256 total = uint256(_u.pending) + uint256(_u.active);
        _u.pending = 0;
        _u.active = 0;
        _u.epochWritten = currentEpochId;

        // the user will be deactivated from the current epoch onwards
        _u.activations.deactivateFrom(currentEpochId);

        stakingToken.safeTransfer(_msgSender(), total);
        emit Exited(_msgSender(), currentEpochId);
    }

    /**
     * @notice internal function to action withdrawal once paramaters checked.
     * @dev    this function assumes < the full balance is being withdrawn.
     *         if the full balance is being withdrawn, use _exit
     * @param  _amount to withdraw, assumed to be valid
     * @param  _u storage pointer to the user withdrawal data
     */
    function _withdraw(uint256 _amount, UserStake storage _u) internal {
        // update the state before withdrawing
        _resetPendingIfEpochHasPassed(_u);

        // if the user has not made sufficient deposits this epoch to cover the
        // withdrawal amount, we will have to take from their active balance
        if (_amount > _u.pending) {
            // subtract from contract global balances
            // we remove the user's pending balance from epochPendingBalance
            // and the remainder from the current epoch balance
            uint120 fromActive = (_amount - _u.pending).toUint120();
            epochPendingBalance -= _u.pending;
            epochBalances[currentEpochId] -= fromActive;

            // the user's pending balances are cleared
            // and the remainder is subtracted from their active balance
            _u.active -= fromActive;
            _u.pending = 0;

            // otherwise, just subtract the full amt from pending
        } else {
            epochPendingBalance -= _amount;
            _u.pending -= _amount.toUint120();
        }

        // new total balance should be less than total or we would have exited earlier
        if (uint256(_u.pending) + uint256(_u.active) == 0) revert InvalidEmptyBalance(_msgSender(), _amount);

        // update the last time we saw the user and send their tokens back
        _u.epochWritten = currentEpochId;
        stakingToken.safeTransfer(_msgSender(), _amount);
        emit Withdrawn(_msgSender(), currentEpochId, _amount);
    }

    /**
     * @dev if the last time we saw the user was in a past epoch
     *      then we need to move their pending balance to active
     *      and reset the pending balance.
     */
    function _resetPendingIfEpochHasPassed(UserStake storage _u) internal {
        if (_u.epochWritten < currentEpochId) {
            _u.active += _u.pending;
            _u.pending = 0;
        }
    }

    /* ===== Admin Setters ===== */

    /**
     * @notice move to the next epoch. The balance at the end of the previous epoch is rolled forward.
     */
    function activateNextEpoch() external onlyRole(OPERATOR_ROLE) {
        // roll forward the previous balance, adding the pending deposits
        uint256 startingEpochBalance = epochBalances[currentEpochId] + epochPendingBalance;
        epochBalances.push(startingEpochBalance);

        // reset pending and move to the next epoch
        epochPendingBalance = 0;
        currentEpochId++;

        emit NewEpoch(currentEpochId, block.timestamp);
    }

    /// @notice see OpenZeppelin Pauseable
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    /**
     * @notice withdraws all of the deposited staking tokens from the contract
     * @dev    this function can be called even when the contract is paused, but must be called by the admin.
     */
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 transferQty = stakingToken.balanceOf(address(this));
        stakingToken.safeTransfer(_msgSender(), transferQty);
        emit EmergencyWithdraw(_msgSender(), transferQty);
    }
}
