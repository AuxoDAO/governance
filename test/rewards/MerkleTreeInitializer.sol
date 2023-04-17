// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import "@forge-std/StdJson.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IMerkleDistributorCore, MerkleDistributor} from "@rewards/MerkleDistributor.sol";
import {DelegationRegistry} from "@rewards/DelegationRegistry.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

contract MockERC20 is ERC20 {
    uint8 __decimals;

    constructor(uint8 _decimals) ERC20("Test", "Test") {
        __decimals = _decimals;
    }

    function mint() public {
        _mint(msg.sender, type(uint256).max);
    }

    function decimals() public view override returns (uint8) {
        return __decimals;
    }
}

/**
 * @dev hardcoded values from the merkle trees.
 *      Ideally we would read from the tree using foundry utils
 *      but difficult to do with the JSON keys being dynamic addresses.
 */
contract MerkleTreeInitializer is IMerkleDistributorCore {
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address claimant3 = 0x14B6B961a0b80558E92795Dd2515eB8A650Cb081;
    address claimant9 = 0x9dB96AdB915e51f61e2495AFb026bB9E887A364B;

    // sample claimant on first window
    bytes32[] merkleProofClaimant3Window0 = new bytes32[](3);

    // second claimant, first window
    bytes32[] merkleProofClaimant9Window0 = new bytes32[](3);

    // same claimant, second window
    bytes32[] merkleProofClaimant9Window1 = new bytes32[](4);

    // dai claim
    bytes32[] merkleProofClaimant3Window2 = new bytes32[](4);

    // roots
    bytes32 merkleRootWindow0 = bytes32(0xc50e4af2651ff3ff624eba54ee9ccb0eb89cd03dff104bfc017f13f0f110d4d2);
    bytes32 merkleRootWindow1 = bytes32(0xb13bf104b1a9b89944759cfce3d7c785a55bca18b72963ad937e5becef811ad4);
    // dai window
    bytes32 merkleRootWindow2 = bytes32(0x154f11db06e7ea1be0f65d4c0330da2e7ede160e6e9d93dd0ccd361bb126f9f0);

    function _initProofs() internal {
        merkleProofClaimant3Window0[0] = bytes32(0xecd5b7fa64c6057bb1224957e64196e827ea625a3364a3401e588d97889642ba);
        merkleProofClaimant3Window0[1] = bytes32(0x819a114c3c84d773e18d73dd97da8685ea2217eee81541b8198099029d3be620);
        merkleProofClaimant3Window0[2] = bytes32(0x34e4349bee09a19841b0078b3c0035c7d07506129e7ca29eb80fdf0f3d89ffdb);

        merkleProofClaimant9Window0[0] = bytes32(0xeb48643cb21d61798a82800941e7252ba15e4cf2612d8de86d42ba23aef13693);
        merkleProofClaimant9Window0[1] = bytes32(0x1b8f651c9ad6c27944e50ff903a27da4cff625f4c98b67507369be3ef3bac30c);
        merkleProofClaimant9Window0[2] = bytes32(0x39c75036bfa0d5adc7cbca16f742803c9b8fa89f4e1c2a6cbc09d73ed92da50c);

        merkleProofClaimant9Window1[0] = bytes32(0x55d634738ad4eccfeb66caa92285cfa5e9d0635cb7ec6c519ab5117dfb86462d);
        merkleProofClaimant9Window1[1] = bytes32(0xc76f67485f4bdb2440b7675031952ad22487119a936bc6216960c3817daeccca);
        merkleProofClaimant9Window1[2] = bytes32(0x76c1acc4f1a3f713819c1c372981bc9f8c18e56eb0e97e7c0b40575a8e8c99f1);
        merkleProofClaimant9Window1[3] = bytes32(0x97c03dcfd7e48325590131e8e7ebfa132378152e6007840786127cf2a21f86cd);

        merkleProofClaimant3Window2[0] = bytes32(0x49d3272353c2a974495424062fd38c3a2e2a19c8e42f1a152c466a095bd18381);
        merkleProofClaimant3Window2[1] = bytes32(0xf125444d80dcc867432b01781325da76eabaeb18d75a0b568d82e05c00fa4c4b);
        merkleProofClaimant3Window2[2] = bytes32(0xf01c0d8ac3cd898a612b3ab965412a709678b4f049b9b070bdaaa02b82433e0e);
        merkleProofClaimant3Window2[3] = bytes32(0xb1ec30cd2ee0cdaddaf82c9a13b9665c74b182bd128793176890ebcc20cb5a23);
    }

    function _getMerkleClaims()
        internal
        view
        returns (
            Claim memory claimA9W0,
            Claim memory claimA9W1,
            Claim memory claimA3W0,
            uint256 totalRewards0,
            uint256 totalRewards1
        )
    {
        // total rewards for each window
        totalRewards0 = 497883000000000000000000;
        totalRewards1 = 566384000000000000000000;

        // per user rewards
        uint256 rewardsA3W0 = 34354000000000000000000;
        uint256 rewardsA9W0 = 7357000000000000000000;
        uint256 rewardsA9W1 = 74155000000000000000000;

        claimA3W0 = Claim({
            windowIndex: 0,
            accountIndex: 3,
            amount: rewardsA3W0,
            token: WETH,
            merkleProof: merkleProofClaimant3Window0,
            account: claimant3
        });

        claimA9W0 = Claim({
            windowIndex: 0,
            accountIndex: 9,
            amount: rewardsA9W0,
            token: WETH,
            merkleProof: merkleProofClaimant9Window0,
            account: claimant9
        });

        claimA9W1 = Claim({
            windowIndex: 1,
            accountIndex: 9,
            amount: rewardsA9W1,
            token: WETH,
            merkleProof: merkleProofClaimant9Window1,
            account: claimant9
        });

        return (claimA9W0, claimA9W1, claimA3W0, totalRewards0, totalRewards1);
    }

    function _getDAIClaim() internal view returns (Claim memory, uint totalDAIRewards) {
        totalDAIRewards = 528744000000000000000000;

        return (
            Claim({
                windowIndex: 2,
                accountIndex: 3,
                amount: 85310000000000000000000,
                token: DAI,
                merkleProof: merkleProofClaimant3Window2,
                account: claimant3
            }),
            totalDAIRewards
        );
    }
}



