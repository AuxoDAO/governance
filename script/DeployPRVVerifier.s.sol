pragma solidity 0.8.16;

import "@forge-std/Script.sol";

import {PRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";
import {PProxy} from "@pproxy/PProxy.sol";
import {HealthCheck} from "./HealthCheck.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

// parameters - update if increasing the version
import "./parameters/v1.sol";

contract DeployPRVVerifier is Script, HealthCheck, UpgradeDeployer {
    // mainnet addresses
    address public constant PRV_PROXY =
        0xc72fbD264b40D88E445bcf82663D63FF21e722AF;

    PRVMerkleVerifier public verifier;

    function run() public {
        vm.startBroadcast(0x0Cf1d21431cbE5d3379024fB04996E8F8608A7c0);
        {
            verifier = _deployPRVVerifier(PRV_PROXY);
            if (!verifier.paused()) verifier.pause();
            verifier.transferOwnership(MULTISIG_OPS);
            PProxy(payable(address(verifier))).setProxyOwner(MULTISIG_OPS);
        }
        vm.stopBroadcast();

        require(verifier.paused(), "HealthCheck: Verifier - Paused");
        require(
            verifier.nextWindowIndex() == 0,
            "HealthCheck: Verifier - Window"
        );
        require(
            verifier.owner() == MULTISIG_OPS,
            "HealthCheck: Verifier - Owner"
        );

        console2.log("Verifier", address(verifier));
        // prv.setWithdrawalManager(address(verifier));
    }
}
