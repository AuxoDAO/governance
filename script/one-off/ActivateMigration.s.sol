// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

// foundry imports
import "@forge-std/Script.sol";
import "@forge-std/console.sol";

// libraries - external
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

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
import {MockRewardsToken} from "@mocks/Token.sol";
import {HealthCheck} from "../HealthCheck.sol";

// parameters - update if increasing the version
import "../parameters/v1.sol";
import "../parameters/MainnetAddresses.sol";

// simulation
import {AuxoProtocolSimulation} from "../Simulation.s.sol";

/**
 * @dev performs the additional transactions to begin the Auxo migration.
 *      This cannot be run as a broadcast transaction, as it requires the multisig
 */
contract ActivateMigration is Script, UpgradeDeployer, HealthCheck {
    // deployed contracts
    Upgradoor private up = Upgradoor(UPGRADOOR_MAINNET);
    SharesTimeLock private old = SharesTimeLock(UPGRADOOR_OLD_TIMELOCK);
    Auxo private auxo = Auxo(AUXO_MAINNET);
    TokenLocker private locker = TokenLocker(LOCKER_MAINNET);

    // derive the address from the private key in the .env file - unless MOCK is true
    address private deployer;

    function run() public virtual {
        activateMigration();
    }

    function activateMigration() internal {
        vm.startPrank(MULTISIG_OPS);
        {
            // grant permissions to existing contracts
            auxo.grantRole(auxo.MINTER_ROLE(), address(up));
            locker.setWhitelisted(address(up), true);

            // upgrade the stl and activate the migration
            Proxy proxy = Proxy(payable(address(old)));
            proxy.setImplementation(STIMPL_MAINNET);

            // activate the migration
            old.setMigratoor(address(up));
            old.setMigrationON();
        }
        vm.stopPrank();

        require(upgradoorOkay(up, auxo, PRV(PRV_MAINNET), PRVRouter(PRV_ROUTER_MAINNET), locker), "upgradoor not okay");
        require(sharesTimelockReady(old, address(up)), "shares timelock not ready");
    }
}
