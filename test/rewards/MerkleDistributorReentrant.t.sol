// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IMerkleDistributorCore, MerkleDistributor} from "@rewards/MerkleDistributor.sol";

import "./MerkleTreeInitializer.sol";
import "../utils.sol";

/// test reentrancy guard by having the same modifier on inner and outer functions
contract Reentrant is MerkleDistributor {
    function reClaim(Claim memory _claim) external nonReentrant {
        this.claim(_claim);
    }

    function reClaimMulti(Claim[] memory _claims) external nonReentrant {
        this.claimMulti(_claims);
    }

    function reClaimDelegated(Claim memory _claim) external nonReentrant {
        this.claimDelegated(_claim);
    }

    function reClaimMultiDelegated(Claim[] memory _claims) external nonReentrant {
        this.claimMultiDelegated(_claims);
    }
}


contract TestDistributor is MerkleRewardsTestBase {
    Reentrant internal re;

    function setUp() public override {
        super.setUp();
        re = new Reentrant();
        Proxy proxy = proxies[MERKLE_DISTRIBUTOR].proxy;
        vm.prank(proxy.getProxyOwner());
        proxy.setImplementation(address(re));
    }

    function testNoReentrant() public {
        Claim[] memory _claims = new Claim[](1);
        _claims[0] = Claim({
            accountIndex: 3,
            account: claimant3,
            amount: 1000000000000000000,
            windowIndex: 0,
            merkleProof: merkleProofClaimant3Window0,
            token: WETH
        });

        vm.expectRevert(Errors.REENTRANCY_GUARD);
        re.reClaim(_claims[0]);

        vm.expectRevert(Errors.REENTRANCY_GUARD);
        re.reClaimMulti(_claims);

        vm.expectRevert(Errors.REENTRANCY_GUARD);
        re.reClaimDelegated(_claims[0]);

        vm.expectRevert(Errors.REENTRANCY_GUARD);
        re.reClaimMultiDelegated(_claims);
    }
}
