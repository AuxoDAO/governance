// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {TransparentUpgradeableProxy as Proxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "@oz/governance/TimelockController.sol";

import {TokenLocker, IERC20MintableBurnable} from "@governance/TokenLocker.sol";
import {ARV} from "@src/ARV.sol";
import {Auxo} from "@src/AUXO.sol";
import {AuxoGovernor, IVotes} from "@governance/Governor.sol";

import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {PRV} from "@prv/PRV.sol";
import "@prv/RollStaker.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {MockRewardsToken} from "@mocks/Token.sol";
import {SimpleDecayOracle} from "@oracles/SimpleDecayOracle.sol";

interface PProxy {
    function getProxyOwner() external view returns (address);
    function getImplementation() external view returns (address);
    function setImplementation(address _newImplementation) external;
}

contract DeployOracle is Script {
    /// @dev Requires corresponding pk passed in `forge script`
    address deployer = vm.envAddress("DEPLOYMENT_ACCOUNT");
    SimpleDecayOracle public decayOracle;

    // The main contracts of the Auxo DAO are initialised: veAUXO, AUXO, the timelock and the governance
    function run() public {
        require(deployer != address(0), "DEPLOYMENT_ACCOUNT not set");
        vm.startBroadcast(deployer);
        //Initialize Oracle
        decayOracle = new SimpleDecayOracle(address(0xe0a7e931e2595E69D995462aD4D3DC676030168B));
        console.log("decayOracle", address(decayOracle));
    }
}
