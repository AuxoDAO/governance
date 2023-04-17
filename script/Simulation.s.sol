// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

// foundry imports
import "@forge-std/Script.sol";
import "@forge-std/console2.sol";

// libraries - external
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IGovernor} from "@oz/governance/IGovernor.sol";
import {GovernorCountingSimple} from "@oz/governance/extensions/GovernorCountingSimple.sol";

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
import {ActivateMigration} from "./one-off/ActivateMigration.s.sol";

import "./parameters/v1.sol";
import "./parameters/MainnetAddresses.sol";


/// @dev number of existing veDOUGH holders to run simulation with
///      more holders gives more a comprehensive simulation but will be slower
///      recommended a minimum of 10
uint constant NUMBER_OF_HOLDERS_TO_LOAD = 5;

/**
 * @notice a simulation script that runs a number of actions on real contracts.
 * @dev    this script can be run as a standalone by calling forge script AuxoProtocolSimulation
 *         or you can invoke it from the `entrypoint` function at the end of a deploy script
 */
contract AuxoProtocolSimulation is Script, ActivateMigration {
    using stdJson for string;

    Auxo public auxo = Auxo(AUXO_MAINNET);

    // PRV
    PRV public prv = PRV(PRV_MAINNET);
    PRVRouter public router = PRVRouter(PRV_ROUTER_MAINNET);
    PRVMerkleVerifier public verifier = PRVMerkleVerifier(PRV_MERKLE_VERIFIER_MAINNET);
    RollStaker public roll = RollStaker(ROLLSTAKER_MAINNET);

    // ARV
    ARV public arv = ARV(ARV_MAINNET);
    TokenLocker public locker = TokenLocker(LOCKER_MAINNET);

    // governance
    AuxoGovernor public governor = AuxoGovernor(payable(GOVERNOR_MAINNET));
    TimelockController public timelock = TimelockController(payable(TIMELOCK_MAINNET));

    // rewards
    MerkleDistributor public distributor = MerkleDistributor(ARV_MERKLE_DISTRIBUTOR_MAINNET);
    MerkleDistributor public prvDistributor = MerkleDistributor(PRV_MERKLE_DISTRIBUTOR_MAINNET);
    SimpleDecayOracle public oracle = SimpleDecayOracle(ORACLE_MAINNET);
    ClaimHelper public claimHelper = ClaimHelper(CLAIM_HELPER_MAINNET);

    // migration contracts
    Upgradoor public up = Upgradoor(UPGRADOOR_MAINNET);
    SharesTimeLock public old = SharesTimeLock(UPGRADOOR_OLD_TIMELOCK); // this should be fixed

    /* INTERNAL VARIABLES */
    address[] private holders;

    // Named Users for Easy Narrative
    address public satoshi;
    address public defiWizard;
    address public passenger;
    address public lsdAddict;
    address public orca;
    address public humpback;
    address public triggerHappyTimmy;
    address public minnow;
    address public theDeveloper;

    /// @dev this function is called by the deploy script to run the simulation
    ///      set NUMBER_OF_HOLDERS_TO_LOAD to the number of veDOUGH holders you want to simulate
    function run() public override {
        console2.log("Beginning Simulation (%d holders)...", NUMBER_OF_HOLDERS_TO_LOAD);
        addContractLabels();
        loadVeDoughHolders(NUMBER_OF_HOLDERS_TO_LOAD);
        activateMigration();
        runMigration();
        cancelVote();
        firstGovernanceVote();
        governanceAdminVotes();
        simulateRewardsPRV();
    }

    /**
     * @dev creates a first vote to mint tokens to the treasury
     */
    function firstGovernanceVote() internal {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        IGovernor.ProposalState proposalState;
        uint256 proposalMintAuxo;
        uint mintQty = 1_000_000 ether;
        uint treasuryBalanceInitial = auxo.balanceOf(MULTISIG_TREASURY);

        /// ---- The First Vote ----- ///
        console2.log("Begin first vote...");

        // The first vote in the DAO is to release 10m tokens to the market in a liqudity event
        // ops is the minter so we mint first to the treasury
        vm.prank(MULTISIG_OPS);
        auxo.mint(address(timelock), mintQty);

        // we setup the vote
        bytes memory transferAuxoToTimelock = abi.encodeCall(auxo.transfer, (MULTISIG_TREASURY, mintQty));
        string memory description = "Mint 10m Auxo to the Multisig";
        (targets, values, calldatas, proposalMintAuxo) =
            proposalArgsSingleCall(address(auxo), 0, transferAuxoToTimelock, description);

        // satoshi creates the vote
        {
            console2.log("Creating First Vote...");

            (bool success, address proposer) = find(holders, canPropose);
            require(success, "Sim: no proposer found");

            vm.prank(proposer);
            governor.propose(targets, values, calldatas, description);

            // let's check the vote looks good:
            proposalState = governor.state(proposalMintAuxo);

            uint256 proposalSnapshot = governor.proposalSnapshot(proposalMintAuxo);
            uint256 proposalDeadline = governor.proposalDeadline(proposalMintAuxo);

            // we test the state is correct and that the start and end date for votes is properly configured
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Pending), "Sim: proposal state is not pending");
            require(proposalSnapshot == block.number + GOV_VOTING_DELAY_BLOCKS, "Sim: proposal snapshot is not correct");
            require(proposalDeadline == block.number + GOV_VOTING_DELAY_BLOCKS + GOV_VOTING_PERIOD_BLOCKS, "Sim: proposal deadline is not correct");
        }

        // A user "passenger" decide to delegate their vote to a super smart "defi wizard"
        {
            console2.log("Vote created, attempting delegation...");
            uint256 wizardVotesBefore = arv.getVotes(defiWizard);
            uint256 passengerVotesBefore = arv.getVotes(passenger);

            vm.prank(passenger);
            arv.delegate(defiWizard);

            // roll the state forward and check the voting power has been transferred
            vm.roll(block.number + 1);
            uint256 wizardVotesAfter = arv.getVotes(defiWizard);
            uint256 passengerVotesAfter = arv.getVotes(passenger);

            require(wizardVotesAfter == wizardVotesBefore + passengerVotesBefore, "Sim: wizard votes are not correct");
            require(passengerVotesAfter == 0, "Sim: passenger votes are not correct");
        }

        {
            console2.log("Delegation Success, beginning vote...");
            vm.roll(block.number + GOV_VOTING_DELAY_BLOCKS + 1);
            proposalState = governor.state(proposalMintAuxo);
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Active), "Sim: proposal state is not active");
        }

        // The users start to cast their votes
        {
            uint256 expectedFor;
            uint256 expectedAgainst;
            for (uint256 i = 0; i < holders.length; i++) {
                address user = holders[i];
                uint8 voteDirection;
                uint256 userVotes = arv.getVotes(user);

                // we want the votes to be in favor, so we check if the last vote
                // would put us over the threshold and if so we vote for otherwise vote against
                if (expectedAgainst + userVotes >= expectedFor) {
                    expectedFor += userVotes;
                    voteDirection = uint8(GovernorCountingSimple.VoteType.For);
                } else {
                    expectedAgainst += userVotes;
                    voteDirection = uint8(GovernorCountingSimple.VoteType.Against);
                }
                vm.prank(user);
                governor.castVote(proposalMintAuxo, voteDirection);
                require(governor.hasVoted(proposalMintAuxo, user), "Sim: user did not vote");
            }

            // we check things add up so far
            (uint256 actualAgainst, uint256 actualFor,) = governor.proposalVotes(proposalMintAuxo);
            require(expectedFor == actualFor, "Sim: expected for does not match actual for");
            require(expectedAgainst == actualAgainst, "Sim: expected against does not match actual against");
            console2.log("For: ", actualFor);
            console2.log("Against: ", actualAgainst);
        }

        // the vote passes and new auxo tokens can be minted to a multisig
        {
            console2.log("Vote over, running checks on timelock and status...");

            vm.roll(block.number + GOV_VOTING_PERIOD_BLOCKS + 1);
            proposalState = governor.state(proposalMintAuxo);
            console2.log(uint(proposalState));
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Succeeded), "Sim: proposal state is not succeeded");

            // defiWizard tries queueing on the governor contract
            // this will not work because of the timelock
            vm.startPrank(defiWizard);
            vm.expectRevert("TimelockController: operation is not ready");
            governor.execute(targets, values, calldatas, keccak256(bytes(description)));

            // she remembers the timelock infrastructure and queues first
            governor.queue(targets, values, calldatas, keccak256(bytes(description)));

            vm.stopPrank();

            proposalState = governor.state(proposalMintAuxo);
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Queued), "Sim: proposal state is not queued");
        }

        // A user "trigger happy timmy, fastest signer in the metaverse"
        // tries to execute the minting tx before the timelock
        {
            console2.log("Proposal queued, attempting to execute before timelock...");
            vm.prank(triggerHappyTimmy);
            vm.expectRevert("TimelockController: operation is not ready");
            governor.execute(targets, values, calldatas, keccak256(bytes(description)));
        }

        // Timmy succeeds after realising he has to wait for the timelock to finish
        {
            console2.log("Proposal queued, attempting to execute after timelock...");
            // NOTE timestamp over blocknumber - :(
            vm.warp(block.timestamp + GOV_TIMELOCK_DELAY_SECONDS + 1);
            vm.prank(triggerHappyTimmy);
            governor.execute(targets, values, calldatas, keccak256(bytes(description)));
            proposalState = governor.state(proposalMintAuxo);
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Executed), "Sim: proposal state is not executed");
        }

        // now we check the multisig has the correct quantity of tokens
        require(auxo.balanceOf(MULTISIG_TREASURY) - treasuryBalanceInitial == mintQty, "Sim: multisig does not have correct amount of tokens");
        console2.log("First Vote Passes!\n");
    }


    function cancelVote() internal {
        console2.log("Begin vote to be cancelled...");
        uint256 proposalToCancel;
        IGovernor.ProposalState proposalState;
        string memory descriptionToCancel;
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;

        (bool success, address proposer) = find(holders, canPropose);
        require(success, "Sim: no proposer found");

        {
            descriptionToCancel = "CANCEL ME";

            (targets, values, calldatas, proposalToCancel) =
                proposalArgsSingleCall(address(auxo), 0, abi.encodeCall(auxo.transfer, (address(0), 1 ether)), descriptionToCancel);

            proposalToCancel = governor.hashProposal(
                targets, values, calldatas, keccak256(bytes(descriptionToCancel))
            );
        }

        {
            console2.log("Proposal cast...");

            vm.prank(proposer);
            governor.propose(targets, values, calldatas, descriptionToCancel);
            // wait for the initial delay then vote
            vm.roll(block.number + GOV_VOTING_DELAY_BLOCKS + 1);
            allVoteInFavourOf(proposalToCancel);

            // check all good so far
            vm.roll(block.number + GOV_VOTING_PERIOD_BLOCKS + 1);
            proposalState = governor.state(proposalToCancel);
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Succeeded), "Sim: proposal did not succeed");

            vm.prank(proposer);
            governor.queue(targets, values, calldatas, keccak256(bytes(descriptionToCancel)));

            proposalState = governor.state(proposalToCancel);
            require(uint256(proposalState) == uint256(IGovernor.ProposalState.Queued), "Sim: proposal state is not queued");

            vm.warp(block.timestamp + 1);

            // prank as ops and try to cancel
            vm.startPrank(MULTISIG_OPS);
            {
                bytes32 id = timelock.hashOperationBatch(targets, values, calldatas, 0, keccak256(bytes(descriptionToCancel)));
                timelock.cancel(id);
                proposalState = governor.state(proposalToCancel);
                require(uint256(proposalState) == uint256(IGovernor.ProposalState.Canceled), "Sim: proposal state is not cancelled");

            }
            vm.stopPrank();

            console2.log("Proposal cancelled!\n");
        }
    }

    function simulateRewardsARV() internal {
        revert("Sim: not implemented yet");
    }

    /**
     @dev test lifecycle of rewards for ARV and PRV
          For ARV: deposit, eject, balances, rewards claim
          For PRV: deposit, withdraw, balances and state
    */
    function simulateRewardsPRV() internal {
        console2.log("Begin rewards simulation...");

        // everyone should be inactive who has deposited
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            // some users deposited to a second address
            address backupAddress = secondAddress(holder);

            uint prvBalance = prv.balanceOf(holder) + prv.balanceOf(backupAddress);
            uint rollBalance = roll.getTotalBalanceForUser(holder) + roll.getTotalBalanceForUser(backupAddress);
            // see the runMigration function
            // if i % 4 == 0 means the holder went all in on ARV, so don't have PRV
            if (i % 4 == 0) {
                require(prvBalance == 0, "Sim: prv balance not zero");
                require(rollBalance == 0, "Sim: roll balance not zero");
            } else {
                // not 100% certain we will have PRV because user might only have 1 lock
                if (rollBalance > 0) {
                    uint pendingBalance = roll.getPendingBalanceForUser(holder) + roll.getPendingBalanceForUser(backupAddress);
                    uint activeBalance = roll.getActiveBalanceForUser(holder) + roll.getActiveBalanceForUser(backupAddress);
                    require(pendingBalance == rollBalance, "Sim: incorrect roll balance");
                    require(activeBalance == 0, "Sim: roll is active");
                    require(!roll.userIsActive(holder) && !roll.userIsActive(backupAddress), "Sim: roll is active");
                }
            }
        }

        // advance to the the next epoch
        vm.prank(ROLLSTAKER_OPERATOR);
        roll.activateNextEpoch();

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            // some users deposited to a second address
            address backupAddress = secondAddress(holder);

            uint prvBalance = prv.balanceOf(holder) + prv.balanceOf(backupAddress);
            uint rollBalance = roll.getTotalBalanceForUser(holder) + roll.getTotalBalanceForUser(backupAddress);
            // see the runMigration function
            // if i % 4 == 0 means the holder went all in on ARV, so don't have PRV
            if (i % 4 == 0) {
                require(prvBalance == 0, "Sim: prv balance not zero");
                require(rollBalance == 0, "Sim: roll balance not zero");
            } else {
                // not 100% certain we will have PRV because user might only have 1 lock
                if (rollBalance > 0) {
                    uint pendingBalance = roll.getPendingBalanceForUser(holder) + roll.getPendingBalanceForUser(backupAddress);
                    uint activeBalance = roll.getActiveBalanceForUser(holder) + roll.getActiveBalanceForUser(backupAddress);
                    require(pendingBalance == 0, "Sim: incorrect roll balance");
                    require(activeBalance == rollBalance, "Sim: roll is active");
                    require(!roll.userIsActive(holder) || !roll.userIsActive(backupAddress), "Sim: roll is active");
                }
            }
        }

        console2.log("Rewards simulation success!\n");
    }

    /**
     * @dev this test covers a series of votes to change governance params
     */
    function governanceAdminVotes() internal {
        console2.log("Governance Admin Votes...");

        console2.log("Governor Quorum Numerator...");
        bytes memory setQuorumNumerator = abi.encodeCall(governor.updateQuorumNumerator, (6));
        governanceVoteAndExecute(setQuorumNumerator, address(governor), "Set governor quorum numerator");
        require(governor.quorumNumerator() == 6, "Sim: governor quorum numerator not set");


        console2.log("Governor token threshold...");
        bytes memory setTokenThreshold = abi.encodeCall(governor.setProposalThreshold, (1000 ether));
        governanceVoteAndExecute(setTokenThreshold, address(governor), "Set governor token threshold");
        require(governor.proposalThreshold() == 1000 ether, "Sim: governor proposer threshold not set");

        console2.log("Governor voting period...");
        bytes memory setVotingPeriod = abi.encodeCall(governor.setVotingPeriod, (2000));
        governanceVoteAndExecute(setVotingPeriod, address(governor), "Set governor voting period");
        require(governor.votingPeriod() == 2000, "Sim: governor voting period not set");
    }

    /// @dev takes N existing holders of veDOUGH and simualtes the migration
    function runMigration() internal {
        // save the vedough contract
        ERC20 vedough = ERC20(address(old.rewardsToken()));

        // pre log
        console2.log("Auxo Supply", auxo.totalSupply());
        console2.log("PRV Supply", prv.totalSupply());
        console2.log("ARV Supply", arv.totalSupply());

        // migrate holders
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            address backupAddress = secondAddress(holder);
            uint256 balance = vedough.balanceOf(holder);

            console2.log("migrating holder: %s, vedough balance: %s", holder, balance);

            vm.startPrank(holder);
            {
                if (i % 4 == 0) {
                    // 1. aggregateAndBoost to veAUXO
                    try up.aggregateAndBoost() {}
                    catch Error(string memory reason) {
                        console2.log("aggregateAndBoost failed: %s", reason);
                    }
                } else if (i % 4 == 1) {
                    // 2. aggregateFirst lock to veAUXO, rest to PRV
                    try up.upgradeSingleLockARV(backupAddress) {}
                    catch Error(string memory reason) {
                        console2.log("upgradeSingleLockVeAuxo failed: %s", reason);
                    }
                    try up.aggregateToPRV() {}
                    catch Error(string memory reason) {
                        console2.log("aggregateToPRV failed: %s", reason);
                    }
                } else if (i % 4 == 2) {
                    // 3. aggregateFirst lock to PRV, rest to ARV
                    try up.upgradeSingleLockPRVAndStake(backupAddress) {}
                    catch Error(string memory reason) {
                        console2.log("upgradeSingleLockPRV failed: %s", reason);
                    }
                    try up.aggregateToARV() {}
                    catch Error(string memory reason) {
                        console2.log("aggregateToARV failed: %s", reason);
                    }
                } else {
                    // 4. all to PRV
                    try up.aggregateToPRVAndStake() {}
                    catch Error(string memory reason) {
                        console2.log("aggregateToPRVAndStake failed: %s", reason);
                    }
                }
                // if the holder has ARV, they should self delegate to activate votes
                if (arv.balanceOf(holder) > 0) arv.delegate(holder);

                // log balances of the new tokens
                {
                    uint vedoughBalanceholder = vedough.balanceOf(holder);
                    uint arvBalanceholder = arv.balanceOf(holder);
                    uint arvBalancebackupAddress = arv.balanceOf(backupAddress);
                    uint prvBalanceholder = prv.balanceOf(holder);
                    uint prvBalancebackupAddress = prv.balanceOf(backupAddress);
                    uint rollBalanceholder = roll.getPendingBalanceForUser(holder);
                    uint rollBalancebackupAddress = roll.getPendingBalanceForUser(backupAddress);
                    uint total = arvBalanceholder
                        + arvBalancebackupAddress
                        + prvBalanceholder
                        + prvBalancebackupAddress
                        + rollBalanceholder
                        + rollBalancebackupAddress
                    ;

                    console2.log("holder: %s, veDOUGH: %s", holder, vedoughBalanceholder);
                    console2.log("holder: %s, ARV: %s", holder, arvBalanceholder);
                    console2.log("backup: %s, ARV: %s", backupAddress, arvBalancebackupAddress);
                    console2.log("holder: %s, PRV: %s", holder, prvBalanceholder);
                    console2.log("backup: %s, PRV: %s", backupAddress, prvBalancebackupAddress);
                    console2.log("rollStakerBalance %s", rollBalanceholder);
                    console2.log("rollStakerBackupBalance %s", rollBalancebackupAddress);
                    console2.log();

                    // it's possible user has expired locks. Ejecting is out of scope of this test at this stage
                    // however if vedough is zero, they MUST have tokens somewhere that are not AUXO
                    if (vedoughBalanceholder == 0) require(total > 0, "Sim: holder has no tokens");
                    require(auxo.balanceOf(holder) == 0, "Sim: holder has auxo");
                }
            }
            vm.stopPrank();
        }

        // post log
        console2.log("Auxo Supply", auxo.totalSupply());
        console2.log("PRV Supply", prv.totalSupply());
        console2.log("ARV Supply", arv.totalSupply());

        // roll to the next block to activate delegation
        vm.roll(block.number + 1);
    }

    /* -------------- HELPERS ---------------- */

    // deterministically creates a new address for a user
    function secondAddress(address _user) internal pure returns (address) {
        bytes32 hashedAddress = keccak256(abi.encodePacked(_user));
        return address(uint160(uint(hashedAddress)));
    }

    // foundry stack traces will label proxies as PProxy
    function addContractLabels() internal {
        vm.label(address(auxo), "AUXO");
        vm.label(address(prv), "PRV");
        vm.label(address(roll), "RollStaker");
        vm.label(address(arv), "ARV");
        vm.label(address(locker), "TokenLocker");
        vm.label(address(governor), "AuxoGovernor");
        vm.label(address(timelock), "TimelockController");
        vm.label(address(distributor), "MerkleDistributor");
        vm.label(address(oracle), "SimpleDecayOracle");
        vm.label(address(router), "LsdRouter");
        vm.label(address(up), "Upgradoor");
        vm.label(address(old), "SharesTimeLock");
    }

    function loadVeDoughHolders(uint n) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fork/holders.json");
        string memory file = vm.readFile(path);
        address[] memory _holders = file.readAddressArray(".holders");
        // we need a proposer. so taking this guy and ensuring they are in the array
        // he has about 1.9m veDOUGH
        address whale = 0x89d2D4934ee4F1f579056418e6aeb136Ee919d65;

        // load the first n holders to the array
        holders.push(whale);
        for (uint256 i = 0; i < n; i++) {
            // no duplicates
            if (_holders[i] != whale) holders.push(_holders[i]);
        }
        // add some labels to existing holders
        _addAddressLabels(n);
    }

    // order matters here: addresses have different post migration holdings.
    function _addAddressLabels(uint n) private {
        passenger = holders[0]; vm.label(passenger, "passenger");
        if (n >= 2) defiWizard = holders[1]; vm.label(defiWizard, "defiWizard");
        if (n >= 3) satoshi = holders[2]; vm.label(satoshi, "satoshi");
        if (n >= 4) lsdAddict = holders[3]; vm.label(lsdAddict, "lsdAddict");
        if (n >= 5) humpback = holders[4]; vm.label(humpback, "humpback");
        if (n >= 6) triggerHappyTimmy = holders[5]; vm.label(triggerHappyTimmy, "triggerHappyTimmy");
        if (n >= 7) orca = holders[6]; vm.label(orca, "orca");
        if (n >= 8) minnow = holders[7]; vm.label(minnow, "minnow");
        if (n >= 9) theDeveloper = holders[8]; vm.label(theDeveloper, "theDeveloper");
    }

    function hasAuxo(address holder) internal view returns (bool) {
        return auxo.balanceOf(holder) > 0;
    }

    function hasPRV(address holder) internal view returns (bool) {
        return prv.balanceOf(holder) > 0;
    }

    function hasARV(address holder) internal view returns (bool) {
        return arv.balanceOf(holder) > 0;
    }

    function canPropose(address holder) internal view returns (bool) {
        return arv.getVotes(holder) > governor.proposalThreshold();
    }

    function hasQuorum(address holder) internal view returns (bool) {
        return arv.getVotes(holder) >= governor.quorum(block.number - 1);
    }

    function canProposeButNotQuorum(address holder) internal view returns (bool) {
        return canPropose(holder) && !hasQuorum(holder);
    }

    // look mama, HOFs
    function find(address[] memory arr, function(address) view returns (bool) func) internal view returns (bool, address) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (func(arr[i])) return (true, arr[i]);
        }
        return (false, address(0));
    }

    /**
     * @dev   assuming the governance function is already simulated, run through a successful vote and execution
     * @param _transaction encoded transaction to be executed
     */
    function governanceVoteAndExecute(bytes memory _transaction, address _target, string memory _description) internal {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        uint proposal;

        // setup the vote
        (targets, values, calldatas, proposal) =
            proposalArgsSingleCall(_target, 0, _transaction, _description);

        // propose the vote
        (bool success, address proposer) = find(holders, canPropose);
        require(success, "Sim: no proposer found");

        // ensure proposer is self delegated
        arv.delegate(proposer);
        vm.roll(block.number + 1);
        console2.log("proposer %s, voting power: %d, threshold %d", proposer, arv.getVotes(proposer), governor.proposalThreshold());

        vm.prank(proposer);
        governor.propose(targets, values, calldatas, _description);

        // wait for the initial delay then vote
        vm.roll(block.number + GOV_VOTING_DELAY_BLOCKS + 1);
        allVoteInFavourOf(proposal);

        // wait for the past delay and ensure it succeeded
        vm.roll(block.number + GOV_VOTING_PERIOD_BLOCKS + 1);
        IGovernor.ProposalState proposalState = governor.state(proposal);
        require(proposalState == IGovernor.ProposalState.Succeeded, "Sim: proposal state is not succeeded");

        // queue and execute - description needs to be unique here
        governor.queue(targets, values, calldatas, keccak256(bytes(_description)));
        vm.warp(block.timestamp + GOV_TIMELOCK_DELAY_SECONDS);
        governor.execute(targets, values, calldatas, keccak256(bytes(_description)));

        // ensure it executed
        proposalState = governor.state(proposal);
        require(proposalState == IGovernor.ProposalState.Executed, "Sim: proposal state is not executed");
    }

    // shortcut method to setup memory addresses of length 1 for a vote
    // also returns the proposal id by hashing the description
    function proposalArgsSingleCall(address _target, uint256 _value, bytes memory _calldata, string memory _description)
        internal
        view
        returns (address[] memory, uint256[] memory, bytes[] memory, uint256)
    {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = _target;
        values[0] = _value;
        calldatas[0] = _calldata;
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, keccak256(bytes(_description)));

        return (targets, values, calldatas, proposalId);
    }

    function allVoteInFavourOf(uint256 proposalHash) internal {
        for (uint256 i = 0; i < holders.length; i++) {
            address user = holders[i];
            vm.prank(user);
            governor.castVote(proposalHash, uint8(GovernorCountingSimple.VoteType.For));
        }
    }

    /* -------------- ENTRYPOINT ---------------- */

    // this struct just allows passing of addresses in calldata without running into stack depth errors
    struct ContractAddresses {
        address auxo;
        address prv;
        address roll;
        address arv;
        address locker;
        address governor;
        address timelock;
        address distributor;
        address oracle;
        address router;
        address up;
        address old;
    }

    /**
     * @dev other scripts can call this entrypoint with real addresses to avoid
     *      having to manually set contract addresses above.
     *      If you are doing so, ensure the script has access to cheatcodes
     *      by calling vm.allowCheatcodes(address(simulation)):
     *      https://book.getfoundry.sh/cheatcodes/allow-cheatcodes
     */
    function entrypoint(ContractAddresses memory addresses) external {
        // destructure the addresses into the storage variables
        auxo = Auxo(addresses.auxo);
        prv = PRV(addresses.prv);
        roll = RollStaker(addresses.roll);
        arv = ARV(addresses.arv);
        locker = TokenLocker(addresses.locker);
        governor = AuxoGovernor(payable(addresses.governor));
        timelock = TimelockController(payable(addresses.timelock));
        distributor = MerkleDistributor(addresses.distributor);
        oracle = SimpleDecayOracle(addresses.oracle);
        router = PRVRouter(addresses.router);
        up = Upgradoor(addresses.up);
        old = SharesTimeLock(addresses.old);

        // now we have set the variables, we can run the simulation
        run();
    }
}
