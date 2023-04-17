pragma solidity 0.8.16;

import "@forge-std/Script.sol";

import {Upgradoor} from "@bridge/Upgradoor.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {HealthCheck} from "../HealthCheck.sol";

// parameters - update if increasing the version
import "../parameters/v1.sol";

contract DeployUpgradoor is Script, HealthCheck {
    // mainnet addresses
    address public constant PRV_PROXY =
        0xc72fbD264b40D88E445bcf82663D63FF21e722AF;
    address public constant AUXO = 0xff030228a046F640143Dab19be00009606C89B1d;
    address public constant TOKEN_LOCKER_PROXY =
        0x3E70FF09C8f53294FFd389a7fcF7276CC3d92e64;
    address public constant PRV_ROUTER =
        0xEE2b00267188c60aaF1d46EA5c8f4B36006FA6Cc;
    SharesTimeLock public old = SharesTimeLock(UPGRADOOR_OLD_TIMELOCK);

    function run() public {
        vm.startBroadcast(0x0Cf1d21431cbE5d3379024fB04996E8F8608A7c0);

        // deploy the fresh Upgradoor instance
        Upgradoor up = new Upgradoor({
            _oldLock: address(old),
            _auxo: AUXO,
            _dough: address(old.depositToken()),
            _tokenLocker: TOKEN_LOCKER_PROXY,
            _prv: PRV_PROXY,
            _veDOUGH: address(old.rewardsToken()),
            _router: PRV_ROUTER
        });

        vm.stopBroadcast();

        console2.log("Upgradoor", address(up));
    }
}
