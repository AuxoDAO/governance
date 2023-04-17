// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {MockRewardsToken} from "@mocks/Token.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {RollStaker} from "@prv/RollStaker.sol";
import {PRVRouter} from "@prv/PRVRouter.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

import {ISafe130 as IGnosisSafe} from "./ISafe130.sol";

/**
 * @dev simulating the migration of a smart contract account with veDOUGH locked in a Gnosis Safe
 *      This test is a fork test and requires the enviornment variable RPC_URL to be set
 *
 *      Ordinarily the veDOUGH tokenLocker (and Auxo TokenLocker) do not allow smart contract wallets to hold veDOUGH.
 *      This is a deliberate safety mechanism to prevent certain classes of attacks.
 *      We do, however, have whitelisting capabilities for approved addresses.
 *
 *      An example address is https://etherscan.io/address/0xea9f2e31ad16636f4e1af0012db569900401248a#code
 *      which is a Gnosis safe holding approx 2.4m veDOUGH.
 *
 *      These tests need to cover the workflow of creating a signature for the migration from each of the multisig signers, then submitting the `execTransaction` from the gnosis safe.
 *      The safe in question has one signator: https://etherscan.io/address/0x4d04eb67a2d1e01c71fad0366e0c200207a75487 (jailwarden.eth)
 *      We need to setup the contract to call our veAUXO migration functions.
 *
 *      We do this by pranking the safe itself, adding ourselves as the owner and signing a 1/1 message to the safe that approves the migration transaction.
 *      We then call the migration function from the safe, which will call the upgradoor contract.
 */
