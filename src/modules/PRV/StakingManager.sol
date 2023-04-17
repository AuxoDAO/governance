// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IVotes} from "@oz/governance/utils/IVotes.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";
import {AccessControlUpgradeable as AccessControl} from "@oz-upgradeable/access/AccessControlUpgradeable.sol";

import "@interfaces/ITokenLocker.sol";

interface IStakingManagerEvents {
    event RepresentativeChanged(address indexed representative);
    event AuxoApproval(address indexed target, uint256 amount);
}

/**
 * @title  StakingManager for ARV
 * @author alexintosh
 * @notice Tokens are staked in perpetuity, no coming back
 * @dev    The StakingManager deposits AUXO and holds ARV on behalf of PRV holders.
 *         Rewards accrued by the StakingManager are distributed to PRV holders.
 *         These rewards are calculated separately.
 *         Anyone can increase the StakingManager's deposit quantity, or boost it's position to the maximum duration
 *         Note: anyone can send AUXO to the staking manager, not necessarily just via. PRV, therefore the staking
 *         manager's locked balance does not necessarily reflect the amount of PRV locked.
 */
contract StakingManager is AccessControl, IStakingManagerEvents {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @dev these variables have no setters so cannot be changed
    ///      they are not marked as immutable due to constraints with upgradeability
    address public AUXO;
    address public ARV;

    /// @notice the locker holds AUXO and mints new ARV to the staking manager
    ITokenLocker public tokenLocker;

    /// ====== PRIVATE VARIABLES ======

    uint8 internal constant MAXIMUM_DEPOSIT_MONTHS = 36;

    /// @dev this provides reserved storage slots for upgrades with inherited contracts
    uint256[50] private __gap;

    /// ====== INITIALIZER ======

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the necessary addresses.
     * @param  _auxo Address of the AUXO ERC20 token that is deposited into the locker
     * @param  _arv Address of the governance token that is held by the staking manager.
     * @param  _tokenLocker Address of the token locker contract that the staking manager interacts with
     * @param  _governor will be given the GOVERNOR_ROLE for this contract
     */
    function initialize(address _auxo, address _arv, address _tokenLocker, address _governor) external initializer {
        AUXO = _auxo;
        ARV = _arv;
        tokenLocker = ITokenLocker(_tokenLocker);

        // Setting initial state
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _governor);

        // slither-disable-next-line unused-return
        IERC20(AUXO).approve(_tokenLocker, type(uint256).max);
        emit AuxoApproval(_tokenLocker, type(uint256).max);
    }

    /// ===========================
    /// ===== ADMIN FUNCTIONS =====
    /// ===========================

    /**
     * @notice governor relinquishes their role and transfers it to another address
     */
    function transferGovernance(address _governor) external onlyRole(GOVERNOR_ROLE) {
        _grantRole(GOVERNOR_ROLE, _governor);
        _revokeRole(GOVERNOR_ROLE, _msgSender());
    }

    /// ============================
    /// ===== PUBLIC FUNCTIONS =====
    /// ============================

    function approveAuxo() external {
        IERC20(AUXO).approve(address(tokenLocker), 0);
        IERC20(AUXO).approve(address(tokenLocker), type(uint256).max);
        emit AuxoApproval(address(tokenLocker), type(uint256).max);
    }

    /**
     * @notice creates the initial deposit for the staking manager.
     * @dev    this function can only be called once and will revert otherwise.
     *         we would expect to call it as part of deployment. Use increase() otherwise.
     */
    function stake() external {
        uint256 balance = IERC20(AUXO).balanceOf(address(this));
        tokenLocker.depositByMonths(balance.toUint192(), MAXIMUM_DEPOSIT_MONTHS, address(this));
    }

    /**
     * @notice deposits any AUXO in this contract that is not currently staked, into active vault.
     */
    function increase() external {
        uint256 balance = IERC20(AUXO).balanceOf(address(this));
        tokenLocker.increaseAmount(balance.toUint192());
    }

    /**
     * @notice boosts the staked balance of the stakingManager to the full length
     * @dev    this prevents other users ejecting the staking manager.
     */
    function boostToMax() external {
        tokenLocker.boostToMax();
    }
}
