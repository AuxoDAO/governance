// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {MerkleProofUpgradeable as MerkleProof} from "@oz-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {PausableUpgradeable as Pausable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable as IERC20} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {IWithdrawalManager} from "@interfaces/IWithdrawalManager.sol";
import {IPRV} from "@interfaces/IPRV.sol";

interface IPRVMerkleVerifier is IWithdrawalManager {
    /**
     * @notice represents the maximum quantity of PRV that can be redeemed in a given window.
     * @dev    this is computed off chain based on a snapshot at a previous block.
     * @param  windowIndex that the claim belongs to
     * @param  amount of PRV that can be redeemed in the window, multiple claims are allowed but the total cannot exceed this value
     * @param  merkleProof that corresponds to the merkle root stored in the window
     * @param  account that is claiming the PRV
     */
    struct Claim {
        uint256 windowIndex;
        uint256 amount;
        bytes32[] merkleProof;
        address account;
    }

    /**
     * @notice stores a merkle root of claims which are valid between a start and end block.
     * @param  maxAmount the maximum amount of PRV that can be redeemed in the window
     * @param  totalRedeemed the total amount of PRV that has been redeemed in the window
     * @param  startBlock the block number (inclusive) at which the window starts
     * @param  endBlock the block number (exclusive) before which the window ends
     * @param  merkleRoot computed off chain based on a snapshot at a previous block.
     */
    struct Window {
        uint256 maxAmount;
        uint256 totalRedeemed;
        uint32 startBlock;
        uint32 endBlock;
        bytes32 merkleRoot;
    }

    event CreatedWindow(uint256 indexed windowIndex, uint256 maxAmount, uint32 startBlock, uint32 endBlock);
    event DeletedWindow(uint256 indexed windowIndex, address indexed sender);
    event PRVSet(address indexed prv, address indexed auxo);
}

/**
 * @title  Auxo Passive Rewards Vault (PRV) Merkle Verifier
 * @notice restricts PRV -> Auxo redemption based on limits set in a merkle tree
 * @dev    snapshotting PRV holders and restricting redemptions ensures that PRV redemptions (which may be constrained by budget)
 *         are more open to all PRV holders, and less susceptible to frontrunning attacks.
 */
