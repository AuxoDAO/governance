// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz/governance/Governor.sol";
import "@oz/governance/extensions/GovernorSettings.sol";
import "@oz/governance/extensions/GovernorCountingSimple.sol";
import "@oz/governance/extensions/GovernorVotes.sol";
import "@oz/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@oz/governance/extensions/GovernorTimelockControl.sol";

contract AuxoGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /**
     * @param _token will be ARV
     * @param _timelock the address of the timelock controller that actually executes transactions
     * @param _initialVotingDelayBlocks number of blocks before voting begins - where users can adjust voting weights
     * @param _initialVotingPeriodBlocks number of blocks that a vote will last, after the delay ends
     * @param _initialMiniumumTokensForProposal number of ARV tokens a user must hold to create a vote
     * @param _initialQuorumPercentage % of total ARV that must vote either FOR or ABSTAIN before a vote can be executed
     * @dev   quorum percentage is in whole percentage points only from 0 - 100%
     */
    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint256 _initialVotingDelayBlocks,
        uint256 _initialVotingPeriodBlocks,
        uint256 _initialMiniumumTokensForProposal,
        uint256 _initialQuorumPercentage
    )
        Governor("AuxoGovernor")
        GovernorSettings(_initialVotingDelayBlocks, _initialVotingPeriodBlocks, _initialMiniumumTokensForProposal)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_initialQuorumPercentage)
        GovernorTimelockControl(_timelock)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
