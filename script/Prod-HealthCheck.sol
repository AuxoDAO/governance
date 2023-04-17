// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

// foundry imports
import "@forge-std/Script.sol";
import "@forge-std/console.sol";

// libraries - external
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

// libraries - DAO owned
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

// auxo
import {Auxo} from "@src/AUXO.sol";

// PRV
import {PRV} from "@prv/PRV.sol";
import {PRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";
import {RollStaker} from "@prv/RollStaker.sol";

// ARV
import {ARV} from "@src/ARV.sol";
import {TokenLocker, IERC20MintableBurnable} from "@governance/TokenLocker.sol";

// governance
import {AuxoGovernor, IVotes} from "@governance/Governor.sol";
import {TimelockController} from "@oz/governance/TimelockController.sol";

// rewards
import {MerkleDistributor} from "@rewards/MerkleDistributor.sol";
import {SimpleDecayOracle} from "@oracles/SimpleDecayOracle.sol";
import {ClaimHelper} from "@rewards/ClaimHelper.sol";

// utilities
import {PRVRouter} from "@prv/PRVRouter.sol";

// migration contracts
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";

// scripting utilities
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";
import "./parameters/v1.sol";

/**
 * @notice validate state variables in the auxo protocol
 * @dev    health checks will revert simulations so can test that, in a complex deployment, nothing has been missed or misconfigured.
 * VERSION: 1
 */
contract ProdHealthCheck is Script {
    address private deployer;

    /// @dev avoid having to pass deployer the whole time and just set once
    function setDeployer(address _deployer) internal {
        deployer = _deployer;
    }

    /**
     * - Minter role correctly owned by the DAO/Timelock
     * - OPS Multisig is the admin
     * - Total Supply is as expected
     */
    function auxoTokenOkay(Auxo _auxo)
        internal
        view
        returns (bool)
    {
        // right ppl have the admin over the auxo token
        require(_auxo.hasRole(_auxo.MINTER_ROLE(), MULTISIG_OPS), "HealthCheck: Auxo - Minter role");
        require(
            _auxo.hasRole(_auxo.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS), "HealthCheck: Auxo - admin"
        );

        // deployer or zero address does not have the above roles
        require(!_auxo.hasRole(_auxo.MINTER_ROLE(), deployer), "HealthCheck: Auxo - Deployer has minter role");
        require(!_auxo.hasRole(_auxo.DEFAULT_ADMIN_ROLE(), deployer), "HealthCheck: Auxo - Deployer has admin role");
        require(!_auxo.hasRole(_auxo.MINTER_ROLE(), address(0)), "HealthCheck: Auxo - Zero address has minter role");
        require(
            !_auxo.hasRole(_auxo.DEFAULT_ADMIN_ROLE(), address(0)), "HealthCheck: Auxo - Zero address has admin role"
        );

        require(_auxo.totalSupply() == 0, "HealthCheck: Auxo - Total supply");

        return true;
    }

    /**
     * Test the ARV state:
     * - locker is the owner of the veAUXO contract
     */
    function arvOkay(ARV arv, TokenLocker _locker) internal view returns (bool) {
        require(arv.tokenLocker() == address(_locker) && arv.tokenLocker() != address(0), "HealthCheck: ARV - Locker");

        return true;
    }

    /**
     * Checks:
     * - The addresses of the deposit token, the ve token, and PRV
     * - The minimum and maximum lock duration and amount
     * - The balance of Auxo in the locker
     * - The lock information for the staking manager
     * - The presence of two whitelisted smart contracts
     * - The absence of migration or emergency unlock
     * - The ownership and access control configuration
     * - The early exit configuration
     */
    function lockerOkay(
        TokenLocker _locker,
        Auxo auxo,
        ARV arv,
        PRV prv,
        address _timelock
    ) internal view returns (bool) {
        require(
            _lockerStateOkay(_locker, auxo, arv, prv),
            "HealthCheck: Locker - State"
        );

        require(
            _lockerRolesOkay(_locker, auxo, arv, prv, _timelock),
            "HealthCheck: Locker - Roles"
        );

        // 2 whitelisted smart contracts: the jailwarden multisig + upgradoor
        require(_locker.whitelisted(LOCKER_WHITELISTED_SMART_CONTRACT), "HealthCheck: Locker - Jailwarden whitelisted");
        require(!_locker.whitelisted(address(0)), "HealthCheck: Locker - Zero address whitelisted");

        return true;
    }

    function _lockerStateOkay(TokenLocker _locker, Auxo auxo, ARV arv, PRV prv)
        private
        view
        returns (bool)
    {
        // basic state variables
        require(address(_locker.depositToken()) == address(auxo), "HealthCheck: Locker - Auxo");
        require(
            address(_locker.veToken()) == address(arv) && address(_locker.veToken()) != address(0),
            "HealthCheck: Locker - ARV"
        );
        require(
            address(_locker.PRV()) == address(prv) && address(_locker.PRV()) != address(0),
            "HealthCheck: Locker - PRV"
        );

        require(_locker.minLockDuration() == LOCKER_MIN_LOCK_DURATION, "HealthCheck: Locker - Min lock duration");
        require(_locker.maxLockDuration() == LOCKER_MAX_LOCK_DURATION, "HealthCheck: Locker - Max lock duration");
        require(_locker.minLockAmount() == LOCKER_MIN_LOCK_AMOUNT, "HealthCheck: Locker - Min lock amount");
        require(_locker.maxRatioArray(36) == 1 ether, "HealthCheck: Locker - Max ratio array");

        // migration/exit not enabled
        require(_locker.emergencyUnlockTriggered() == false, "HealthCheck: Locker - Emergency unlock triggered");
        require(_locker.migrationEnabled() == false, "HealthCheck: Locker - Migration enabled");
        require(_locker.migrator() == address(0), "HealthCheck: Locker - Migrator");

        // early exit properly configured
        require(
            _locker.penaltyBeneficiary() == LOCKER_EARLY_EXIT_PENALTY_BENFICIARY, "HealthCheck: Locker - Beneficiary"
        );
        require(_locker.earlyExitFee() == LOCKER_EARLY_EXIT_PENALTY_PERCENTAGE, "HealthCheck: Locker - Penalty rate");
        return true;
    }

    function _lockerRolesOkay(TokenLocker _locker, Auxo, ARV, PRV, address)
        private
        view
        returns (bool)
    {
        // access control configured
        require(_locker.hasRole(_locker.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS), "HealthCheck: Locker - timelock admin role");

        require(!_locker.hasRole(_locker.DEFAULT_ADMIN_ROLE(), deployer), "HealthCheck: Locker - Deployer Admin role");
        require(
            !_locker.hasRole(_locker.DEFAULT_ADMIN_ROLE(), address(0)), "HealthCheck: Locker - Zero addr Admin role"
        );

        // also check the compounder role
        require(_locker.hasRole(_locker.COMPOUNDER_ROLE(), MULTISIG_OPS), "HealthCheck: Locker - Compounder role");
        return true;
    }

    /**
     * Check the verifier is setup in the basic state. It should be:
     * Linked to PRV
     * Paused
     * Not have an active window
     * An attempt to withdraw should fail
     */
    function verifierOkay(PRVMerkleVerifier _verifier, PRV _prv) internal view returns (bool) {
        require(address(_verifier.PRV()) == address(_prv), "HealthCheck: Verifier - PRV");
        require(_verifier.paused(), "HealthCheck: Verifier - Paused");
        require(_verifier.nextWindowIndex() == 0, "HealthCheck: Verifier - Window");
        require(_verifier.owner() == MULTISIG_OPS, "HealthCheck: Verifier - Owner");

        // attempt to withdraw
        (bool success, ) = address(_prv).staticcall(abi.encodeCall(_prv.withdraw, (1 ether, "")));
        require(!success, "HealthCheck: Verifier - Withdraw");

        return true;
    }

    /**
     * Check proxy ownership has been correctly transferred to the operations multisig
     *
     * This check should be at the end of the script.
     */
    function proxiesOkay(UpgradeDeployer.ProxyHolder[] memory _proxies) internal view returns (bool) {
        for (uint256 i = 0; i < _proxies.length; i++) {
            bool isOwner = Proxy(_proxies[i].proxy).getProxyOwner() == MULTISIG_OPS;
            require(isOwner, "HealthCheck: Proxy - owner");
        }
        return true;
    }

    /**
     * Check the governor state:
     * - The addresses of the token and the timelock
     * - The voting delay and period
     * - The quorum and proposal threshold
     * This can be run as soon as the governor is deployed.
     */
    function govOkay(AuxoGovernor _governor, address _arv, address _timelock) internal view returns (bool) {
        // addresses
        require(address(_governor.token()) == _arv && _arv != address(0), "HealthCheck: Gov - ARV");
        require(address(_governor.timelock()) == _timelock && _timelock != address(0), "HealthCheck: Gov - Timelock");

        // gov params
        require(_governor.votingDelay() == GOV_VOTING_DELAY_BLOCKS, "HealthCheck: Gov - Voting delay");
        require(_governor.votingPeriod() == GOV_VOTING_PERIOD_BLOCKS, "HealthCheck: Gov - Voting period");
        require(_governor.proposalThreshold() == GOV_MINIMUM_TOKENS_PROPOSAL, "HealthCheck: Gov - Quorum votes");
        require(_governor.quorumNumerator() == GOV_QUORUM_PERCENTAGE, "HealthCheck: Gov - Quorum Numerator");

        return true;
    }

    /**
     * Check the timelock state:
     * - Admin role has been set to the admin address (which can be address(0))
     * governor is the only proposer and canceller, meaning the deployer is neither
     * executior is set to executor address, which could be address(0)
     * delay is set to the correct value
     *
     * This can be run as once the timelock is deployed and the original permissions are adjusted
     */
    function timelockOkay(TimelockController _timelock, address _governor) internal view returns (bool) {
        require(
            _timelock.hasRole(_timelock.TIMELOCK_ADMIN_ROLE(), MULTISIG_OPS),
            "HealthCheck: Timelock - Admin role"
        );
        require(
            _timelock.hasRole(_timelock.EXECUTOR_ROLE(), GOV_TIMELOCK_EXECUTOR_ADDRESS),
            "HealthCheck: Timelock - Executor role"
        );
        require(_timelock.hasRole(_timelock.PROPOSER_ROLE(), _governor), "HealthCheck: Timelock - Proposer role");
        require(_timelock.hasRole(_timelock.CANCELLER_ROLE(), _governor), "HealthCheck: Timelock - Canceller role");

        require(_timelock.hasRole(_timelock.PROPOSER_ROLE(), MULTISIG_OPS), "HealthCheck: Timelock - Proposer role");
        require(_timelock.hasRole(_timelock.CANCELLER_ROLE(), MULTISIG_OPS), "HealthCheck: Timelock - Canceller role");

        // zero address nor deployer have the proposer, canceller, admin role
        require(
            !_timelock.hasRole(_timelock.PROPOSER_ROLE(), deployer), "HealthCheck: Timelock - Deployer Proposer role"
        );
        require(
            !_timelock.hasRole(_timelock.CANCELLER_ROLE(), deployer),
            "HealthCheck: Timelock - Deployer Canceller role"
        );
        require(
            !_timelock.hasRole(_timelock.TIMELOCK_ADMIN_ROLE(), deployer),
            "HealthCheck: Timelock - Deployer Admin role"
        );
        require(!_timelock.hasRole(_timelock.PROPOSER_ROLE(), address(0)), "HealthCheck: Timelock - zero addr proposer");
        require(
            !_timelock.hasRole(_timelock.CANCELLER_ROLE(), address(0)), "HealthCheck: Timelock - zero addr canceller"
        );

        // check the min delay
        require(_timelock.getMinDelay() == GOV_TIMELOCK_DELAY_SECONDS, "HealthCheck: Timelock - Delay");

        return true;
    }

    /**
     * Check the PRV state:
     * governor is set to the timelock controller
     * entry fee and beneficiary are initiaized
     * total supply of PRV is the initial mint and is sent to the treasury
     * the verifier is set to the verifier address
     *
     * This can be run as soon as the PRV is setup
     */
    function prvOkay(PRV _prv, Auxo _auxo, address, address _verifier) internal view returns (bool) {
        require(_prv.governor() == MULTISIG_OPS && _prv.governor() != address(0), "HealthCheck: PRV - Governor/Multisig");
        require(_prv.AUXO() == address(_auxo) && _prv.AUXO() != address(0), "HealthCheck: PRV - Auxo");

        require(_prv.fee() == PRV_FEE, "HealthCheck: PRV - Exit fee");
        require(_prv.feeBeneficiary() == PRV_FEE_BENEFICIARY, "HealthCheck: PRV - Beneficiary");

        require(_prv.balanceOf(MULTISIG_TREASURY) == _prv.totalSupply(), "HealthCheck: PRV - Treasury balance");

        require(_prv.withdrawalManager() == _verifier, "HealthCheck: PRV - Manager");

        return true;
    }

    /**
     * Check the RollStaker state:
     * not paused
     * current epochid is zero, epoch balances are a length 1 array == 0, pending balance = 0
     * PRV is set correctly
     * OPERATOR and ADMIN ROLE set to the multisig
     *
     * This can be run as soon as the RollStaker is setup
     */
    function rollOkay(RollStaker _roll, PRV _prv, address _timelock) internal view returns (bool) {
        require(!_roll.paused(), "HealthCheck: Roll - Paused");
        require(_roll.currentEpochId() == 0, "HealthCheck: Roll - Epoch");
        require(_roll.epochBalances(0) == 0, "HealthCheck: Roll - Epoch balances");
        require(_roll.epochPendingBalance() == 0, "HealthCheck: Roll - Pending balance");

        require(address(_roll.stakingToken()) == address(_prv), "HealthCheck: Roll - PRV");
        require(_prv.balanceOf(address(_roll)) == 0, "HealthCheck: Roll - PRV balance");

        require(_roll.hasRole(_roll.OPERATOR_ROLE(), MULTISIG_OPS), "HealthCheck: Roll - Operator role");
        require(!_roll.hasRole(_roll.OPERATOR_ROLE(), deployer), "HealthCheck: Roll - Operator deployer");

        require(_roll.hasRole(_roll.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS), "HealthCheck: Roll - Admin role");
        require(!_roll.hasRole(_roll.DEFAULT_ADMIN_ROLE(), deployer), "HealthCheck: Roll - Admin deployer");
        require(!_roll.hasRole(_roll.DEFAULT_ADMIN_ROLE(), address(0)), "HealthCheck: Roll - Admin zero");

        return true;
    }

    /// @dev check the auxo, prv and rollstaker addresses are as expected
    function routerOkay(PRVRouter _router, PRV _prv, Auxo _auxo, RollStaker _roll) internal view returns (bool) {
        require(_router.AUXO() == address(_auxo) && _router.AUXO() != address(0), "HealthCheck: Router - Auxo");
        require(_router.PRV() == address(_prv) && _router.PRV() != address(0), "HealthCheck: Router - PRV");
        require(_router.Staker() == address(_roll) && _router.Staker() != address(0), "HealthCheck: Router - Roll");

        return true;
    }


    /**
     * @dev check the merkle distributor state:
     * owner is transferred to ops multisig (this contract is not trustless)
     * lockBlock, nextCreatedIndex merkleWindows array all empty
     */
    function merkleDistributorOkay(MerkleDistributor _distributor, bool _enableTesting) internal view returns (bool) {
        require(_distributor.owner() == MULTISIG_OPS, "HealthCheck: MerkleDistributor - Owner");
        require(_distributor.lockBlock() == 0, "HealthCheck: MerkleDistributor - Lock block");

        // if testing is enabled, we will create the distribution, no need to run a health check
        if (_enableTesting) return true;

        require(_distributor.nextCreatedIndex() == 0, "HealthCheck: MerkleDistributor - Next created index");
        MerkleDistributor.Window memory window = _distributor.getWindow(0);
        require(window.merkleRoot == bytes32(0), "HealthCheck: MerkleDistributor - Window root");
        require(window.rewardAmount == 0, "HealthCheck: MerkleDistributor - Window rwd amount");
        require(window.rewardToken == address(0), "HealthCheck: MerkleDistributor - Window rwd");

        return true;
    }

    function claimHelperOkay(ClaimHelper _helper, MerkleDistributor _arv, MerkleDistributor _prv) internal view returns (bool) {

        require(address(_helper.ActiveDistributor()) == address(_arv), "HealthCheck: ClaimHelper - ARV");
        require(address(_helper.PassiveDistributor()) == address(_prv), "HealthCheck: ClaimHelper - PRV");

        require(_arv.whitelistedDelegates(address(_helper)), "HealthCheck: ClaimHelper - ARV whitelist");
        require(_prv.whitelistedDelegates(address(_helper)), "HealthCheck: ClaimHelper - PRV whitelist");

        return true;
    }
}
