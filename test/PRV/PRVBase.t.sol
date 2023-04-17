pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV, IPRVEvents} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";
import {PRVMerkleVerifier, IPRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";

import "../utils.sol";

/// @dev overlay any testing methods on top of base contract
contract MockPRV is PRV {
    // mock method to allow resetting governance
    function resetFeeBeneficiary() external {
        feeBeneficiary = address(0);
    }
}

contract MockPRVMerkleVerifier is PRVMerkleVerifier {
    bool private _shouldPass;

    function setShouldPass(bool _pass) public {
        _shouldPass = _pass;
    }

    function verifyClaim(Claim memory) public view override returns (bool) {
        return _shouldPass;
    }
}

contract PRVTestBase is Test, UpgradeDeployer, IPRVEvents {
    using IsEOA for address;

    TokenLocker internal tokenLocker;
    ARV internal veauxo;
    address public FEE_BENEFICIARY = address(420);

    Auxo internal deposit;
    PRV internal prv;
    PRVMerkleVerifier internal verifier;
    uint32 internal constant AVG_SECONDS_MONTH = 2628000;

    /// skips the merkle verification
    /// @dev capitalised to make it easier to recognise in tests
    modifier USE_MOCK_VERIFIER() {
        MockPRVMerkleVerifier mock = new MockPRVMerkleVerifier();
        proxies[PRV_VERIFIER].proxy.setImplementation(address(mock));

        // proxy: so we need to initialize the should pass to true
        (bool success,) =
            address(proxies[PRV_VERIFIER].proxy).call(abi.encodeWithSignature("setShouldPass(bool)", true));
        require(success, "failed to set mock verifier");
        _;
    }

    /// use the mock prv that has a reset fee beneficiary method
    /// @dev capitalised to make it easier to recognise in tests
    modifier USE_MOCK_PRV() {
        MockPRV mock = new MockPRV();
        proxies[PASSIVE_REWARDS_VAULT].proxy.setImplementation(address(mock));
        _;
    }

    modifier notAdmin(address _who) {
        vm.assume(!isAdmin(_who));
        _;
    }

    function _initializeContracts() internal returns (TokenLocker, ARV, Auxo) {
        // setup auxo and mint the max amount minus the initial mint
        Auxo _deposit = new Auxo();
        _deposit.mint(address(this), type(uint256).max);

        // deploy the locker before setting up veAUXO, then initialize it
        TokenLocker _tokenLocker = _deployLockerUninitialized();
        ARV _veauxo = new ARV(address(_tokenLocker));
        _tokenLocker.initialize(
            _deposit, IERC20MintableBurnable(address(_veauxo)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 1 ether
        );

        // add some labels to make logging more clear with proxies
        vm.label(address(_tokenLocker), "TokenLocker");

        return (_tokenLocker, _veauxo, _deposit);
    }

    function setUp() public virtual {
        (tokenLocker, veauxo, deposit) = _initializeContracts();

        prv = _deployPRV(address(deposit));
        verifier = _deployPRVVerifier(address(prv));
        prv.setWithdrawalManager(address(verifier));
    }
}
