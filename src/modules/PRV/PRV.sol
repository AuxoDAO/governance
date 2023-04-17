// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable as IERC20} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20PermitUpgradeable as IERC20Permit} from "@oz-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import {IWithdrawalManager} from "@interfaces/IWithdrawalManager.sol";

import {ERC20Upgradeable as ERC20} from "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable as ERC20Permit} from "@oz-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from "@oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IPRVEvents {
    event FeeSet(uint256 fee);
    event FeeBeneficiarySet(address indexed feeBeneficiary);
    event GovernorSet(address indexed governor);
    event Withdrawal(address indexed to, uint256 _amount);
    event WithdrawalManagerSet(address indexed withdrawalManager);
}

/**
 * @title  Auxo Passive Reward Vault (PRV)
 * @author alexintosh, jordaniza
 * @notice PRV has the following key properties:
 *    1) Implements the full ERC20 standard, including optional fields name, symbol and decimals
 *    2) Is upgradeable
 *    3) PRV only be minted in exchange for deposits in AUXO tokens
 *    4) PRV can be burned to withdraw underlying AUXO back in return, a withdrawal manager contract can be defined
 *       to add additional withdrawal logic.
 *    5) Has admin functions managed by a governor address
 *    6) Implements the ERC20Permit standard for offchain approvals.
 */