contract MerkleRewardsTestBase is
    Test,
    IMerkleDistributorCore,
    MerkleTreeInitializer,
    DelegationRegistry,
    UpgradeDeployer
{
    MerkleDistributor public distributor;

    MockERC20 internal token1;
    MockERC20 internal dai;

    modifier notAdmin(address _who) {
        vm.assume(!isAdmin(_who));
        _;
    }

    function setUp() public virtual {
        distributor = _deployMerkleDistributor();
        _initProofs();
        token1 = new MockERC20(18);
        dai = new MockERC20(18);
    }

    /// @dev overwrite an existing address with the code for our mock token
    function _prepareRewardToken() internal returns (MockERC20) {
        MockERC20 rewardToken = new MockERC20(18);
        rewardToken.mint();
        rewardToken.approve(address(distributor), type(uint256).max);
        return rewardToken;
    }

    function _initializeClaims() internal returns (Claim memory, Claim memory, Claim memory) {
        (
            Claim memory claimA9W0,
            Claim memory claimA9W1,
            Claim memory claimA3W0,
            uint256 totalRewards0,
            uint256 totalRewards1
        ) = _getMerkleClaims();

        // etch writes existing bytecode to a given address.
        vm.etch(WETH, address(token1).code);
        MockERC20(WETH).approve(address(distributor), type(uint256).max);
        MockERC20(WETH).mint();

        distributor.setWindow(totalRewards0, WETH, merkleRootWindow0, "");
        distributor.setWindow(totalRewards1, WETH, merkleRootWindow1, "");

        return (claimA9W0, claimA9W1, claimA3W0);
    }

    // this function was added later so can be initialized separately
    function _initializeDAIClaim() internal returns (Claim memory) {
        (Claim memory claimA3W2, uint256 totalDAIRewards) = _getDAIClaim();

        vm.etch(DAI, address(dai).code);
        MockERC20(DAI).approve(address(distributor), type(uint256).max);
        MockERC20(DAI).mint();

        distributor.setWindow(totalDAIRewards, DAI, merkleRootWindow2, "");

        return claimA3W2;
    }
}
