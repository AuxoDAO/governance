# AuxoGovernor
[Git Source](https://github.com/jordaniza/auxo-governance/blob/a1f69a902e4549a031b707b4f353e1bf999b68f6/src/modules/governance/Governor.sol)

**Inherits:**
Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl


## Functions
### constructor

*quorum percentage is in whole percentage points only from 0 - 100%*


```solidity
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
    GovernorTimelockControl(_timelock);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`IVotes`|will be ARV|
|`_timelock`|`TimelockController`|the address of the timelock controller that actually executes transactions|
|`_initialVotingDelayBlocks`|`uint256`|number of blocks before voting begins - where users can adjust voting weights|
|`_initialVotingPeriodBlocks`|`uint256`|number of blocks that a vote will last, after the delay ends|
|`_initialMiniumumTokensForProposal`|`uint256`|number of ARV tokens a user must hold to create a vote|
|`_initialQuorumPercentage`|`uint256`|% of total ARV that must vote either FOR or ABSTAIN before a vote can be executed|


### votingDelay


```solidity
function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256);
```

### votingPeriod


```solidity
function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256);
```

### quorum


```solidity
function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256);
```

### state


```solidity
function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState);
```

### propose


```solidity
function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    public
    override(Governor, IGovernor)
    returns (uint256);
```

### proposalThreshold


```solidity
function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256);
```

### _execute


```solidity
function _execute(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) internal override(Governor, GovernorTimelockControl);
```

### _cancel


```solidity
function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    internal
    override(Governor, GovernorTimelockControl)
    returns (uint256);
```

### _executor


```solidity
function _executor() internal view override(Governor, GovernorTimelockControl) returns (address);
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) public view override(Governor, GovernorTimelockControl) returns (bool);
```

