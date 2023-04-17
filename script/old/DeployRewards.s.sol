// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {TransparentUpgradeableProxy as Proxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TokenLocker, IERC20MintableBurnable} from "@governance/TokenLocker.sol";
import {ARV} from "@src/ARV.sol";
import {Auxo} from "@src/AUXO.sol";
import {AuxoGovernor, IVotes} from "@governance/Governor.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {PRV} from "@prv/PRV.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {MockRewardsToken} from "@test/mocks/Token.sol";
import {MerkleDistributor, IMerkleDistributorCore} from "@rewards/MerkleDistributor.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

contract DeployRewards is Script, UpgradeDeployer {
    /// @dev Requires corresponding pk passed in `forge script`
    address private deployer = vm.envAddress("DEPLOYMENT_ACCOUNT");

    address public constant REWARDS_ADDRESS = 0x7744116988D2374CE954E3A9dB638c1CC7BB94bA;
    address public constant REWARDS_TOKEN_ADDRESS = 0x8b7e1e0817CAC96bA81c4ce2794D93920FbF35C8;
    uint256 public constant TOTAL_REWARDS = 228242408557385611134;

    /// @notice run as DEPLOYMENT_ACCOUNT from .env file.
    modifier broadcastAsDeployer() {
        require(deployer != address(0), "DEPLOYMENT_ACCOUNT not set");
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    MerkleDistributor private impl;
    Proxy private proxy;
    MerkleDistributor public rewards;
    bytes32[] proof;
    MockRewardsToken rewardsToken;

    // deploy TUP for rewards
    function deployRewardsContract() public {
        rewards = _deployMerkleDistributor();
    }

    function setWindowAndMerkleRoot() public {
        rewardsToken.mint(deployer, TOTAL_REWARDS);
        bytes32 root = bytes32(0x65040f19958dfabc93f786bc303ee26a219bfa87d9e1f37d9577c54dbe744b2d);
        rewardsToken.approve(address(rewards), TOTAL_REWARDS);
        rewards.setWindow(TOTAL_REWARDS, REWARDS_TOKEN_ADDRESS, root, "");
    }

    /// @dev run as the owner of the distributor
    function whiteListDelegate(address _delegate) public {
        rewards.setWhitelisted(_delegate, true);
    }

    /// @dev run as the person due rewards
    function setRewardsDelegate(address _delegate) public {
        console2.log(deployer); // should be different from the contract owner
        rewards.setRewardsDelegate(_delegate);
    }

    function run() public broadcastAsDeployer {
        rewardsToken = MockRewardsToken(REWARDS_TOKEN_ADDRESS);
        rewards = MerkleDistributor(REWARDS_ADDRESS);

        proof.push(bytes32(0xfb3547ca53990c5de34341ae45f7954a6dc0802434cf72d2db26390bfdefb680));
        rewards.claimDelegated(
            IMerkleDistributorCore.Claim({
                windowIndex: 0,
                accountIndex: 1,
                amount: 20749309868853237375,
                token: REWARDS_TOKEN_ADDRESS,
                merkleProof: proof,
                account: 0x4A1c900Ee1042dC2BA405821F0ea13CfBADCAb7B
            })
        );
    }
}
