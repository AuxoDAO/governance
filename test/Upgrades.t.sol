// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import "@test/utils.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";

contract V2 is TokenLocker {
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

contract HashCollision is TokenLocker {
    /// @dev this shares the signature of the proxy. We will see which value is returned
    function addressToBytes32(address _value) public pure returns (bytes32) {
        return bytes32("");
    }
}

contract TestUpgrades is Test {
    using IsEOA for address;

    TokenLocker private timelock;
    Proxy private proxy;
    V2 private timelockV2;
    ARV private reward;
    Auxo private deposit;

    uint32 private constant AVG_SECONDS_MONTH = 2628000;

    function setUp() public {
        TokenLocker impl = new TokenLocker();
        proxy = new Proxy();
        proxy.setImplementation(address(impl));
        timelock = TokenLocker(address(proxy));
        // setup the deposit and reward tokens
        deposit = new Auxo();
        reward = new ARV(address(timelock));

        // initialize
        timelock.initialize(
            deposit, IERC20MintableBurnable(address(reward)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 100
        );
    }

    /// ===== HELPER FUNCTIONS ====
    function _upgradeToV2() internal {
        V2 impl = new V2();
        proxy.setImplementation(address(impl));
        timelockV2 = V2(address(proxy));
    }

    /// ===== Main =====

    // test cannot reinitialize
    function testNoReinitialize() public {
        vm.expectRevert(Errors.INITIALIZED);
        timelock.initialize(deposit, IERC20MintableBurnable(address(reward)), 26 weeks, 156 weeks, 1e18);
    }

    // test we can upgrade a contract
    function testUpgrade() public {
        bool success;
        bytes memory _calldata;

        // make a call with a yet-to-be-implemented function signature
        _calldata = abi.encodeWithSelector(timelockV2.setVersion.selector, "v1.1");
        (success,) = address(proxy).call(_calldata);
        assert(!success);

        _upgradeToV2();

        _calldata = abi.encodeWithSelector(timelockV2.setVersion.selector, "v1.1");
        (success,) = address(proxy).call(_calldata);
        assert(success);
        assertEq(timelockV2.version(), "v1.1");
    }

    // test no re-init after upgrade
    function testCannotReinitAfterUpgrading() public {
        _upgradeToV2();

        vm.expectRevert(Errors.INITIALIZED);
        timelockV2.initialize(deposit, IERC20MintableBurnable(address(reward)), 0, 0, 0);
    }

    function testCannotInitializeImplementationContract() public {
        TokenLocker impl = new TokenLocker();
        vm.expectRevert(Errors.INITIALIZED);
        impl.initialize(
            deposit, IERC20MintableBurnable(address(reward)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 100
        );
    }

    function testOnlyAdminCanSetImplementation(address _someone) public {
        vm.assume(_someone != proxy.getProxyOwner());
        TokenLocker impl = new TokenLocker();

        vm.startPrank(_someone);
        {
            vm.expectRevert(Errors.NOT_PROXY_ADMIN);
            proxy.setImplementation(address(impl));

            vm.expectRevert(Errors.NOT_PROXY_ADMIN);
            proxy.setProxyOwner(_someone);
        }
    }

    function testCollision(address _value) public {
        HashCollision impl = new HashCollision();
        proxy.setImplementation(address(impl));
        HashCollision timelockCollision = HashCollision(address(proxy));

        bytes32 expectedValue = bytes32(uint256(uint160(_value)));
        bytes32 actualValue = timelockCollision.addressToBytes32(_value);

        console2.log("Value after collision");
        console2.logBytes32(actualValue);

        assertEq(actualValue, expectedValue);
    }

    /**
     * @dev you don't need to run this, but it's a basic setup that's useful for
     *      Inspecting the storage layout with multiple inheritance and upgradeable contracts.
     *      You're looking to see if gaps are roughly in the right place, and if variables with
     *      low numbered slots look correct (obviously this will not show any mapping data)
     */
    function PeekStorage() public {
        _upgradeToV2();
        timelockV2.setVersion("VERSION TEST");

        for (uint256 i; i < 140; i++) {
            bytes32 res = timelockV2.peekStorage(i);
            if (i < 37) {
                assertEq(res, bytes32(timelockV2.maxRatioArray(i)));
                continue;
            }
            // isInitialized
            if (i == 37) {
                assertEq(uint256(res), 1);
                continue;
            }
            // isInitializing
            if (i == 38) {
                assertEq(uint256(res), 0);
                continue;
            }
            // __gap first
            if (i <= 38 + 49) {
                assertEq(res, bytes32(0x0));
                continue;
            }
            // _owner
            if (i == 38 + 50) {
                bytes memory addressBytes = abi.encode(address(this));
                assertEq(res, bytes32(addressBytes));
                continue;
            }
            // __gap second
            if (i <= 138) {
                assertEq(res, bytes32(0x0));
                continue;
            }

            /// @dev uncomment this to look at the rest of the slots
            console.logBytes32(res);
        }
    }
}
