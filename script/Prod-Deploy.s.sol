// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

// foundry imports
import "@forge-std/Script.sol";
import "@forge-std/console.sol";

// libraries - external
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

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
import {MockRewardsToken} from "@mocks/Token.sol";
import {ProdHealthCheck} from "./Prod-HealthCheck.sol";

// parameters - update if increasing the version
import "./parameters/v1.sol";

// simulation
import {AuxoProtocolSimulation} from "./Simulation.s.sol";

/**
 * @notice and end-to-end deployer script for the auxo protocol
 * @dev    capitalized values come from the parameters file, adjust as needed
 * VERSION: 1
 */
contract DeployAuxoProduction is Script, UpgradeDeployer, ProdHealthCheck {
    Auxo public auxo;

    // PRV
    PRV public prv;
    PRVMerkleVerifier public verifier;
    RollStaker public roll;

    // ARV
    ARV public arv;
    TokenLocker public locker;

    // governance
    AuxoGovernor public governor;
    TimelockController public timelock;

    // rewards
    MerkleDistributor public distributorARV;
    MerkleDistributor public distributorPRV;
    SimpleDecayOracle public oracle;
    ClaimHelper public helper;

    // utilities
    PRVRouter public router;

    // WETH address on mainnet
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // derive the address from the private key in the .env file - unless MOCK is true
    address public deployer;

    // migration contracts
    Upgradoor public up;
    // new implementation
    SharesTimeLock public impl;


    /* --------- MODIFIERS -------- */

    modifier broadcastAsDeployer() {
        // not mocking requires a forked url passed because we are broadcasting
        require(deployer != address(0), "PRIVATE_KEY not set");
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    /* --------- SETUP -------- */

    function setUp() public {
        // log deployer and check it is correctly captured in internal health checks
        deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("Deployer address:", deployer);
        setDeployer(deployer);
    }

    /* --------- MAIN -------- */

    /// @notice this is the main function for forge script, and runs after "setUp"
    function run() public broadcastAsDeployer {

        auxo = new Auxo();
            // governance and the upgradoor can mint auxo, but the deployer doesn't need anymore
            // also allow the timelock to change the roles
            auxo.grantRole(auxo.MINTER_ROLE(), MULTISIG_OPS);
            auxo.grantRole(auxo.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS);

            auxo.renounceRole(auxo.MINTER_ROLE(), deployer);
            auxo.renounceRole(auxo.DEFAULT_ADMIN_ROLE(), deployer);

            // health check the auxo, ARV and PRV tokens
            require(auxoTokenOkay(auxo), "HealthCheck: Auxo");

        // deploy the locker and ARV contract, then link them
        locker = _deployLockerUninitialized();
        arv = new ARV(address(locker));
        locker.initialize(
            auxo,
            IERC20MintableBurnable(address(arv)),
            LOCKER_MIN_LOCK_DURATION,
            LOCKER_MAX_LOCK_DURATION,
            LOCKER_MIN_LOCK_AMOUNT
        );
            locker.setPenalty(LOCKER_EARLY_EXIT_PENALTY_PERCENTAGE);
            locker.setPenaltyBeneficiary(LOCKER_EARLY_EXIT_PENALTY_BENFICIARY);

        // deploy time lock and governor
        // the timelock should be the address used for any actions that require governance
        timelock = _deployTimelockController();
        governor = new AuxoGovernor({
            _token: IVotes(address(arv)),
            _timelock: timelock,
            _initialVotingDelayBlocks: GOV_VOTING_DELAY_BLOCKS,
            _initialVotingPeriodBlocks: GOV_VOTING_PERIOD_BLOCKS,
            _initialMiniumumTokensForProposal: GOV_MINIMUM_TOKENS_PROPOSAL,
            _initialQuorumPercentage: GOV_QUORUM_PERCENTAGE
        });

            // healthcheck on the governor as all its params are set at deployment
            require(govOkay(governor, address(arv), address(timelock)), "HealthCheck: Gov");

            // update the timelock roles
            timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
            timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
            timelock.grantRole(timelock.PROPOSER_ROLE(), MULTISIG_OPS);
            timelock.grantRole(timelock.CANCELLER_ROLE(), MULTISIG_OPS);
            timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), MULTISIG_OPS);

            // revoke the deployer's roles
            timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
            timelock.revokeRole(timelock.CANCELLER_ROLE(), deployer);
            timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer);

            // health check the timelock
            require(timelockOkay(timelock, address(governor)), "HealthCheck: Timelock");

        // deploy the PRV contract with the governor as the deployer
        prv = _deployPRV({_deposit: address(auxo), _governor: deployer});

            prv.setFeePolicy(PRV_FEE, PRV_FEE_BENEFICIARY);

        // deploy the verifier and link it to the PRV contract.
        // the verifier needs to be linked and activated to prevent immediate conversion from PRV to AUXO
        verifier = _deployPRVVerifier({_prv: address(prv)});

            prv.setWithdrawalManager(address(verifier));
            if (!verifier.paused()) verifier.pause();

            // hand over control of the PRV contract to the multisig
            verifier.transferOwnership(MULTISIG_OPS);
            prv.setGovernor(MULTISIG_OPS);

            require(verifierOkay(verifier, prv), "HealthCheck: Verifier");

            // setup whitelisting for the locker and link the prv token
            locker.setWhitelisted(LOCKER_WHITELISTED_SMART_CONTRACT, true);
            locker.setPRV(address(prv));

        // deploy the roll staker and the router to finish the PRV
        roll = _deployRollStaker(address(prv));
        router = new PRVRouter({
            _auxo: address(auxo),
            _prv: address(prv),
            _staker: address(roll)
        });

            // transfer ownership of the roll staker and set up the admins
            roll.grantRole(roll.OPERATOR_ROLE(), MULTISIG_OPS);
            roll.grantRole(roll.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS);
            roll.renounceRole(roll.OPERATOR_ROLE(), deployer);
            roll.renounceRole(roll.DEFAULT_ADMIN_ROLE(), deployer);

            require(rollOkay(roll, prv, address(timelock)), "HealthCheck: Roll");
            require(routerOkay(router, prv, auxo, roll), "HealthCheck: Router");

            // deploy the upgradoor
            up = new Upgradoor({
                _oldLock: UPGRADOOR_OLD_TIMELOCK,
                _auxo: address(auxo),
                _dough: DOUGH,
                _tokenLocker: address(locker),
                _prv: address(prv),
                _veDOUGH: VEDOUGH,
                _router: address(router)
            });

            // deploy the new implementation for stl
            impl = new SharesTimeLock();
            proxies[SHARES_TIMELOCK].implementation = address(impl);

            require(arvOkay(arv, locker), "HealthCheck: ARV");
            require(prvOkay(prv, auxo, address(timelock), address(verifier)), "HealthCheck: PRV");

            // hand over control of the locker to the DAO and run the final health check
            locker.grantRole(locker.DEFAULT_ADMIN_ROLE(), MULTISIG_OPS);
            locker.grantRole(locker.COMPOUNDER_ROLE(), LOCKER_COMPOUNDER);
            locker.renounceRole(locker.DEFAULT_ADMIN_ROLE(), deployer);
            require(
                lockerOkay(locker, auxo, arv, prv, address(timelock)),
                "HealthCheck: Locker"
            );

        // main protocol is now deployed, we now can deploy the auxilliary contracts for rewards
        oracle = new SimpleDecayOracle(address(locker));
        distributorARV = _deployMerkleDistributor();
        distributorPRV = _deployMerkleDistributorPRV();

        // initialize the claim helper
        helper = new ClaimHelper({
            _activeDistributorAddress: address(distributorARV),
            _passiveDistributorAddress: address(distributorPRV)
        });

            // whitelist the claim helper on the distributors
            distributorARV.setWhitelisted(address(helper), true);
            distributorPRV.setWhitelisted(address(helper), true);

            require(claimHelperOkay(helper, distributorARV, distributorPRV), "HealthCheck: ClaimHelper");

            distributorARV.transferOwnership(MULTISIG_OPS);
            distributorPRV.transferOwnership(MULTISIG_OPS);

            // check the distributor, the oracle doesn't need a health check
            require(merkleDistributorOkay(distributorARV, false), "HealthCheck: MerkleDistributorARV");
            require(merkleDistributorOkay(distributorPRV, false), "HealthCheck: MerkleDistributorPRV");

            // transfer the ownership of the newly deployed contracts to the Multisig and validate
            _transferProxyOwnership(MULTISIG_OPS);
            require(proxiesOkay(_collectProxies()), "HealthCheck: Proxies");

        logContractAddresses();
    }

    /// ----------------- DEPLOYMENT HELPERS -----------------

    /// @dev boilerplate to deploy TL Controller, needs transferring roles after gov deployed
    function _deployTimelockController() internal returns (TimelockController) {
        // setup the executors and proposers for the timelock
        // Executor == zero address to allow anyone to execute
        address[] memory executors = new address[](1);
        executors[0] = GOV_TIMELOCK_EXECUTOR_ADDRESS;

        // proposer needs to be changed to the governor once it's deployed
        address[] memory proposers = new address[](1);
        proposers[0] = deployer;

        // deploy the timelock and governor
        return new TimelockController(GOV_TIMELOCK_DELAY_SECONDS, proposers, executors, deployer);
    }

    // logs contract addresses for post deploy scripts
    function logContractAddresses() internal view {
        console2.log("--------------------------------");
        console2.log("auxo", address(auxo));
        console2.log("PRV", address(prv));
        console2.log("Router", address(router));
        console2.log("MerkleVerifier", address(verifier));
        console2.log("MerkleDistributor ARV", address(distributorARV));
        console2.log("MerkleDistributor PRV", address(distributorPRV));
        console2.log("Oracle", address(oracle));
        console2.log("ClaimHelper", address(helper));
        console2.log("Governor", address(governor));
        console2.log("Timelock", address(timelock));
        console2.log("locker", address(locker));
        console2.log("ARV", address(arv));
        console2.log("RollStaker", address(roll));
        console2.log("--------------------------------");
    }
}