contract TestContractMigrate is Test, UpgradeDeployer {
    /* ========== Fork Data ========== */

    // multisigs
    address payable public constant USER_MULTISIG = payable(0xEa9f2E31Ad16636f4e1AF0012dB569900401248a);
    address public PIEDAO_MULTISIG = 0x6458A23B020f489651f2777Bd849ddEd34DfCcd2;

    // contract addressses
    address payable public constant OLD_TIMELOCK = payable(0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45);
    address public constant DOUGH = 0xad32A8e6220741182940c5aBF610bDE99E737b2D;
    address public constant VEDOUGH = 0xE6136F2e90EeEA7280AE5a0a8e6F48Fb222AF945;

    // users - jailwarden.eth is the owner of the safe with a large qty of veDOUGH
    address public constant JAILWARDEN = 0x4D04EB67A2D1e01c71FAd0366E0C200207A75487;

    // contracts fetched from mainnet (versus deployed in the test)
    SharesTimeLock public OLD = SharesTimeLock(OLD_TIMELOCK);
    IGnosisSafe public safe = IGnosisSafe(USER_MULTISIG);
    IERC20 public dough = IERC20(DOUGH);
    IERC20 public veDOUGH = IERC20(VEDOUGH);

    /* ========== Test Data ========== */

    // the user we will generate with a known private key
    uint128 private PK1 = 1;
    address internal user = vm.addr(PK1);

    // contracts deployed in the test
    Upgradoor internal UP;
    TokenLocker internal tokenLocker;
    ARV internal veauxo;
    Auxo internal auxo;
    PRV internal lsd;
    PRVRouter internal router;
    RollStaker internal roll;

    uint32 internal constant AVG_SECONDS_MONTH = 2628000;

    /* ========== Test Setup ========== */

    /// @dev boilerplate for deploying the auxo contracts
    function _deployAuxoProtocol() internal {
        // init the locker
        tokenLocker = _deployLockerUninitialized();

        // setup tokens
        auxo = new Auxo();
        auxo.mint(address(this), 1 ether);
        veauxo = new ARV(address(tokenLocker));

        // init locker with the ARV/veAUXO token
        tokenLocker.initialize(
            auxo, IERC20MintableBurnable(address(veauxo)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 0.0001 ether
        );

        // setup lsd/xauxo/PRV and connect to router and rollstaker
        lsd = _deployPRV(address(auxo));
        auxo.approve(address(lsd), 1 ether);
        roll = _deployRollStaker(address(lsd));
        router = new PRVRouter(address(auxo), address(lsd), address(roll));
    }

    /// @dev deploys the upgradoor and updates the sharestimelock to the newest implementation with migration enabled
    function _deployUpgradoor() internal {
        UP = new Upgradoor(
            address(OLD),
            address(auxo),
            address(dough),
            address(tokenLocker),
            address(lsd),
            address(veDOUGH),
            address(router)
        );

        // Set the migrator on the old timelock & enable migration
        SharesTimeLock stImpl = new SharesTimeLock();
        Proxy stProxy = Proxy(OLD_TIMELOCK);

        vm.startPrank(PIEDAO_MULTISIG);
        {
            stProxy.setImplementation(address(stImpl));
            OLD.setMigrationON();
            OLD.setMigratoor(address(UP));
        }
        vm.stopPrank();

        // We whitelist the Upgradoor contract to auxo on the tokenlocker
        tokenLocker.setWhitelisted(address(UP), true);

        // We give minting role to the Upgradoor
        auxo.grantRole(auxo.MINTER_ROLE(), address(UP));

        // finally, we need to whitelist the safe on the locker
        tokenLocker.setWhitelisted(address(safe), true);
    }

    function setUp() public {
        // connect to the forked environment
        string memory rpc = vm.envString("RPC_URL");
        uint256 forkId = vm.createFork(rpc, 16577397);
        vm.selectFork(forkId);

        // deploy the auxo protocol
        _deployAuxoProtocol();

        // deploy the upgradoor
        _deployUpgradoor();
    }

    /* ========== Tests ========== */

    /// @dev check everything is working: at block 16577397 the safe has nonce 723
    function testFork_canGetSafe() public {
        assertEq(safe.nonce(), 723);
    }

    /// @dev ensure we can add a new owner to the safe for our test
    ///      usually this requires a safe transaction, but in foundry, we can prank the safe
    function testFork_transferSafeOwnership() public {
        vm.prank(address(safe));
        safe.addOwnerWithThreshold(user, 1);
        assert(safe.isOwner(user));
    }

    /// @dev check we can get the correct veDOUGH balance of the safe at block 16577397
    function testFork_canGetVeDoughBalance() public {
        uint256 vedoughBalanceBefore = veDOUGH.balanceOf(address(safe));
        assertEq(vedoughBalanceBefore, 2381425290208086383693704);
    }

    // let's try creating a valid signature
    function testFork_canSign() public {
        // we need to add the user as an owner to the safe in order for the safe to consider the signature valid
        vm.prank(address(safe));
        safe.addOwnerWithThreshold(user, 1);

        // this is the function we are looking to call from our safe
        bytes memory callData = abi.encodeWithSelector(UP.aggregateAndBoost.selector);

        // we need to wrap the calldata with additional transaction metadata to create
        // a signable message that the safe expects
        bytes memory txData = safe.encodeTransactionData({
            to: address(UP),
            value: 0,
            data: callData,
            operation: 0,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: safe.nonce()
        });

        // ecrecover expects a hash of the message
        bytes32 txHash = keccak256(txData);

        // sign it first and check it works with ecrecover
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK1, txHash);
        address currentOwner = ecrecover(txHash, v, r, s);
        assertEq(currentOwner, user);

        // safe expects a signature in r,s,v and packed.
        bytes memory signature = abi.encodePacked(r, s, v);

        // now get v,r,s from the safe's internal method and check it
        (v, r, s) = signatureSplit(signature, 0);
        currentOwner = ecrecover(txHash, v, r, s);
        assertEq(currentOwner, user);

        // the signature should be valid now
        // these transactions will revert if the signature is invalid
        safe.checkNSignatures(txHash, txData, signature, 1);
        safe.checkSignatures(txHash, txData, signature);
    }

    function testFork_safeAggregateToVeAuxo() public {
        bytes memory callData = abi.encodeWithSelector(UP.aggregateToARV.selector);
        _executeWithSafe(callData);
    }

    function testFork_safeAggregateAndBoost() public {
        bytes memory callData = abi.encodeWithSelector(UP.aggregateAndBoost.selector);
        _executeWithSafe(callData);
    }

    function testFork_safeUpgradeSingleLockVeAuxo() public {
        bytes memory callData = abi.encodeCall(UP.upgradeSingleLockARV, (address(safe)));
        _executeWithSafe(callData);
    }

    /* ========== Test Helpers ========== */

    /// @param _callData encode the function call to pass to the gnosis safe
    function _executeWithSafe(bytes memory _callData) internal {
        uint256 vedoughBalanceBefore = veDOUGH.balanceOf(address(safe));
        uint256 veauxoBalanceBefore = veauxo.balanceOf(address(safe));
        console2.log("veDOUGH balance before", vedoughBalanceBefore);
        console2.log("veAUXO balance before", veauxoBalanceBefore);

        // we need to add the user as an owner to the safe in order for the safe to consider the signature valid
        vm.prank(address(safe));
        safe.addOwnerWithThreshold(user, 1);

        // we need to wrap the calldata with additional transaction metadata to create
        // a signable message that the safe expects
        bytes memory txData = safe.encodeTransactionData({
            to: address(UP),
            value: 0,
            data: _callData,
            operation: 0,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: safe.nonce()
        });

        // ecrecover expects a hash of the message
        bytes32 txHash = keccak256(txData);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK1, txHash);

        // safe expects a signature in r,s,v and packed.
        bytes memory signature = abi.encodePacked(r, s, v);

        // try executing the transaction
        vm.prank(user);
        safe.execTransaction({
            to: address(UP),
            value: 0,
            data: _callData,
            operation: 0,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            signatures: signature
        });

        uint256 vedoughBalanceAfter = veDOUGH.balanceOf(address(safe));
        uint256 veauxoBalanceAfter = veauxo.balanceOf(address(safe));
        console2.log("veDOUGH balance after", vedoughBalanceAfter);
        console2.log("veAUXO balance after", veauxoBalanceAfter);

        assertLt(vedoughBalanceAfter, vedoughBalanceBefore);
        assertGt(veauxoBalanceAfter, 0);
    }


    /// @dev lifted from internal function in Gnosis Safe to validate our signature ecrecover
    function signatureSplit(bytes memory signatures, uint256 pos)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // The signature format is a compact form of:
        //   {bytes32 r}{bytes32 s}{uint8 v}
        // Compact means, uint8 is not padded to 32 bytes.
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            // Here we are loading the last 32 bytes, including 31 bytes
            // of 's'. There is no 'mload8' to do this.
            //
            // 'byte' is not working due to the Solidity parser, so lets
            // use the second best option, 'and'
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }
}
