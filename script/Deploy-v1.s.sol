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
import {HealthCheck} from "./HealthCheck.sol";
import {JSONReader} from "./one-off/ReadTree.s.sol";

// parameters - update if increasing the version
import "./parameters/v1.sol";

// simulation
import {AuxoProtocolSimulation} from "./Simulation.s.sol";

/**
 * @dev the old sharesTimelock contract needs upgrading to work with the current scripts
 *      this requires the multisig to set the new implementation. This enum defines the different
 *      options you have for running the simulation:
 *
 *      MOCK: deploy fresh contracts in the script for DOUGH, veDOUGH and timelock and etch to the relevant addresses.
 *      This option is totally standalone so will work without any forks.
 *
 *      UPGRADE: perform an upgrade of the sharesTimelock contract in the script. This requires a forked url
 *      in order to pull the old contract data, but doesn't require an external transaction to upgrade the contract.
 *      it cannot, however, be used in a live enviornment (because that requires the gnosis safe)
 *
 *      IMPLEMENTATION: deploy just the implementation contract so we can link it in a separate transaction
 *
 *      ASSUME: no action taken - we assume the DAO has performed the upgrade before running the script.
 *      This is the live setting, but you can of course setup a persistent anvil fork to test it out.
 */
enum SETTING { MOCK, UPGRADE, IMPLEMENTATION, ASSUME }

/**
 * @notice and end-to-end deployer script for the auxo protocol
 * @dev    capitalized values come from the parameters file, adjust as needed
 * VERSION: 1
 */
