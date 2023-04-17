pragma solidity 0.8.16;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";
import "@forge-std/StdJson.sol";
import "@oz/utils/Strings.sol";

import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";

interface ISharesTimelocker {
    function getLocksOfLength(address account) external view returns (uint256);

    function locksOf(address account, uint256 id) external view returns (uint256, uint32, uint32);

    function migrate(address staker, uint256 lockId) external;

    function canEject(address account, uint256 lockId) external view returns (bool);

    function migrateMany(address staker, uint256[] calldata lockIds) external returns (uint256);
}

contract EjectFreeRiders is Script {
    using stdJson for string;

    address payable oldTimelock = payable(0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45);

    address[] holders;
    address[] ejectable;
    uint256[] ids;

    string adstr;
    string idstr;

    function run() public {
        SharesTimeLock OLD = SharesTimeLock(oldTimelock);

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fork/holders.json");
        string memory file = vm.readFile(path);
        holders = file.readAddressArray("holders");

        for (uint256 i = 0; i < holders.length; i++) {
            address checksumed = address(holders[i]);
            uint256 numLocks = OLD.getLocksOfLength(checksumed);
            for (uint256 j = 0; j < numLocks; j++) {
                if (OLD.canEject(checksumed, j)) {
                    ejectable.push(checksumed);
                    ids.push(j);
                }
            }
        }

        console.log(ejectable.length);
        console.log(ids.length);

        for (uint256 j = 0; j < ejectable.length; j++) {
            adstr = string(abi.encodePacked(adstr, "\"", Strings.toHexString(uint160(ejectable[j]), 20), "\" ,"));
            idstr = string(abi.encodePacked(idstr, Strings.toString(ids[j]), ", "));
        }

        // adstr = string(abi.encodePacked("[", adstr, "]"));
        // adstr = string(abi.encodePacked("[", idstr, "]"));

        console.log(adstr);
        console.log(idstr);
    }
}
