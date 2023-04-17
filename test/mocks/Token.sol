pragma solidity 0.8.16;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import "@oz/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@oz/token/ERC20/extensions/ERC20Votes.sol";

// transferrable rewards token for testing
contract MockRewardsToken is ERC20("Reward", "RWD"), ERC20Permit("Reward") {
    function mint(address to, uint256 quantity) external returns (bool) {
        _mint(to, quantity);
        return true;
    }

    function burn(address from, uint256 quantity) external returns (bool) {
        _burn(from, quantity);
        return true;
    }
}


contract MockVotingToken is MockRewardsToken, ERC20Votes {

    // The following functions are overrides required by Solidity.
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
