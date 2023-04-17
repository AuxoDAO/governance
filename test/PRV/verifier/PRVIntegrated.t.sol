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
    function setUp() public override {
        super.setUp();
        deposit.approve(address(prv), type(uint256).max);
    }

    // test the user can't claim more than the PRV they currently have
    function testFuzz_cannotClaimMorePRVThanInWallet(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        address _depositor,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER notAdmin(_depositor) {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_amount <= _claim.amount && _amount > 0);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        // setup the PRV contract with a deposit
        prv.depositFor(_depositor, _claim.amount);
        // make a second deposit to bring the total Auxo in line with the maxAmount
        prv.depositFor(deriveAddressFrom(_depositor), _maxAmount - _claim.amount);

        // update the claim params with essential info
        _claim.windowIndex = 0;
        _claim.account = _depositor;

        // set the window and roll to the start block
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);
        vm.roll(verifier.getWindow(0).startBlock);

        // make a transfer to reduce the balance
        address hashedDepositor = deriveAddressFrom(_depositor);
        vm.prank(_depositor);
        prv.transfer(hashedDepositor, _amount);

        // depositor claims
        vm.prank(_depositor);
        // errors out because we can't burn the required amount
        vm.expectRevert(Errors.ERC20_BURN);
        prv.withdraw(_claim.amount, abi.encode(_claim));
    }

    // ---------- test helpers ----------

    function createFuzzClaim(uint256 _windowIndex, address _account, uint256 _amount)
        internal
        pure
        returns (Claim memory)
    {
        bytes32[] memory emptyProof;
        return Claim({windowIndex: _windowIndex, account: _account, amount: _amount, merkleProof: emptyProof});
    }

    // throwaway to use the interface
    function verify(uint256, address, bytes calldata) external returns (bool) {
        return true;
    }
}