contract PRVMerkleVerifier is Ownable, Pausable, IPRVMerkleVerifier {
    // ========== PUBLIC VARIABLES ==========

    /// @notice Index of most next window to be created
    uint256 public nextWindowIndex;

    /// @notice windowIndex => Window
    mapping(uint256 => Window) public windows;

    // windowIdx => user => amountWithdrawn
    mapping(uint256 => mapping(address => uint256)) private amountWithdrawnFromWindow;

    /// @notice the address of the PRV contract
    address public PRV;

    // ========== PRIVATE VARIABLES ==========

    /// @dev the address of the AUXO token - is fetched from the PRV contract
    address private AUXO;

    /// @dev reserved storage slots for upgrades
    uint256[10] private __gap;

    /// ====== MODIFIERS ========

    /// @notice only the PRV contract can call this function
    modifier onlyPRV() {
        require(_msgSender() == PRV, "!PRV");
        _;
    }

    /**
     * @notice claim must be for the current window, and the window must be open
     * @dev    if the window has been deleted this will revert as block.number > (endBlock = 0)
     */
    modifier windowOpen(bytes calldata _data) {
        uint256 windowIndex = abi.decode(_data, (Claim)).windowIndex;
        require(windowIsOpen(windowIndex), "!WINDOW");
        _;
    }

    /**
     * @notice the passed amount must be less than the max amount for the window
     * @dev    requires that the first window has been set or will revert
     *         if the window has been deleted this will revert if amount > 0
     */
    modifier inBudget(uint256 _amount) {
        Window memory window = windows[nextWindowIndex - 1];
        require(_amount <= (window.maxAmount - window.totalRedeemed), "!BUDGET");
        _;
    }

    /**
     * @notice claim data that is too short may not revert with a meaningful
     *         error message once decoded, this checks explicitly bytes data is min length
     * @dev    this doesn't validate the content of the data, it just ensures it is long enough
     *         that we can decode it without reverting - field validation happens later.
     *         Additionally, data that is too long will not necessarily be possible to decode, so will just revert.
     */
    modifier minLengthClaimData(bytes memory _data) {
        // uint256 windowIndex -> 32 bytes
        // uint256 amount -> 32 bytes
        // address account -> 20 bytes padded to 32 bytes
        // bytes32[] merkleProof -> 32 bytes for length + 64 bytes for array of length 1
        require(_data.length >= 192, "!DATA");
        _;
    }

    /// ====== INITIALIZER ========

    constructor() {
        _disableInitializers();
    }

    /// @param _prv the address of the PRV contract - must implement IPRV as Auxo address will be fetched from it
    function initialize(address _prv) external initializer {
        __Ownable_init();
        __Pausable_init();

        // set the PRV contract and the linked AUXO contract address
        PRV = _prv;
        AUXO = IPRV(PRV).AUXO();
        emit PRVSet(PRV, AUXO);
    }

    /// ======== ADMIN FUNCTIONS ========

    /// @notice see openzeppelin docs for more info on pausable
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice whitelists the process withdrawal function to just the PRV contract
     * @dev    Auxo address will be fetched from the PRV contract and updated
     */
    function setPRV(address _prv) external onlyOwner {
        PRV = _prv;
        AUXO = IPRV(PRV).AUXO();
        emit PRVSet(PRV, AUXO);
    }

    /**
     * @notice instantiates a new window with a given merkle root and max amount, bounded by start and end blocks.
     * @dev    the previous window is deleted - this will disable claims until the new window begins.
     * @param  _maxAmount the maximum amount of PRV that can be redeemed in the window
     * @dev    there must be sufficient AUXO in the PRV contract to cover this amount or the tx will revert
     * @param  _merkleRoot the merkle root of the claims in the window
     * @param  _startBlock the block number at which the window starts
     * @param  _endBlock the block number at which the window ends. Must be greater than _startBlock
     */
    function setWindow(uint256 _maxAmount, bytes32 _merkleRoot, uint32 _startBlock, uint32 _endBlock)
        external
        onlyOwner
    {
        require(_endBlock > _startBlock, "END <= START");
        require(IERC20(AUXO).balanceOf(address(PRV)) >= _maxAmount, "MAX > AUXO");

        // delete the previous window - must check for nextWindowIndex > 0 to avoid underflow
        if (nextWindowIndex > 0) _deleteWindow(nextWindowIndex - 1);

        windows[nextWindowIndex] = Window({
            merkleRoot: _merkleRoot,
            maxAmount: _maxAmount,
            totalRedeemed: 0,
            startBlock: _startBlock,
            endBlock: _endBlock
        });

        nextWindowIndex++;

        emit CreatedWindow(nextWindowIndex - 1, _maxAmount, _startBlock, _endBlock);
    }

    /**
     * @notice Delete window at the specified index if it exists.
     * @dev    Callable only by owner.
     * @param  _windowIndex to delete.
     */
    function deleteWindow(uint256 _windowIndex) public onlyOwner {
        _deleteWindow(_windowIndex);
    }

    /**
     * @dev internal method that avoids ownable modifier.
     *      setWindow ensures that we can rely on an endBlock of zero to only be present if the window has no data
     */
    function _deleteWindow(uint256 _windowIndex) internal {
        if (windows[_windowIndex].endBlock != 0) {
            delete windows[_windowIndex];
            emit DeletedWindow(_windowIndex, _msgSender());
        }
    }

    /// ======== WITHDRAWAL ========

    /**
     * @notice takes a request to redeem some amount of PRV and verifies that it is both valid and within the budget.
     * @dev    we allow repeated claims so long as the total amount claimed is less than the amount in the merkle tree.
     * @param  _amount the amount of PRV to redeem, can be less than the claim amount if the user is only redeeming part of the claim
     * @param  _account the address of the user who is redeeming the PRV
     * @param  _data encoded claim data as bytes.
     * @return true if the claim is valid, false otherwise
     */
    function verify(uint256 _amount, address _account, bytes calldata _data)
        external
        whenNotPaused
        onlyPRV
        minLengthClaimData(_data)
        windowOpen(_data)
        inBudget(_amount)
        returns (bool)
    {
        Claim memory _claim = abi.decode(_data, (Claim));

        // check the claim has correct properties and exists in the merkle tree
        require(verifyClaim(_claim), "!VALID");

        // check the claim is for the correct user - we trust the PRV contract to pass this along
        require(_claim.account == _account, "!CLAIMANT");

        // check the user is not requesting more than remaining, or more than the claim in total
        require(_amount <= availableToWithdrawInClaim(_claim), "CLAIM_TOO_HIGH");

        // update the amount withdrawn
        amountWithdrawnFromWindow[_claim.windowIndex][_claim.account] += _amount;
        windows[_claim.windowIndex].totalRedeemed += _amount;

        return true;
    }

    /// ======== VIEW FUNCTIONS ========

    /**
     * @notice Returns True if leaf described by {account, windowIndex, amount} is stored in Merkle root at given window index.
     * @param _claim claim object describing rewards, accountIndex, account, window index, and merkle proof.
     * @return valid True if leaf exists.
     */
    function verifyClaim(Claim memory _claim) public view virtual returns (bool valid) {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        _claim.account,
                        _claim.windowIndex,
                        _claim.amount
                    )
                )
            )
        );
        return MerkleProof.verify(_claim.merkleProof, windows[_claim.windowIndex].merkleRoot, leaf);
    }

    /// @return the amount of PRV that has been withdrawn by the user for a given window
    function withdrawn(address _account, uint256 _windowIndex) public view returns (uint256) {
        return amountWithdrawnFromWindow[_windowIndex][_account];
    }

    /// @return the amount of PRV that the user can still withdraw for a given window
    function availableToWithdrawInClaim(Claim memory _claim) public view returns (uint256) {
        return _claim.amount - withdrawn(_claim.account, _claim.windowIndex);
    }

    /// @return whether the user can still withdraw for a given window
    function canWithdraw(Claim memory _claim) external view returns (bool) {
        return availableToWithdrawInClaim(_claim) > 0;
    }

    /// @return the amount of PRV that can still be withdrawn in the window
    function budgetRemaining(uint256 _windowIndex) public view returns (uint256) {
        Window memory window = windows[_windowIndex];
        return window.maxAmount - window.totalRedeemed;
    }

    /// @return the window at a given index, encoded as a struct
    function getWindow(uint256 _windowIndex) external view returns (Window memory) {
        return windows[_windowIndex];
    }

    /// @return whether the passed window index is currently accepting withdrawals
    function windowIsOpen(uint256 _windowIndex) public view returns (bool) {
        // at least one window has been set and the passed index is the currently active window
        if (nextWindowIndex == 0 || _windowIndex != nextWindowIndex - 1) return false;
        // if the above is true, check the current block number is within the window bounds
        else return block.number >= windows[_windowIndex].startBlock && block.number < windows[_windowIndex].endBlock;
    }
}
