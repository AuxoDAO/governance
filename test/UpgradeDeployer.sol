// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {TimelockController} from "@oz/governance/TimelockController.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {TokenLocker, IERC20MintableBurnable} from "@governance/TokenLocker.sol";
import {ARV} from "@src/ARV.sol";
import {Auxo} from "@src/AUXO.sol";
import {AuxoGovernor, IVotes} from "@governance/Governor.sol";

import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {PRV} from "@prv/PRV.sol";
import {RollStaker} from "@prv/RollStaker.sol";
import {PRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {MerkleDistributor} from "@rewards/MerkleDistributor.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";

/**
 * @dev this helper contract deploys and stores proxies for various upgradeable contracts
 *      additionally it stores the implementation, admin and proxy inside a mapping,
 *      and exposes the keys. This allows us to re-use across different scripts and make
 *      consistent changes to upgradeablity models.
 */
contract UpgradeDeployer {
    /// @dev use these keys to access the proxy data for a particular contract
    string internal constant TOKEN_LOCKER = "tokenLocker";
    string internal constant ROLL_STAKER = "rollStaker";
    string internal constant MERKLE_DISTRIBUTOR = "merkleDistributor";
    string internal constant MERKLE_DISTRIBUTOR_PRV = "merkleDistributorPRV";
    string internal constant PASSIVE_REWARDS_VAULT = "prv";
    string internal constant PRV_VERIFIER = "prvVerifier";
    string internal constant SHARES_TIMELOCK = "sharesTimelock";

    struct ProxyHolder {
        Proxy proxy;
        address implementation;
    }

    mapping(string => ProxyHolder) internal proxies;

    /// @dev best to avoid having randomly generated addresses as the below values
    ///      as can throw weird errors in testing, use this in modifiers
    function isAdmin(address _who) public view returns (bool) {
        return _who == address(this)
            || _isAdminForContract(_who, TOKEN_LOCKER)
            || _isAdminForContract(_who, ROLL_STAKER)
            || _isAdminForContract(_who, SHARES_TIMELOCK)
            || _isAdminForContract(_who, MERKLE_DISTRIBUTOR)
            || _isAdminForContract(_who, MERKLE_DISTRIBUTOR_PRV)
            || _isAdminForContract(_who, PASSIVE_REWARDS_VAULT)
            || _isAdminForContract(_who, PRV_VERIFIER)
            ;
    }

    function _isAdminForContract(address _who, string memory _key) private view returns (bool) {
        return _who == address(proxies[_key].proxy);
    }

    /// @dev deploy and initialize the token locker
    function _deployLocker(
        IERC20 _depositToken,
        IERC20MintableBurnable _veToken,
        uint32 _minLockDuration,
        uint32 _maxLockDuration,
        uint192 _minLockAmount
    ) internal returns (TokenLocker) {
        console2.log("WARNING: You should setup ARV before calling this, and initialize separately");
        TokenLocker locker = _createLocker();
        locker.initialize(_depositToken, _veToken, _minLockDuration, _maxLockDuration, _minLockAmount);
        return locker;
    }

    /**
     * @dev deploy the token locker without initializing the contract
     *      required because veAUXO requires the locker deployed and the locker
     *       initialization requires the veAUXO contract
     */
    function _deployLockerUninitialized() internal returns (TokenLocker) {
        return _createLocker();
    }

    function _createLocker() private returns (TokenLocker) {
        TokenLocker impl = new TokenLocker();
        Proxy proxy = new Proxy();
        proxy.setImplementation(address(impl));
        TokenLocker locker = TokenLocker(address(proxy));
        proxies[TOKEN_LOCKER] = ProxyHolder(proxy, address(impl));
        return locker;
    }

    function _deployRollStaker(address _xAuxo) internal returns (RollStaker) {
        RollStaker impl = new RollStaker();
        Proxy proxy = new Proxy();

        proxy.setImplementation(address(impl));
        RollStaker roll = RollStaker(address(proxy));
        roll.initialize(_xAuxo);

        proxies[ROLL_STAKER] = ProxyHolder(proxy, address(impl));
        return roll;
    }

    function _deployMerkleDistributor() internal returns (MerkleDistributor) {
        MerkleDistributor impl = new MerkleDistributor();
        Proxy proxy = new Proxy();

        proxy.setImplementation(address(impl));
        MerkleDistributor distributor = MerkleDistributor(address(proxy));
        distributor.initialize();

        proxies[MERKLE_DISTRIBUTOR] = ProxyHolder(proxy, address(impl));
        return distributor;
    }

    /// deploy a second distributor for PRV rewards
    function _deployMerkleDistributorPRV() internal returns (MerkleDistributor) {
        MerkleDistributor impl = new MerkleDistributor();
        Proxy proxy = new Proxy();

        proxy.setImplementation(address(impl));
        MerkleDistributor distributor = MerkleDistributor(address(proxy));
        distributor.initialize();

        proxies[MERKLE_DISTRIBUTOR_PRV] = ProxyHolder(proxy, address(impl));
        return distributor;
    }

    function _deploySharesTimelock() public returns (SharesTimeLock) {
        SharesTimeLock impl = new SharesTimeLock();
        Proxy proxy = new Proxy();
        proxy.setImplementation(address(impl));
        proxies[SHARES_TIMELOCK] = ProxyHolder(proxy, address(impl));
        return SharesTimeLock(address(proxy));
    }

    // deploy for testing with address this
    function _deployPRV(address _deposit) internal returns (PRV) {
        return __deployPRV(_deposit, address(this));
    }

    // deploy with a specific governor
    function _deployPRV(address _deposit, address _governor) internal returns (PRV) {
        return __deployPRV(_deposit, _governor);
    }

    function __deployPRV(address _deposit, address _governor) private returns (PRV) {
        Proxy proxy = new Proxy();
        PRV impl = new PRV();
        proxy.setImplementation(address(impl));
        PRV prv = PRV(address(proxy));
        prv.initialize({
            _auxo: _deposit,
            _fee: 0,
            _feeBeneficiary: address(0),
            _governor: _governor,
            _withdrawalManager: address(0)
        });
        proxies[PASSIVE_REWARDS_VAULT] = ProxyHolder(proxy, address(impl));
        return prv;
    }

    function _deployPRVVerifier(address _prv) internal returns (PRVMerkleVerifier) {
        Proxy proxy = new Proxy();
        PRVMerkleVerifier impl = new PRVMerkleVerifier();
        proxy.setImplementation(address(impl));
        PRVMerkleVerifier prvVerifier = PRVMerkleVerifier(address(proxy));
        prvVerifier.initialize(_prv);
        proxies[PRV_VERIFIER] = ProxyHolder(proxy, address(impl));
        return prvVerifier;
    }

    function _collectProxies() internal view returns (ProxyHolder[] memory) {
        ProxyHolder[] memory proxyList = new ProxyHolder[](6);
        proxyList[0] = proxies[TOKEN_LOCKER];
        proxyList[1] = proxies[ROLL_STAKER];
        proxyList[2] = proxies[MERKLE_DISTRIBUTOR];
        proxyList[3] = proxies[MERKLE_DISTRIBUTOR_PRV];
        proxyList[4] = proxies[PASSIVE_REWARDS_VAULT];
        proxyList[5] = proxies[PRV_VERIFIER];
        return proxyList;
    }

    function _transferProxyOwnership(address _to) internal {
        proxies[TOKEN_LOCKER].proxy.setProxyOwner(_to);
        proxies[ROLL_STAKER].proxy.setProxyOwner(_to);
        proxies[MERKLE_DISTRIBUTOR].proxy.setProxyOwner(_to);
        proxies[MERKLE_DISTRIBUTOR_PRV].proxy.setProxyOwner(_to);
        proxies[PASSIVE_REWARDS_VAULT].proxy.setProxyOwner(_to);
        proxies[PRV_VERIFIER].proxy.setProxyOwner(_to);
    }
}
