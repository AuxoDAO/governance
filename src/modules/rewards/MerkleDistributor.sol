// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

import {PausableUpgradeable as Pausable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from "@oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MerkleProofUpgradeable as MerkleProof} from "@oz-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable as IERC20} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {DelegationRegistry} from "@rewards/DelegationRegistry.sol";
import {SafeCastUpgradeable as SafeCast} from "@oz-upgradeable/utils/math/SafeCastUpgradeable.sol";

/**
 * @title IMerkleDistributorCore
 * @notice events and structs used in the MerkleDistributor contract
 */

interface IMerkleDistributorCore {
    /**
     * @notice groups reward data for a given account in the window
     * @param windowIndex the current distribution window
     * @param accountIndex autoincrementing from zero and unique for each account.
     * @dev Assigned off chain. Allows for efficiently tracking claimants using a bitmap.
     * @param amount of rewards owed to the user
     * @param token the address of the reward token
     * @param account the address of the claimant
     */
    struct Claim {
        uint256 windowIndex;
        uint256 accountIndex;
        uint256 amount;
        address token;
        bytes32[] merkleProof;
        address account;
    }

    /**
     * @notice A Window is created by a trusted operator for each round of rewards, to be distrubted according to a predefined merkle tree
     * @param merkleRoot the root of the generated merkle tree
     * @param rewardAmount total rewards across all users
     * @param rewardToken the token that will reward users
     * @param ipfsHash IPFS hash of the merkle tree stored as string. Can be used to independently fetch recipient proofs and tree.
     * @dev stored as string to query the ipfs data without needing to reconstruct multihash - go to https://cloudflare-ipfs.com/ipfs/<IPFS-HASH>.
     */
    struct Window {
        bytes32 merkleRoot;
        uint256 rewardAmount;
        address rewardToken;
        string ipfsHash;
    }

    event Claimed(
        address indexed caller,
        uint256 indexed windowIndex,
        address indexed account,
        uint256 accountIndex,
        uint256 rewardAmount,
        address rewardToken
    );

    event ClaimDelegated(
        address indexed delegatee,
        uint256 indexed windowIndex,
        address indexed account,
        uint256 accountIndex,
        uint256 rewardAmount,
        address rewardToken
    );

    /**
     * @notice compressed event data for delegated batch claims.
     * @dev    `accountIndexes` and `windowIndexes` are index aligned and can be used
     *         as a composite key to find the full claim data off-chain.
     * @param  delegate address of the who claimed the rewards
     * @param  token address of the reward token - we only allow one token per call
     * @param  windowIndexes array of window indexes for the claims.
     * @dev    limited to 255 windows which is approx 21 years for 1 month windows
     */
    event ClaimDelegatedMulti(
        address indexed delegate, address indexed token, uint8[] windowIndexes, uint16[] accountIndexes
    );

    event CreatedWindow(
        uint256 indexed windowIndex, address indexed owner, uint256 rewardAmount, address indexed rewardToken
    );
    event WithdrawRewards(address indexed owner, uint256 amount, address indexed token);
    event DeleteWindow(uint256 indexed windowIndex, address indexed owner);
    event LockSet(uint256 indexed lockBlock);
}

/**
 * @title  MerkleDistributor contract.
 * @notice Allows an owner to distribute any reward ERC20 to claimants according to Merkle roots. The owner can specify
 *         multiple Merkle roots distributions with customized reward currencies.
 * @dev    The Merkle trees are not validated in any way, so the system assumes the contract owner behaves honestly.
 */
