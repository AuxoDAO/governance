pragma solidity 0.8.16;

import "@forge-std/Test.sol";

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

// mock token
import {MockVotingToken} from "./mocks/Token.sol";

/// @dev lifted from mainnet parameters
address constant MULTISIG_OPS = 0x6458A23B020f489651f2777Bd849ddEd34DfCcd2;
uint256 constant GOV_VOTING_DELAY_BLOCKS = 13140;
uint256 constant GOV_VOTING_PERIOD_BLOCKS = 50000; // 7 days
uint256 constant GOV_MINIMUM_TOKENS_PROPOSAL = 10000 ether;
uint256 constant GOV_QUORUM_PERCENTAGE = 5;
uint32 constant GOV_TIMELOCK_DELAY_SECONDS = 1 days;
address constant GOV_TIMELOCK_EXECUTOR_ADDRESS = address(0);
address constant GOV_TIMELOCK_ADMIN_ADDRESS = MULTISIG_OPS;

/// @dev we assume governance is tested but it's helpful to quickly check how to use within solidity
contract TestGovernance is Test {
    uint internal constant VOTERS = 2;

    AuxoGovernor public governor;
    TimelockController public timelock;
    MockVotingToken public arv;
    address internal deployer;

    address[VOTERS] voters;


    function setUp() public {
        deployer = address(this);
        arv = new MockVotingToken();
        timelock = _deployTimelockController();
        governor = new AuxoGovernor({
            _token: IVotes(address(arv)),
            _timelock: timelock,
            _initialVotingDelayBlocks: GOV_VOTING_DELAY_BLOCKS,
            _initialVotingPeriodBlocks: GOV_VOTING_PERIOD_BLOCKS,
            _initialMiniumumTokensForProposal: GOV_MINIMUM_TOKENS_PROPOSAL,
            _initialQuorumPercentage: GOV_QUORUM_PERCENTAGE
        });

        // update the timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), GOV_TIMELOCK_ADMIN_ADDRESS);
        timelock.grantRole(timelock.CANCELLER_ROLE(), GOV_TIMELOCK_ADMIN_ADDRESS);


        for (uint i = 0; i < VOTERS; i++) {
            address voter = vm.addr(i + 1);
            arv.mint(voter, 100000 ether);
            voters[i] = voter;

            vm.startPrank(voter);
            {
                arv.delegate(voter);
            }
            vm.stopPrank();
        }
    }


    function testCanVoteSucceed() public {
        bytes memory setQuorumNumerator = abi.encodeCall(governor.updateQuorumNumerator, (6));
        governanceVoteAndExecute(setQuorumNumerator, address(governor), "Set governor quorum numerator");
        assertEq(governor.quorumNumerator(), 6);
    }

    function testCanVoteCancel() public {
        bytes memory setQuorumNumerator = abi.encodeCall(governor.updateQuorumNumerator, (6));
        governanceVoteAndCancel(setQuorumNumerator, address(governor), "Set governor quorum numerator");
        assertEq(governor.quorumNumerator(), 5);
    }

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
        for (uint256 i = 0; i < voters.length; i++) {
            address user = voters[i];
            vm.prank(user);
            governor.castVote(proposalHash, uint8(GovernorCountingSimple.VoteType.For));
        }
    }

    function governanceVoteAndCancel(bytes memory _transaction, address _target, string memory _description) internal {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        uint proposal;

        // setup the vote
        (targets, values, calldatas, proposal) =
            proposalArgsSingleCall(_target, 0, _transaction, _description);

        address proposer = voters[0];
        // ensure proposer is self delegated
        arv.delegate(proposer);
        vm.roll(block.number + 1);

        vm.prank(proposer);
        governor.propose(targets, values, calldatas, _description);

        IGovernor.ProposalState proposalState = governor.state(proposal);

        // wait for the initial delay then vote
        vm.roll(block.number + GOV_VOTING_DELAY_BLOCKS + 1);
        allVoteInFavourOf(proposal);

        // wait for the past delay and ensure it succeeded
        vm.roll(block.number + GOV_VOTING_PERIOD_BLOCKS + 1);
        proposalState = governor.state(proposal);
        require(proposalState == IGovernor.ProposalState.Succeeded, "Sim: proposal state is not succeeded");

        // queue and execute - description needs to be unique here
        governor.queue(targets, values, calldatas, keccak256(bytes(_description)));

        bytes32 id = timelock.hashOperationBatch(targets, values, calldatas, 0, keccak256(bytes(_description)));
        vm.prank(voters[1]);
        vm.expectRevert();
        timelock.cancel(id);

        vm.prank(GOV_TIMELOCK_ADMIN_ADDRESS);
        timelock.cancel(id);

        proposalState = governor.state(proposal);
        require(proposalState == IGovernor.ProposalState.Canceled, "Sim: proposal state is not canceled");
    }

    function governanceVoteAndExecute(bytes memory _transaction, address _target, string memory _description) internal {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        uint proposal;

        // setup the vote
        (targets, values, calldatas, proposal) =
            proposalArgsSingleCall(_target, 0, _transaction, _description);

        address proposer = voters[0];
        // ensure proposer is self delegated
        arv.delegate(proposer);
        vm.roll(block.number + 1);

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
}
