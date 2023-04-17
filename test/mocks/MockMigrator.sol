pragma solidity 0.8.16;

import {ITokenLocker} from "@interfaces/ITokenLocker.sol";

// transferrable rewards token for testing
contract MockMigrator {
    ITokenLocker locker;

    constructor(address _locker) {
        locker = ITokenLocker(_locker);
    }

    function execMigration() external {
        locker.migrate(msg.sender);
    }
}
