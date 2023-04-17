pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {RollStaker, IRollStaker} from "@prv/RollStaker.sol";
import {Bitfields} from "@prv/bitfield.sol";

import "@test/utils.sol";
import {MockRewardsToken as MockERC20} from "@mocks/Token.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

/// @dev extend rollstaker with some setters for testing isolated components
contract MockRollStaker is RollStaker {
    using SafeCast for uint256;
    /// @dev make more epochs

    function setEpoch(uint8 _epochId) external {
        currentEpochId = _epochId;
        while (epochBalances.length <= currentEpochId) {
            epochBalances.push(0);
        }
    }

    function setEpochBalance(uint8 _id, uint256 _balance) external {
        epochBalances[_id] = _balance;
    }

    function setEpochDelta(uint256 _pending) external {
        epochPendingBalance = _pending;
    }

    function setUserStake(address _user, Bitfields.Bitfield memory _bitfield, uint256 _pending, uint256 _active)
        external
    {
        userStakes[_user].activations = _bitfield;
        userStakes[_user].pending = _pending.toUint120();
        userStakes[_user].active = _active.toUint120();
    }
}

/**
 * @dev Base class for tests that need to deploy a RollStaker
 */
contract RollStakerTestInitializer is Test, IRollStaker, UpgradeDeployer {
    using Bitfields for Bitfields.Bitfield;

    MockRollStaker public roll;
    IERC20 internal mockToken;
    uint256 internal constant MONTH = 30 * 24 * 60 * 60;

    // used to test 'last active'
    Bitfields.Bitfield internal bf;

    // used to test fetching historic epoch balances
    uint8 internal constant MAX_EPOCHS = 250;

    modifier notAdmin(address _who) {
        vm.assume(!isAdmin(_who));
        _;
    }

    function setUp() public virtual {
        MockERC20 token = new MockERC20();
        mockToken = IERC20(address(token));
        token.mint(address(this), type(uint256).max);

        RollStaker _roll = _deployRollStaker(address(token));

        // upgrade to mock for these tests
        MockRollStaker mockImpl = new MockRollStaker();
        proxies[ROLL_STAKER].proxy.setImplementation(address(mockImpl));
        roll = MockRollStaker(address(_roll));
    }
}
