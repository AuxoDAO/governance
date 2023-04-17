// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import "@forge-std/StdJson.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IMerkleDistributorCore, MerkleDistributor} from "@rewards/MerkleDistributor.sol";

import "./MerkleTreeInitializer.sol";
import "@test/utils.sol";
import {DelegationRegistry} from "@rewards/DelegationRegistry.sol";

contract V2 is MerkleDistributor {
    string public version;

    function setVersion(string memory _v) external {
        version = _v;
    }

    function peekStorage(uint256 _slot) external view returns (bytes32 slotContent) {
        assembly {
            slotContent := sload(_slot)
        }
    }
}

contract MerkleDistributorUpgradeTest is MerkleRewardsTestBase {
    V2 internal v2;
    Proxy internal proxy;

    function setUp() public override {
        super.setUp();
        proxy = proxies[MERKLE_DISTRIBUTOR].proxy;
    }

    function testNoReinitialize() public {
        vm.expectRevert(Errors.INITIALIZED);
        distributor.initialize();
    }

    function testCannotInitializeTheImplementation() public {
        MerkleDistributor impl = new MerkleDistributor();
        vm.expectRevert(Errors.INITIALIZED);
        impl.initialize();
    }

    function testUpgrade() public {
        bool success;
        bytes memory _calldata;

        // make a call with a yet-to-be-implemented function signature
        _calldata = abi.encodeWithSelector(v2.setVersion.selector, "v1.1");
        (success,) = address(proxy).call(_calldata);
        assert(!success);

        V2 impl = new V2();
        proxy.setImplementation(address(impl));
        v2 = V2(address(proxy));

        _calldata = abi.encodeWithSelector(V2.setVersion.selector, "v1.1");
        (success,) = address(proxy).call(_calldata);
        assert(success);
        assertEq(v2.version(), "v1.1");
    }
}