contract PRV is ERC20, ERC20Permit, ReentrancyGuard, IPRVEvents {
    /// ====== PUBLIC VARIABLES ======

    /// @notice max entry fee from AUXO -> PRV is 10%
    uint256 public constant MAX_FEE = 10 ** 17;

    /// @notice the deposit token required to mint PRV
    address public AUXO;

    /// @notice express as a % of the deposit token and sent to the fee beneficiary.
    uint256 public fee;

    /// @notice entry fees will be sent to this address for each token minted.
    address public feeBeneficiary;

    /// @notice governor retains admin control over the contract.
    address public governor;

    /// @notice external contract to determine if a user is eligible to withdraw.
    address public withdrawalManager;

    /// ====== GAP ======

    /// @dev gap for future storage variables in upgrades with inheritance
    uint256[10] private __gap;

    /// ====== MODIFIERS ======

    modifier onlyGovernance() {
        require(_msgSender() == governor, "!GOVERNOR");
        _;
    }

    /// ====== Initializer ======

    // disable initializers for implementation contracts
    constructor() {
        _disableInitializers();
    }

    /**
     * @param  _auxo address of the AUXO token contract. Cannot be changed after deployment.
     * @param  _fee for withdrawing AUXO back to PRV, can be set to zero to disable fees.
     * @param  _feeBeneficiary address to send fees to - if set to zero, fees will not be charged.
     * @param  _governor address of the governor that has admin control over the contract. Only the governor can change the governor.
     * @param  _withdrawalManager contract to apply additional withdrawal steps. If set to zero, no restrictions will be applied to withdrawals.
     */
    function initialize(address _auxo, uint256 _fee, address _feeBeneficiary, address _governor, address _withdrawalManager) external initializer {
        require(_auxo != address(0), "AUXO:ZERO_ADDR");
        require(_fee <= MAX_FEE, "FEE TOO BIG");
        require(_governor != address(0), "GV:ZERO_ADDR");

        __ReentrancyGuard_init();
        __ERC20_init("Auxo Passive Reward Vault", "PRV");
        __ERC20Permit_init("Auxo Passive Reward Vault");

        AUXO = _auxo;
        fee = _fee;
        feeBeneficiary = _feeBeneficiary;
        governor = _governor;
        withdrawalManager = _withdrawalManager;

        emit FeeSet(_fee);
        emit FeeBeneficiarySet(_feeBeneficiary);
        emit GovernorSet(_governor);
        emit WithdrawalManagerSet(_withdrawalManager);
    }

    /**
     * @notice Allows a user to deposit and stake a specific token (AUXO) to a specified account.
     * @param  _account Ethereum address of the account to deposit and stake the token to.
     * @param  _amount uint256 representing the amount of token to deposit and stake.
     */
    function depositFor(address _account, uint256 _amount) external {
        _deposit(_account, _amount);
    }

    /**
     * @notice Allows a user to deposit using ERC20 permit method.
     * @param  _deadline uint256 representing the deadline for the signature to be valid.
     * @dev   See ERC20-Permit for details on the ECDSA params v,r,s
     */
    function depositForWithSignature(
        address _account,
        uint256 _amount,
        uint256 _deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(AUXO).permit(_msgSender(), address(this), _amount, _deadline, v, r, s);
        _deposit(_account, _amount);
    }

    /**
     * @notice redeems PRV for AUXO. A withdrawal fee may be applied.
     * @dev    if the withdrawal manager is set, it will be called to validate the withdrawal request.
     * @param  _amount of PRV to redeem for AUXO.
     * @param  _data to pass to withdrawal manager for withdrawal validation
     */
    function withdraw(uint256 _amount, bytes memory _data)
        external
        nonReentrant
    {
        // cannot do a zero withdrawal
        require(_amount > 0, "ZERO_AMOUNT");

        if (withdrawalManager != address(0)) {
            // reach out to the manager to check the validity of the withdrawal request
            require(
                IWithdrawalManager(withdrawalManager).verify(_amount, _msgSender(), _data), "BAD_WITHDRAW"
            );
        }

        // the amount is valid, charge the fee and redeem auxo
        uint256 amountMinFee = _chargeFee(_amount);
        _burn(_msgSender(), _amount);
        require(IERC20(AUXO).transfer(_msgSender(), amountMinFee), "TRANSFER_FAILED");

        emit Withdrawal(_msgSender(), _amount);
    }

    /// ====== INTERNAL ======

    /**
     * @dev    calculates the fee to be charged - if the beneficiary is not set, no fee is charged.
     * @return (the amount of auxo after the fee has been deducted, the fee amount deducted)
     */
    function _calcFee(uint256 _amount) internal view returns (uint256, uint256) {
        // don't charge a fee if the beneficiary is not set (or fee is zero)
        if (fee == 0 || feeBeneficiary == address(0)) return (_amount, 0);

        uint256 feeAmount = _amount * fee / (10 ** 18);
        uint256 amountMinFee = _amount - feeAmount;
        return (amountMinFee, feeAmount);
    }

    /**
     *  @dev    calculates the exit fee in auxo and sends to the fee beneficiary.
     *  @return the amount of auxo after the fee has been deducted.
     */
    function _chargeFee(uint256 _amount) internal returns (uint256) {
        (uint256 amountMinFee, uint256 feeAmount) = _calcFee(_amount);

        // _calcFee already checks for the fee beneficiary being set
        // so we don't need to check again here to avoid a zero address transfer error
        if (feeAmount > 0) {
            require(IERC20(AUXO).transfer(feeBeneficiary, feeAmount), "TRANSFER_FAILED");
        }
        return amountMinFee;
    }

    /**
     * @dev takes a deposit, in auxo from the sender and mints PRV
     */
    function _deposit(address _account, uint256 _amount) internal {
        require(IERC20(AUXO).transferFrom(_msgSender(), address(this), _amount), "TRANSFER_FAILED");
        _mint(_account, _amount);
    }

    /// ====== VIEWS ======

    /// @return the amount of AUXO that will be redeemed for the given amount of PRV, minus any exit fees
    function previewWithdraw(uint256 _amount) external view returns (uint256) {
        (uint256 amountPreview,) = _calcFee(_amount);
        return amountPreview;
    }

    /// ====== ADMIN FUNCTIONS ======

    /**
     * @notice This function sets the exit fee for the contract. Only the governor can call this function.
     * @param  _fee uint256 value of the exit fee, bounded at 10%.
     */
    function setFee(uint256 _fee) public onlyGovernance {
        require(_fee <= MAX_FEE, "FEE_TOO_BIG");
        fee = _fee;
        emit FeeSet(_fee);
    }

    /**
     * @notice sets the beneficiary address for the contract's entry fee. Only the governor can call this function.
     * @param  _beneficiary address of the beneficiary for the entry fee.
     */
    function setFeeBeneficiary(address _beneficiary) public onlyGovernance {
        require(_beneficiary != address(0), "ZERO_ADDR");
        feeBeneficiary = _beneficiary;
        emit FeeBeneficiarySet(_beneficiary);
    }

    /**
     * @notice utility function to set fee and beneficiary in one call.
     * @dev    we do not need to check for governance as this is checked in the setters.
     */
    function setFeePolicy(uint256 _fee, address _beneficiary) external {
        setFee(_fee);
        setFeeBeneficiary(_beneficiary);
    }

    /**
     * @notice allows the existing governor to transfer ownership to a new address.
     */
    function setGovernor(address _governor) external onlyGovernance {
        require(_governor != address(0), "ZERO_ADDR");
        governor = _governor;
        emit GovernorSet(_governor);
    }

    /**
     * @notice allows the existing governor to set a withdrawal manager
     *         this is a contract that will verify the validity of a withdrawal and amount
     * @dev    set the manager to address(0) to disable any additional withdrawal logic
     */
    function setWithdrawalManager(address _withdrawalManager) external onlyGovernance {
        withdrawalManager = _withdrawalManager;
        emit WithdrawalManagerSet(_withdrawalManager);
    }
}
