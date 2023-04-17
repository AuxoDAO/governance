pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV, IPRVEvents} from "@prv/PRV.sol";
import {PRVMerkleVerifier, IPRVMerkleVerifier} from "@prv/PRVMerkleVerifier.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Auxo} from "@src/AUXO.sol";
import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {PRVTestBase} from "../PRVBase.t.sol";

import "@test/utils.sol";

contract PRVTestVerifier is PRVTestBase, IPRVMerkleVerifier {
    function setUp() public override {
        super.setUp();

        // setWindow fails without sufficient Auxo in the PRV contract
        // in most cases, we're not testing this, so we just send all the AUXO
        // to the PRV contract to avoid having to do this in every test
        deposit.transfer(address(prv), type(uint256).max);
    }


    // --------- reverts ------------

    // test only the PRV contract can call the verifier
    function testFuzz_onlyPRVCanCall(uint256 _amount, address _notPRV) public {
        vm.assume(_notPRV != address(prv));
        Claim memory claim = createFuzzClaim(0, address(this), _amount);

        vm.prank(_notPRV);
        vm.expectRevert(Errors.NOT_PRV);
        verifier.verify(_amount, claim.account, abi.encode(claim));
    }

    // test the claim cannot be processed when paused
    function testFuzz_cannotProcessClaimWhenPaused() public {
        verifier.pause();
        Claim memory claim = createFuzzClaim(0, address(this), 1);

        vm.expectRevert(Errors.PAUSABLE);
        verifier.verify(1, claim.account, abi.encode(claim));
    }

    // test the claim must be in budget
    function testFuzz_claimMustBeInBudget(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount
    ) public {
        vm.assume(_amount > _maxAmount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);
        Claim memory claim = createFuzzClaim(0, address(this), _amount);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(_startBlock);

        vm.prank(address(prv));
        vm.expectRevert(Errors.NO_BUDGET);
        verifier.verify(_amount, claim.account, abi.encode(claim));
    }

    // test the claim must be in the correct window index
    function testFuzz_claimMustBeCorrectWindow(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount
    ) public {
        vm.assume(_amount <= _maxAmount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        // invalid window index
        Claim memory claim = createFuzzClaim(1, address(this), _amount);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);
        vm.roll(_startBlock);

        vm.prank(address(prv));
        vm.expectRevert(Errors.BAD_WINDOW);
        verifier.verify(_amount, claim.account, abi.encode(claim));

        // valid claim but window is gone
        claim = createFuzzClaim(0, address(this), _amount);
        verifier.deleteWindow(0);

        // now will revert again
        vm.prank(address(prv));
        vm.expectRevert(Errors.BAD_WINDOW);
        verifier.verify(_amount, claim.account, abi.encode(claim));
    }

    // test window must be active
    function testFuzz_claimMustBeInsideWindow(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        uint256 _rollTo
    ) public {
        vm.assume(_rollTo > _endBlock || _rollTo < _startBlock);
        vm.assume(_amount <= _maxAmount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);
        Claim memory claim = createFuzzClaim(0, address(this), _amount);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(_rollTo);

        vm.prank(address(prv));
        vm.expectRevert(Errors.BAD_WINDOW);
        verifier.verify(_amount, claim.account, abi.encode(claim));
    }

    // test the claim must be valid
    function testFuzz_claimMustBeValid(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        /* ~zero chance of random claim being valid */
        Claim memory _claim
    ) public {
        vm.assume(_amount <= _maxAmount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);
        _claim.windowIndex = 0;

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        vm.expectRevert(Errors.INVALID_CLAIM);
        verifier.verify(_amount, _claim.account, abi.encode(_claim));
    }

    // test a zero amount claim will revert
    function testFuzz_zeroClaimRevertsWithPositiveAmount(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_amount <= _maxAmount);
        vm.assume(_amount > 0);

        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);
        _claim.amount = 0;
        _claim.windowIndex = 0;

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        vm.expectRevert(Errors.CLAIM_TOO_HIGH);
        verifier.verify(_amount, _claim.account, abi.encode(_claim));
    }

    function testFuzz_zeroClaimOKwithZeroAmount(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.amount = 0;
        _claim.windowIndex = 0;

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(0, _claim.account, abi.encode(_claim));

        assertEq(verifier.getWindow(0).totalRedeemed, 0);
        assertEq(verifier.withdrawn(_claim.account, 0), 0);
        assertEq(verifier.availableToWithdrawInClaim(_claim), 0);
        assertEq(verifier.canWithdraw(_claim), false);
        assertEq(verifier.budgetRemaining(0), _maxAmount);
    }

    // test a claim where the amount is greater than the claim will revert
    function testFuzz_amountGtClaimReverts(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        _amount = _claim.amount + 1;

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        vm.expectRevert(Errors.CLAIM_TOO_HIGH);
        verifier.verify(_amount, _claim.account, abi.encode(_claim));
    }

    // ---------- success ------------

    // test that the total redeemed and the claimed for user are updated and that the total remaining is correct
    function testFuzz_claimSuccess(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_amount <= _claim.amount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(_amount, _claim.account, abi.encode(_claim));

        Window memory window = verifier.getWindow(0);

        assertEq(window.totalRedeemed, _amount);
        assertEq(verifier.withdrawn(_claim.account, 0), _amount);
        assertEq(verifier.availableToWithdrawInClaim(_claim), _claim.amount - _amount);
        assertEq(verifier.canWithdraw(_claim), _amount < _claim.amount);
        assertEq(verifier.budgetRemaining(0), _maxAmount - _amount);
    }

    // ---------- repeat claims ----------

    // test that exhausting the claim will not allow further claims
    function testFuzz_cannotClaimPastExhaust(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        // total budget needs to allow for multiple claims
        vm.assume(_claim.amount < (_maxAmount / 2) && _claim.amount > 0);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(_claim.amount, _claim.account, abi.encode(_claim));

        vm.prank(address(prv));
        vm.expectRevert(Errors.CLAIM_TOO_HIGH);
        verifier.verify(_claim.amount, _claim.account, abi.encode(_claim));
    }

    // test that going over the user total in separate claims will not allow further claims
    function testFuzz_cannotClaimPastTotalForUser(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_amount < _claim.amount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(_amount, _claim.account, abi.encode(_claim));

        vm.prank(address(prv));
        vm.expectRevert(Errors.CLAIM_TOO_HIGH);
        verifier.verify((_claim.amount - _amount) + 1, _claim.account, abi.encode(_claim));
    }

    // test that going over the budget in separate claims will not allow further claims
    function testFuzz_cannotClaimPastTotalBudget(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(_claim.amount, _claim.account, abi.encode(_claim));

        vm.prank(address(prv));
        vm.expectRevert(Errors.NO_BUDGET);
        verifier.verify((_maxAmount - _claim.amount) + 1, _claim.account, abi.encode(_claim));
    }

    // test that multiple claims within the user claim amount will work
    function testFuzz_canMakeMultipleClaims(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock,
        uint256 _amount,
        Claim memory _claim
    ) public USE_MOCK_VERIFIER {
        vm.assume(_claim.amount < _maxAmount && _claim.amount > 0);
        vm.assume(_amount < _claim.amount);
        vm.assume(_startBlock > block.number);
        vm.assume(_endBlock > _startBlock);

        _claim.windowIndex = 0;
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        vm.roll(verifier.getWindow(0).startBlock);

        vm.prank(address(prv));
        verifier.verify(_amount, _claim.account, abi.encode(_claim));

        // second claim should work
        vm.prank(address(prv));
        verifier.verify(_claim.amount - _amount, _claim.account, abi.encode(_claim));

        // emptied with success
        assertEq(verifier.getWindow(0).totalRedeemed, _claim.amount);
        assertEq(verifier.withdrawn(_claim.account, 0), _claim.amount);
        assertEq(verifier.availableToWithdrawInClaim(_claim), 0);
        assertEq(verifier.canWithdraw(_claim), false);
        assertEq(verifier.budgetRemaining(0), _maxAmount - _claim.amount);
    }

    // --------- WINDOWS -----------

    function testFuzz_createDeleteEventsWindow(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock
    ) public {
        vm.assume(_endBlock > _startBlock);

        vm.expectEmit(true, false, false, true);
        emit CreatedWindow(0, _maxAmount, _startBlock, _endBlock);
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        assertEq(verifier.nextWindowIndex(), 1);

        vm.expectEmit(true, true, false, true);
        emit DeletedWindow(0, address(this));
        verifier.deleteWindow(0);
    }

    function testFuzz_cannotSetWindowWithoutSufficientAuxo(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock
    ) public {
        vm.assume(_endBlock > _startBlock);
        vm.assume(_maxAmount > 0);

        // work out how much Auxo we need to keep in PRV to match max amount
        // given that in setup we send all the Auxo to PRV contract
        uint256 minAuxoNeeded = deposit.balanceOf(address(prv)) - _maxAmount;

        // move it out the PRV contract to cause a revert
        vm.prank(address(prv));
        deposit.transfer(address(this), minAuxoNeeded + 1);

        vm.expectRevert(Errors.INSUFFICIENT_AUXO);
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        // send 1 wei back and it should be fine
        deposit.transfer(address(prv), 1);
        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);
    }

    function testFuzz_cannotSetWindowWithEndBeforeStart(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock
    ) public {
        vm.assume(_endBlock > _startBlock);

        vm.expectRevert(Errors.INVALID_EPOCH);
        verifier.setWindow(_maxAmount, _merkleRoot, _endBlock, _startBlock);
    }

    function testFuzz_setNewWindowDeletesPrevious(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock
    ) public {
        vm.assume(_endBlock > _startBlock);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        assertEq(verifier.getWindow(0).endBlock, _endBlock);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        assertEq(verifier.getWindow(0).endBlock, 0);
        assertEq(verifier.getWindow(1).endBlock, _endBlock);
    }

    // deleting previously deleted window twice doesn't break things
    function testFuzz_canSetNewWindowAfterDeletingPrevious(
        uint256 _maxAmount,
        bytes32 _merkleRoot,
        uint32 _startBlock,
        uint32 _endBlock
    ) public {
        vm.assume(_endBlock > _startBlock);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        assertEq(verifier.nextWindowIndex(), 1);

        verifier.deleteWindow(0);

        verifier.setWindow(_maxAmount, _merkleRoot, _startBlock, _endBlock);

        assertEq(verifier.nextWindowIndex(), 2);
    }

    function testFuzz_Ownable(address _notOwner) public {
        vm.assume(_notOwner != address(this));
        vm.assume(_notOwner != address(0));

        vm.startPrank(_notOwner);
        {
            vm.expectRevert(Errors.OWNABLE);
            verifier.setWindow(0, 0, 0, 0);

            vm.expectRevert(Errors.OWNABLE);
            verifier.deleteWindow(0);

            vm.expectRevert(Errors.OWNABLE);
            verifier.setPRV(address(0));

            vm.expectRevert(Errors.OWNABLE);
            verifier.unpause();

            vm.expectRevert(Errors.OWNABLE);
            verifier.pause();
        }
        vm.stopPrank();
    }

    // check gracefully sending random byte data
    function testCanHandleClaimsTooSmall(bytes calldata _claim) public {
        // foundry doesn't seem to generate long bytearrays on its own
        if (_claim.length < 192) {
            vm.prank(address(prv));
            vm.expectRevert("!DATA");
            verifier.verify(1, address(this), _claim);
        }
    }

    function testFuzz_claimNeverLessThan192Bytes(Claim memory _claim) public {
        assertGe(abi.encode(_claim).length, 192);
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
