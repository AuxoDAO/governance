pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV, IPRVEvents} from "@prv/PRV.sol";
import {PRVMerkleVerifier, IPRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Auxo} from "@src/AUXO.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {PRVTestBase} from "../PRVBase.t.sol";

import "@test/utils.sol";

/**
 * @notice tests validating the PRV contract works correctly with the verifier
 */
contract PRVTestCoreAndVerifier is PRVTestBase, IPRVMerkleVerifier {
    bytes32 internal rootW0 = bytes32(0x99aafea368f4ad8d1abfd7b83b33af84beb15b64a2063d828c75423667cd0048);
    bytes32 internal rootW1 = bytes32(0x074152ca48d467571c80a0ee9f73e4480c1737aefac3c2bdbaea685cb840031a);

    bytes32[] internal proofu0w0;
    bytes32[] internal proofu1w0;
    bytes32[] internal proofu0w1;
    bytes32[] internal proofu1w1;

    address internal u0 = 0x1A1087Bf077f74fb21fD838a8a25Cf9Fe0818450;
    address internal u1 = 0x63BCe354DBA7d6270Cb34dAA46B869892AbB3A79;

    Claim internal u0w0;
    Claim internal u1w0;
    Claim internal u0w1;
    Claim internal u1w1;


    function setUp() public override {
        super.setUp();
        _initializeClaims();

        deposit.approve(address(prv), type(uint256).max);

        prv.depositFor(u0w0.account, u0w0.amount);
        prv.depositFor(u1w0.account, u1w0.amount);
        prv.depositFor(address(this), 200 ether);

        verifier.setWindow({
            _maxAmount: 1000 ether,
            _merkleRoot: rootW0,
            _startBlock: uint32(block.number + 1),
            _endBlock: uint32(block.number + 100)
        });
    }

    function testClaimVerifierWithRealTree() public {
        // can't claim before window
        assertEq(prv.balanceOf(u0w0.account), u0w0.amount);
        assertEq(deposit.balanceOf(u0w0.account), 0);
        assertEq(prv.balanceOf(u1w0.account), u1w0.amount);
        assertEq(deposit.balanceOf(u1w0.account), 0);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(u0w0.account);
        prv.withdraw(u0w0.amount, abi.encode(u0w0));

        assertEq(prv.balanceOf(u0w0.account), 0);
        assertEq(deposit.balanceOf(u0w0.account), u0w0.amount);

        vm.prank(u1w0.account);
        prv.withdraw(u1w0.amount, abi.encode(u1w0));

        assertEq(prv.balanceOf(u1w0.account), 0);
        assertEq(deposit.balanceOf(u1w0.account), u1w0.amount);

        prv.depositFor(u0w0.account, u0w1.amount);
        prv.depositFor(u1w0.account, u1w1.amount);

        verifier.setWindow({
            _maxAmount: 700 ether,
            _merkleRoot: rootW1,
            _startBlock: uint32(block.number + 101),
            _endBlock: uint32(block.number + 200)
        });

        vm.roll(verifier.getWindow(1).startBlock);

        vm.prank(u0w1.account);
        prv.withdraw(u0w1.amount, abi.encode(u0w1));

        assertEq(prv.balanceOf(u0w1.account), 0);
        assertEq(deposit.balanceOf(u0w1.account), u0w1.amount + u0w0.amount);

        vm.prank(u1w1.account);
        prv.withdraw(u1w1.amount, abi.encode(u1w1));

        assertEq(prv.balanceOf(u1w1.account), 0);
        assertEq(deposit.balanceOf(u1w1.account), u1w1.amount + u1w0.amount);
    }

    // ---------- test helpers ----------

    // init the tree
    function _initializeClaims() internal {
        proofu0w0.push(bytes32(0x61185c89c01e3cf06f5577795f5411dfcbb7d329feae8323dbfd0517bd3e890f));

        u0w0 = Claim({
            windowIndex: 0,
            account: u0,
            amount: 400 ether,
            merkleProof: proofu0w0
        });

        proofu1w0.push(bytes32(0x0685faae847309c9e2900ffd0f727ec0c26300b1ccc207ae1592dbbd110c2cec));
        proofu1w0.push(bytes32(0x4f521107d20365b80e5ec1efeb8e56773df9b77969db02b8e8bc5925ca3ffdb0));

        u1w0 = Claim({
            windowIndex: 0,
            account: u1,
            amount: 400 ether,
            merkleProof: proofu1w0
        });

        proofu0w1.push(bytes32(0x8fdc54b8f23fd61c7d6403f4654b07c92a5e814784150965ad3b64ed42e512f4));
        proofu0w1.push(bytes32(0xa50f4170bd650b6521fde5d54402b79dcb5e6751a7c52882f37cc92d53eca0be));

        u0w1 = Claim({
            windowIndex: 1,
            account: u0,
            amount: 400 ether,
            merkleProof: proofu0w1
        });

        proofu1w1.push(bytes32(0x839265e0cda2bc72047a74edd545abd4e9b4a772906aca0d070e59fa678309e6));

        u1w1 = Claim({
            windowIndex: 1,
            account: u1,
            amount: 300 ether,
            merkleProof: proofu1w1
        });

    }

    // throwaway to use the interface
    function verify(uint256, address, bytes calldata) external returns (bool) {
        return true;
    }
}