contract MerkleDistributor is Ownable, Pausable, ReentrancyGuard, DelegationRegistry, IMerkleDistributorCore {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @notice incrementing index for each window
    mapping(uint256 => Window) public merkleWindows;

    /**
     * @notice Track which accounts have claimed for each window index.
     * @dev windowIndex => accountIndex => bitMap. Allows 256 claims to be recorded per word stored.
     */
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;

    /// @notice Index of next created Merkle root.
    uint256 public nextCreatedIndex;

    /// @notice Block until when the distributor is locked
    uint256 public lockBlock;

    /// ===== MODIFIERS ======

    modifier notLocked() {
        require(lockBlock == 0 || lockBlock < block.number, "Distributor is Locked");
        _;
    }

    /// ====== INITIALIZER ======

    /// @dev prevent initializer being called in implementation contract
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer for the contract
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    /// ====== ADMIN FUNCTIONS ======

    /// @notice see openzepplin docs for more info on pausable
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Set merkle root for the next available window index and seed allocations.
     * @param _rewardAmount total rewards across all users
     * @param _rewardToken the token that will reward users
     * @param _merkleRoot for merkle tree generated for this window
     * @param _ipfsHash pointing to the merkle tree
     * @dev   we do not check tokens deposited cover all claims for the window, it is assumed this has been checked by the caller.
     *        Deposits are not segregated by window, so users may start claiming reward tokens still pending for other users in previous windows.
     */
    function setWindow(uint256 _rewardAmount, address _rewardToken, bytes32 _merkleRoot, string memory _ipfsHash)
        external
        onlyOwner
    {
        uint256 currentWindowIndex = nextCreatedIndex;
        nextCreatedIndex += 1;

        merkleWindows[currentWindowIndex] = Window({
            merkleRoot: _merkleRoot,
            ipfsHash: _ipfsHash,
            rewardToken: _rewardToken,
            rewardAmount: _rewardAmount
        });

        // save totals by token and transfer from the sender
        IERC20(_rewardToken).safeTransferFrom(_msgSender(), address(this), _rewardAmount);
        emit CreatedWindow(currentWindowIndex, _msgSender(), _rewardAmount, _rewardToken);
    }

    /**
     * @notice Set block to lock the contract
     * @dev    Callable only by owner.
     * @param  _lock block number until when the contract should be locked
     */
    function setLock(uint256 _lock) external onlyOwner {
        lockBlock = _lock;
        emit LockSet(_lock);
    }

    /**
     * @notice Delete merkle root at window index.
     * @dev    Callable only by owner. Likely to be followed by a withdrawRewards call to clear contract state.
     * @param  _windowIndex merkle root index to delete.
     */
    function deleteWindow(uint256 _windowIndex) external onlyOwner {
        delete merkleWindows[_windowIndex];
        emit DeleteWindow(_windowIndex, _msgSender());
    }

    /**
     * @notice Emergency method that transfers rewards out of the contract if the contract was configured improperly.
     * @dev    Callable only by owner.
     * @param  _rewardToken to withdraw from contract.
     * @param  _amount amount of rewards to withdraw.
     */
    function withdrawRewards(address _rewardToken, uint256 _amount) external onlyOwner {
        IERC20(_rewardToken).safeTransfer(_msgSender(), _amount);
        emit WithdrawRewards(_msgSender(), _amount, _rewardToken);
    }

    /// ====== PUBLIC FUNCTIONS ======

    /**
     * @notice Claim rewards for account, as described by Claim input object.
     * @dev    unrecognised reward tokens in the claim, or those with zero value, will be ignored
     */
    function claim(Claim memory _claim) external notLocked nonReentrant {
        _processClaim(_claim, _claim.account);
        emit Claimed(_msgSender(), _claim.windowIndex, _claim.account, _claim.accountIndex, _claim.amount, _claim.token);
    }

    /**
     * @notice Batch claims to reduce gas versus individual submitting all claims.
     * @dev    Method will fail if any individual claims within the batch would fail,
     *         or if multiple accounts or rewards are being claimed for
     * @param  claims array of claims to claim. Sender must always be the claimant
     */
    function claimMulti(Claim[] memory claims) external notLocked nonReentrant {
        require(claims.length > 0, "No Claims");

        uint256 batchedAmount = 0;
        address rewardToken = claims[0].token;

        for (uint256 i = 0; i < claims.length; i++) {
            Claim memory claimI = claims[i];

            // revert transaction if any claims are not for the sender or if claiming multiple tokens
            require(claimI.account == _msgSender(), "Claimant != Sender");
            require(claimI.token == rewardToken, "Multiple Tokens");

            _verifyAndMarkClaimed(claimI);
            batchedAmount += claimI.amount;

            emit Claimed(
                _msgSender(), claimI.windowIndex, claimI.account, claimI.accountIndex, claimI.amount, claimI.token
                );
        }

        // if all claims total zero, something has gone wrong and better to revert
        require(batchedAmount > 0, "No Rewards");
        IERC20(rewardToken).safeTransfer(_msgSender(), batchedAmount);
    }

    /**
     * @notice Makes multiple claims for users and sends to the delegate. Delegate must be whitelisted first.
     * @dev    All claims must be made for the same reward token
     *         Most efficient is to have contiguous claims in passed array for the same account.
     *         We only check that the sender is whitelisted, we do not check that they are specifically whitelisted
     *         for a given user.
     */
    function claimMultiDelegated(Claim[] memory claims)
        external
        whenNotPaused
        notLocked
        nonReentrant
        onlyWhitelisted
    {
        uint256 claimCount = claims.length;
        require(claimCount > 0, "No Claims");

        uint256 batchedAmount = 0;
        address rewardToken = claims[0].token;

        // instantiate arrays of window indexes and account indexes for emitting event
        uint8[] memory windowIndexes = new uint8[](claimCount); // max 255 windows
        uint16[] memory accountIndexes = new uint16[](claimCount); // max 65k accounts

        for (uint256 i = 0; i < claimCount; i++) {
            Claim memory _claim = claims[i];

            // revert transaction if any claims have different reward tokens than first claim
            // or if the delegate is not whitelisted for the user
            require(_claim.token == rewardToken, "Multiple Tokens");
            require(isRewardsDelegate(_claim.account, _msgSender()), "!whitelisted for user");

            _verifyAndMarkClaimed(_claim);
            batchedAmount += _claim.amount;

            // capture the claim data for emitting event
            windowIndexes[i] = _claim.windowIndex.toUint8();
            accountIndexes[i] = _claim.accountIndex.toUint16();
        }
        require(batchedAmount > 0, "No Rewards");
        IERC20(rewardToken).safeTransfer(_msgSender(), batchedAmount);
        emit ClaimDelegatedMulti(_msgSender(), rewardToken, windowIndexes, accountIndexes);
    }

    function claimDelegated(Claim memory _claim)
        external
        whenNotPaused
        notLocked
        nonReentrant
        onlyWhitelisted
        onlyWhitelistedFor(_claim.account)
    {
        _processClaim(_claim, _msgSender());
        emit ClaimDelegated(
            _msgSender(), _claim.windowIndex, _claim.account, _claim.accountIndex, _claim.amount, _claim.token
            );
    }

    function _processClaim(Claim memory _claim, address _receiver) internal {
        _verifyAndMarkClaimed(_claim);
        // zero rewards are skipped
        require(_claim.amount > 0, "Nothing to Claim");
        IERC20(_claim.token).safeTransfer(_receiver, _claim.amount);
    }

    /**
     * @dev Verify claim is valid and mark it as completed in this contract.
     */
    function _verifyAndMarkClaimed(Claim memory _claim) private {
        // Check claimed proof against merkle window at given index
        require(verifyClaim(_claim), "Invalid Claim");

        // Check the account has not yet claimed for this window.
        require(!isClaimed(_claim.windowIndex, _claim.accountIndex), "Already Claimed for Window");

        // Proof is correct and claim has not occurred yet, mark claimed complete.
        _setClaimed(_claim.windowIndex, _claim.accountIndex);
    }

    /**
     * @dev Mark claim as completed for account with assigned `accountIndex`
     * @param _windowIndex to claim against
     * @param _accountIndex assigned when MerkleTree generated
     */
    function _setClaimed(uint256 _windowIndex, uint256 _accountIndex) private {
        uint256 claimedWordIndex = _accountIndex / 256;
        uint256 claimedBitIndex = _accountIndex % 256;
        claimedBitMap[_windowIndex][claimedWordIndex] =
            claimedBitMap[_windowIndex][claimedWordIndex] | (1 << claimedBitIndex);
    }

    /// ====== VIEWS ======

    /**
     * @notice Returns True if the claim for `accountIndex` has already been completed for the Merkle root at `windowIndex`.
     * @dev    This method will only work as intended if all `accountIndex`'s are unique for a given `windowIndex`
     * @param _windowIndex merkle root to check.
     * @param _accountIndex account index to check within window index.
     * @return True if claim has been executed already, False otherwise.
     */
    function isClaimed(uint256 _windowIndex, uint256 _accountIndex) public view returns (bool) {
        uint256 claimedWordIndex = _accountIndex / 256; // group accounts into 256 bit words
        uint256 claimedBitIndex = _accountIndex % 256; // position in group
        uint256 claimedWord = claimedBitMap[_windowIndex][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex); // shift claimed = 1 to position in word
        return claimedWord & mask == mask; // claimedWord & mask will zero all bits not in the mask
    }

    /**
     * @notice Returns True if leaf described by {account, accountIndex, windowIndex, amount, token} is stored in Merkle root at given window index.
     * @param _claim claim object describing rewards, accountIndex, account, window index, and merkle proof.
     * @dev order matters when hashing the leaf - including for struct parameters. Must align with merkle tree.
     * @return valid True if leaf exists.
     */
    function verifyClaim(Claim memory _claim) public view returns (bool valid) {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        _claim.account,
                        _claim.accountIndex,
                        _claim.windowIndex,
                        _claim.amount,
                        _claim.token
                )
            ))
        );
        return MerkleProof.verify(_claim.merkleProof, merkleWindows[_claim.windowIndex].merkleRoot, leaf);
    }

    /**
     * @notice fetch the window object as a struct
     */
    function getWindow(uint256 _windowIndex) external view returns (Window memory) {
        return merkleWindows[_windowIndex];
    }
}