contract DeployAuxo is Script, UpgradeDeployer, HealthCheck {
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

    // migration contracts
    Upgradoor public up;
    SharesTimeLock public old;

    // WETH address on mainnet
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // derive the address from the private key in the .env file - unless MOCK is true
    address public deployer;

    // Internal variables - inherited contracts can override these to set deployment presets
    SETTING internal SHARESTIMELOCK_SETTING = SETTING.MOCK;

    /// @dev set to true to run the simulation after the deploy - will not work for a live deploy
    bool internal RUN_SIMULATION = false;

   /// @dev set to true to enable Auxo minting and setting up of rewards
    bool internal ENABLE_FRONTEND_TESTING = false;

    // private testing address
    address internal FRONTEND = 0x1A1087Bf077f74fb21fD838a8a25Cf9Fe0818450;

    // how many tokens to mint for the frontend
    uint256 internal FRONTEND_MINT = 1000 ether;

    // inherited contracts can be preset with different deploy settings
    constructor(SETTING _setting, bool _simulation, bool _enableFrontend) {
        SHARESTIMELOCK_SETTING = _setting;
        RUN_SIMULATION = _simulation;
        ENABLE_FRONTEND_TESTING = _enableFrontend;
    }

    /* --------- MODIFIERS -------- */

    modifier broadcastAsDeployer() {
        // not mocking requires a forked url passed because we are broadcasting
        if (SHARESTIMELOCK_SETTING != SETTING.MOCK) {
            require(deployer != address(0), "PRIVATE_KEY not set");
            vm.startBroadcast(deployer);
            _;
            vm.stopBroadcast();
        } else {
            _;
        }
    }

    /* --------- SETUP -------- */

    function setUp() public {
        // let the user know in the logs some of the test settings
        logTestSettings();

        // log deployer and check it is correctly captured in internal health checks
        deployer = SHARESTIMELOCK_SETTING == SETTING.MOCK ? address(this) : vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("Deployer address:", deployer);
        setDeployer(deployer);
    }

    /* --------- MAIN -------- */

    /// @notice this is the main function for forge script, and runs after "setUp"
    function run() public broadcastAsDeployer {

        // log and apply setup for the old timelock contract
        if (SHARESTIMELOCK_SETTING == SETTING.MOCK) setUpMock();
        else if (SHARESTIMELOCK_SETTING == SETTING.UPGRADE) upgradeTimelock();
        else if (SHARESTIMELOCK_SETTING == SETTING.IMPLEMENTATION) deploySharesTimelockImpl();

        // deploy the contracts
        deploy();

        // activate the migration if we are not doing so in another transaction
        if ((SHARESTIMELOCK_SETTING == SETTING.ASSUME || SHARESTIMELOCK_SETTING == SETTING.IMPLEMENTATION) == false) activateMigration(up);

        // optionall run the simulation
        if (RUN_SIMULATION) {
            require(sharesTimelockReady(old, address(up)), "sharesTimelock not ready");
            runSimulation();
        }
    }

    function deploy() internal  {
        auxo = new Auxo();

        if (ENABLE_FRONTEND_TESTING) mintToFrontend();

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
        timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), GOV_TIMELOCK_ADMIN_ADDRESS);

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

        // mint our auxo tokens to the treasury
        if (AUXO_TREASURY_INITIAL_MINT > 0) {
            auxo.mint(MULTISIG_TREASURY, AUXO_TREASURY_INITIAL_MINT);
        }

        // deploy the roll staker and the router to finish the PRV
        roll = _deployRollStaker(address(prv));
        router = new PRVRouter({
            _auxo: address(auxo),
            _prv: address(prv),
            _staker: address(roll)
        });

        // transfer ownership of the roll staker and set up the admins
        roll.grantRole(roll.OPERATOR_ROLE(), MULTISIG_OPS);
        roll.grantRole(roll.DEFAULT_ADMIN_ROLE(), address(timelock));
        roll.renounceRole(roll.OPERATOR_ROLE(), deployer);
        roll.renounceRole(roll.DEFAULT_ADMIN_ROLE(), deployer);

        require(rollOkay(roll, prv, address(timelock)), "HealthCheck: Roll");
        require(routerOkay(router, prv, auxo, roll), "HealthCheck: Router");

        // lastly, connect the timelock
        // NOTE check the deploy/upgrade behaviour is as you expect
        old = SharesTimeLock(UPGRADOOR_OLD_TIMELOCK);
        up = new Upgradoor({
            _oldLock: address(old),
            _auxo: address(auxo),
            _dough: address(old.depositToken()),
            _tokenLocker: address(locker),
            _prv: address(prv),
            _veDOUGH: address(old.rewardsToken()),
            _router: address(router)
        });
        // whitelist in the locker
        locker.setWhitelisted(address(up), true);
        require(upgradoorOkay(up, auxo, prv, router, locker), "HealthCheck: Upgradoor");

        // governance and the upgradoor can mint auxo, but the deployer doesn't need anymore
        // also allow the timelock to change the roles
        auxo.grantRole(auxo.MINTER_ROLE(), address(timelock));
        auxo.grantRole(auxo.MINTER_ROLE(), address(up));
        auxo.grantRole(auxo.DEFAULT_ADMIN_ROLE(), address(timelock));

        auxo.renounceRole(auxo.MINTER_ROLE(), deployer);
        auxo.renounceRole(auxo.DEFAULT_ADMIN_ROLE(), deployer);

        // health check the auxo, ARV and PRV tokens
        require(auxoTokenOkay(auxo, address(timelock), address(up), ENABLE_FRONTEND_TESTING ? FRONTEND_MINT : 0), "HealthCheck: Auxo");
        require(arvOkay(arv, locker), "HealthCheck: ARV");
        require(prvOkay(prv, auxo, address(timelock), address(verifier)), "HealthCheck: PRV");

        // hand over control of the locker to the DAO and run the final health check
        locker.grantRole(locker.DEFAULT_ADMIN_ROLE(), address(timelock));
        locker.grantRole(locker.COMPOUNDER_ROLE(), LOCKER_COMPOUNDER);
        locker.renounceRole(locker.DEFAULT_ADMIN_ROLE(), deployer);
        require(
            lockerOkay(locker, auxo, arv, prv, address(up), address(timelock)),
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
        require(merkleDistributorOkay(distributorARV, ENABLE_FRONTEND_TESTING), "HealthCheck: MerkleDistributorARV");
        require(merkleDistributorOkay(distributorPRV, ENABLE_FRONTEND_TESTING), "HealthCheck: MerkleDistributorPRV");

        // transfer the ownership of the newly deployed contracts to the Multisig and validate
        _transferProxyOwnership(MULTISIG_OPS);
        require(proxiesOkay(_collectProxies()), "HealthCheck: Proxies");

        logContractAddresses();
    }

    /// ----------------- DEPLOYMENT HELPERS -----------------

    /**
     * @dev allows us to run mock tests without instantiating a forked environment
     *      This deploys a mock of the shares timelock and dough/veDough contracts
     *      You can't use this in real environments as it makes use of the etch and prank cheatcodes
     *      which, obviously, don't exist on mainnet
     */
    function setUpMock() internal {
        MockRewardsToken _dough = new MockRewardsToken();
        MockRewardsToken _vedough = new MockRewardsToken();

        // deploy and fetch from struct
        _deploySharesTimelock();
        address impl = proxies[SHARES_TIMELOCK].implementation;
        Proxy proxy = proxies[SHARES_TIMELOCK].proxy;

        // write our contract bytecode to the expected address
        vm.etch(UPGRADOOR_OLD_TIMELOCK, address(proxy).code);
        vm.etch(DOUGH, address(_dough).code);
        vm.etch(VEDOUGH, address(_vedough).code);

        // because we etched, the proxy owner for the implementation will be lost, we need to change this
        vm.prank(address(0));
        Proxy(UPGRADOOR_OLD_TIMELOCK).setProxyOwner(deployer);

        // set the implementation and update the struct
        Proxy(UPGRADOOR_OLD_TIMELOCK).setImplementation(impl);
        proxies[SHARES_TIMELOCK].proxy = Proxy(UPGRADOOR_OLD_TIMELOCK);

        // initialize the _old timelock
        SharesTimeLock(UPGRADOOR_OLD_TIMELOCK).initialize({
            depositToken_: DOUGH,
            rewardsToken_: IERC20MintableBurnable(VEDOUGH),
            minLockDuration_: LOCKER_MIN_LOCK_DURATION,
            maxLockDuration_: LOCKER_MAX_LOCK_DURATION,
            minLockAmount_: LOCKER_MIN_LOCK_AMOUNT
        });
    }

    // uses broadcast to set the implementation of the timelock
    // this will not work in a live environment because the owner is a gnosis safe
    function upgradeTimelock() internal {
        Proxy proxy = Proxy(UPGRADOOR_OLD_TIMELOCK);

        SharesTimeLock impl = new SharesTimeLock();
        address owner = proxy.getProxyOwner();

        vm.broadcast(owner);
        proxy.setImplementation(address(impl));
    }

    function deploySharesTimelockImpl() internal {
        SharesTimeLock impl = new SharesTimeLock();
        proxies[SHARES_TIMELOCK].implementation = address(impl);
    }

    function activateMigration(Upgradoor _up) internal {
        if (SHARESTIMELOCK_SETTING == SETTING.MOCK) {
            vm.startPrank(old.owner());
            {
                old.setMigratoor(address(_up));
                old.setMigrationON();
            }
            vm.stopPrank();
        } else if (SHARESTIMELOCK_SETTING == SETTING.UPGRADE) {
            vm.startBroadcast(old.owner());
            {
                old.setMigratoor(address(_up));
                old.setMigrationON();
            }
            vm.stopBroadcast();
        }
        require(sharesTimelockReady(old, address(_up)), "HealthCheck: SharesTimeLock");
    }

    /// @dev runs the simulation using the entrypoint to pass in the addresses
    function runSimulation() internal {
        // deploy the simulation contract and allow it to run cheatcodes
        AuxoProtocolSimulation simulation = new AuxoProtocolSimulation();
        vm.allowCheatcodes(address(simulation));

        // pass our addresses to the simulation
        simulation.entrypoint(AuxoProtocolSimulation.ContractAddresses({
            auxo: address(auxo),
            prv: address(prv),
            roll: address(roll),
            arv: address(arv),
            locker: address(locker),
            router: address(router),
            oracle: address(oracle),
            distributor: address(distributorARV),
            timelock: address(timelock),
            up: address(up),
            old: address(old),
            governor: address(governor)
        }));
    }

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

    function logTestSettings() internal view {
        if (RUN_SIMULATION) console2.log("Simulation Mode is ON");
        else console2.log("Simulation Mode is OFF, set RUN_SIMULATION=true to run the simulations");

        if(ENABLE_FRONTEND_TESTING) console2.log("Minting 1000 AUXO to frontend, turn this off in production!");

        if (SHARESTIMELOCK_SETTING == SETTING.MOCK) {
            console2.log("Mocking SharesTimeLock Contract");
        }
        else if (SHARESTIMELOCK_SETTING == SETTING.UPGRADE) {
            console2.log("Upgrading SharesTimeLock Contract in Script");
        }
        else if (SHARESTIMELOCK_SETTING == SETTING.ASSUME) {
            console2.log("Not upgrading SharesTimelock: make sure you have upgraded it before continuing");
        }
        else if (SHARESTIMELOCK_SETTING == SETTING.IMPLEMENTATION) {
            console2.log("Deploying an implementation for SharesTimeLock");
        }
        else {
            console2.log("Unknown SharesTimeLock Setting");
        }
    }

    function mintToFrontend() internal {
        auxo.grantRole(auxo.MINTER_ROLE(), address(FRONTEND));
        auxo.mint(FRONTEND, FRONTEND_MINT);
    }

    // logs contract addresses for post deploy scripts
    function logContractAddresses() internal view {
        address stImpl = proxies[SHARES_TIMELOCK].implementation;

        console2.log("--------------------------------");
        console2.log("auxo", address(auxo));
        console2.log("Upgradoor", address(up));
        console2.log("PRV", address(prv));
        console2.log("Router", address(router));
        console2.log("MerkleVerifier", address(verifier));
        console2.log("MerkleDistributor ARV", address(distributorARV));
        console2.log("MerkleDistributor PRV", address(distributorPRV));
        console2.log("Oracle", address(oracle));
        console2.log("Router", address(router));
        console2.log("Governor", address(governor));
        console2.log("SharesTimeLock", address(old));
        console2.log("ClaimHelper", address(helper));
        console2.log("Timelock", address(timelock));
        console2.log("locker", address(locker));
        console2.log("ARV", address(arv));
        console2.log("stImpl", address(stImpl));
        console2.log("RollStaker", address(roll));

        if (ENABLE_FRONTEND_TESTING) {
            console2.log("Balance auxo frontend", auxo.balanceOf(FRONTEND));
            console2.log("Balance prv frontend", prv.balanceOf(FRONTEND));
            console2.log("WETH", address(WETH));
        }

        console2.log("export STIMPL=", address(stImpl));
        console2.log("export UPGRADOOR=", address(up));
        console2.log("--------------------------------");
    }
}
