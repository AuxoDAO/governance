// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IMerkleDistributorCore, MerkleDistributor} from "@rewards/MerkleDistributor.sol";

import "./MerkleTreeInitializer.sol";
import "../utils.sol";

contract TestDistributor is MerkleRewardsTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testSetWindow(bytes32 _merkleRootWindow0, string memory _ipfsHash, uint256 _totalAmount) public {
        MockERC20 rewardToken = _prepareRewardToken();
        uint256 currentWindowIndex = distributor.nextCreatedIndex();

        vm.expectEmit(true, true, false, true);
        emit CreatedWindow(currentWindowIndex, address(this), _totalAmount, address(rewardToken));
        distributor.setWindow(_totalAmount, address(rewardToken), _merkleRootWindow0, _ipfsHash);

        uint256 nextCreatedIndex = distributor.nextCreatedIndex();
        assertEq(nextCreatedIndex, currentWindowIndex + 1);

        // check token totals are correct and totals have been transferred
        assertEq(rewardToken.balanceOf(address(distributor)), _totalAmount);
        assertEq(distributor.getWindow(currentWindowIndex).rewardAmount, _totalAmount);

        // check state variables
        Window memory window = distributor.getWindow(currentWindowIndex);
        assertEq(window.merkleRoot, _merkleRootWindow0);
        assertEq(window.ipfsHash, _ipfsHash);
    }

    // Test ownable functions setWindow, setLock, deleteWindow, WithdrawRewards
    function testOwnable(address _notOwner) public {
        vm.assume(_notOwner != distributor.owner());
        bytes memory ownableErr = bytes("Ownable: caller is not the owner");

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.setWindow(0, address(0), bytes32(0x0), "");

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.setLock(0);

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.deleteWindow(0);

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.withdrawRewards(address(0), 0);

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.pause();

        vm.prank(_notOwner);
        vm.expectRevert(ownableErr);
        distributor.unpause();
    }

    // test pausable functions setWindow, setLock, deleteWindow, WithdrawRewards
    function testPausable(address _anyone) public notAdmin(_anyone) {
        vm.prank(distributor.owner());
        distributor.pause();

        vm.startPrank(_anyone);
        {
            Claim memory claim = Claim({
                account: _anyone,
                amount: 0,
                accountIndex: 0,
                token: address(0),
                windowIndex: 0,
                merkleProof: new bytes32[](0)
            });
            Claim[] memory claims = new Claim[](1);
            claims[0] = claim;

            vm.expectRevert(Errors.PAUSABLE);
            distributor.claimDelegated(claim);

            vm.expectRevert(Errors.PAUSABLE);
            distributor.claimMultiDelegated(claims);
        }
        vm.stopPrank();
    }

    // Test lock prevents claiming
    function testLockedClaims(uint256 _lock, Claim memory _claim) public notAdmin(_claim.account) {
        vm.assume(_lock > 0);
        vm.assume(_claim.account != distributor.owner());
        bytes memory lockedErr = bytes("Distributor is Locked");

        vm.expectEmit(true, false, false, true);
        emit LockSet(_lock);
        distributor.setLock(_lock);

        vm.startPrank(_claim.account);
        {
            vm.expectRevert(lockedErr);
            distributor.claim(_claim);
        }
        vm.stopPrank();
    }

    function testDeleteWindow(bytes32 _merkleRootWindow0, string memory _ipfsHash, uint256 _rewardAmount) public {
        address rewardToken = address(_prepareRewardToken());

        // ensure the window indicies are correctly incremented
        uint256 currentWindowIndex = distributor.nextCreatedIndex();
        distributor.setWindow(_rewardAmount, rewardToken, _merkleRootWindow0, _ipfsHash);
        uint256 nextCreatedIndex = distributor.nextCreatedIndex();
        assertEq(nextCreatedIndex, currentWindowIndex + 1);

        (bytes32 root,,, string memory ipfsHash) = distributor.merkleWindows(currentWindowIndex);
        assertEq(root, _merkleRootWindow0);
        assertEq(ipfsHash, _ipfsHash);

        vm.expectEmit(true, true, false, true);
        emit DeleteWindow(currentWindowIndex, address(this));
        distributor.deleteWindow(currentWindowIndex);
        (root,,, ipfsHash) = distributor.merkleWindows(currentWindowIndex);
        assertEq(root, bytes32(""));
        assertEq(ipfsHash, "");
    }

    // test emergency withdrawals
    function testEmergencyWithdraw(uint256 _totalRewards, uint256 _amount) public {
        vm.assume(_amount < _totalRewards);

        MockERC20 token = _prepareRewardToken();
        distributor.setWindow(_totalRewards, address(token), bytes32(""), "");

        uint256 distributorTokenBalancePre = token.balanceOf(address(distributor));

        vm.expectEmit(true, false, true, true);
        emit WithdrawRewards(address(this), _amount, address(token));
        distributor.withdrawRewards(address(token), _amount);

        uint256 distributorTokenBalancePost = token.balanceOf(address(distributor));
        assertEq(distributorTokenBalancePre - distributorTokenBalancePost, _amount);
    }

    function testClaim() public {
        (Claim memory claimA9W0, Claim memory claimA9W1, Claim memory claimA3W0) = _initializeClaims();

        assertEq(distributor.verifyClaim(claimA9W0), true);
        assertEq(distributor.verifyClaim(claimA9W1), true);
        assertEq(distributor.verifyClaim(claimA3W0), true);

        assertEq(distributor.isClaimed(claimA9W0.windowIndex, claimA9W0.accountIndex), false);
        assertEq(distributor.isClaimed(claimA9W1.windowIndex, claimA9W1.accountIndex), false);
        assertEq(distributor.isClaimed(claimA3W0.windowIndex, claimA3W0.accountIndex), false);

        vm.prank(claimant9);
        vm.expectEmit(true, true, true, true);
        emit Claimed(claimant9, 0, claimant9, claimA9W0.accountIndex, claimA9W0.amount, claimA9W0.token);
        distributor.claim(claimA9W0);

        {
            uint256 claimantRewardBalance = MockERC20(claimA9W0.token).balanceOf(claimant9);
            assertEq(claimantRewardBalance, claimA9W0.amount);
        }

        assertEq(distributor.isClaimed(claimA9W0.windowIndex, claimA9W0.accountIndex), true);
        assertEq(distributor.isClaimed(claimA9W1.windowIndex, claimA9W1.accountIndex), false);
        assertEq(distributor.isClaimed(claimA3W0.windowIndex, claimA3W0.accountIndex), false);

        // attempt a second claim
        vm.expectRevert("Already Claimed for Window");
        distributor.claim(claimA9W0);

        // claim the next window
        vm.expectEmit(true, true, true, true);
        emit Claimed(address(this), 1, claimant9, claimA9W1.accountIndex, claimA9W1.amount, claimA9W1.token);
        distributor.claim(claimA9W1);

        {
            assertEq(claimA9W1.token, claimA9W0.token);
            uint256 claimantRewardBalance = MockERC20(claimA9W0.token).balanceOf(claimant9);
            assertEq(claimantRewardBalance, claimA9W0.amount + claimA9W1.amount);
        }

        assertEq(distributor.isClaimed(claimA9W0.windowIndex, claimA9W0.accountIndex), true);
        assertEq(distributor.isClaimed(claimA9W1.windowIndex, claimA9W1.accountIndex), true);
        assertEq(distributor.isClaimed(claimA3W0.windowIndex, claimA3W0.accountIndex), false);
    }

    // test invalid claims
    function testInvalidClaims(Claim memory _invalidClaim) public {
        vm.expectRevert("Invalid Claim");
        distributor.claim(_invalidClaim);
    }

    // test valid claim for previous window reverts
    function testCannotClaimForPrevWindow() public {
        (Claim memory claimW0, Claim memory claimW1,) = _initializeClaims();

        bytes32[] memory proofW0;
        bytes32[] memory proofW1;

        proofW0 = claimW0.merkleProof;
        proofW1 = claimW1.merkleProof;

        claimW0.merkleProof = proofW1;
        claimW1.merkleProof = proofW0;

        vm.expectRevert("Invalid Claim");
        distributor.claim(claimW1);

        vm.expectRevert("Invalid Claim");
        distributor.claim(claimW0);
    }

    function testSuccessfulMultiClaim() public {
        (Claim memory claimA9W0, Claim memory claimA9W1,) = _initializeClaims();

        Claim[] memory claims = new Claim[](2);
        claims[0] = claimA9W0;
        claims[1] = claimA9W1;

        vm.prank(claimant9);
        distributor.claimMulti(claims);

        {
            uint256 claimant9RewardBalance = MockERC20(claimA9W0.token).balanceOf(claimant9);
            assertEq(claimant9RewardBalance, claimA9W0.amount + claimA9W1.amount);
        }

        for (uint256 c; c < claims.length; c++) {
            assertEq(distributor.isClaimed(claims[c].windowIndex, claims[c].accountIndex), true);
        }
    }

    function testCannotMultiClaimWithPaddedArray() public {
        (Claim memory claimA9W0, Claim memory claimA9W1,) = _initializeClaims();

        Claim[] memory claims = new Claim[](3);
        claims[0] = claimA9W0;
        claims[1] = claimA9W1;

        vm.expectRevert("Claimant != Sender");
        distributor.claimMulti(claims);
    }

    function testCannotMultiClaimForMultipleTokens(address _newRewardToken) public {
        (Claim memory claimA9W0, Claim memory claimA9W1,) = _initializeClaims();
        vm.assume(claimA9W0.token != _newRewardToken);

        Claim[] memory _claims = new Claim[](2);
        _claims[0] = claimA9W0;
        _claims[1] = claimA9W1;

        // change reward token on second claim
        _claims[1].token = _newRewardToken;

        vm.expectRevert("Multiple Tokens");
        vm.prank(claimant9);
        distributor.claimMulti(_claims);
    }

    function testBadMultiClaim(Claim[] memory _claims, address _reward, address _account) public {
        vm.assume(_claims.length > 0);

        // set the reward and account to a constant value
        for (uint256 c; c < _claims.length; c++) {
            _claims[c].token = _reward;
            _claims[c].account = _account;
        }
        // we still expect an invalid claim due to merkle proof
        vm.expectRevert("Invalid Claim");
        vm.prank(_account);
        distributor.claimMulti(_claims);
    }

    function testNoEmptyClaims() public {
        Claim[] memory _claims = new Claim[](0);
        vm.expectRevert("No Claims");
        distributor.claimMulti(_claims);
    }

    function testCannotMultiClaimForSomeoneElse(address _notClaimant) public {
        (Claim memory claimA9W0, Claim memory claimA9W1,) = _initializeClaims();
        vm.assume(claimA9W0.account != _notClaimant);

        Claim[] memory claims = new Claim[](2);
        claims[0] = claimA9W0;
        claims[1] = claimA9W1;

        vm.expectRevert("Claimant != Sender");
        vm.prank(_notClaimant);
        distributor.claimMulti(claims);
    }

    // test we can't claim using a different token in another window
    function testCannotClaimForTokenInPreviousWindow() public {
        (,,Claim memory claimA3W0) = _initializeClaims();
        (Claim memory claimA3W2) = _initializeDAIClaim();
        vm.assume(claimA3W0.token != claimA3W2.token);

        // swap the tokens
        address w0Token = claimA3W0.token;
        address w2Token = claimA3W2.token;

        claimA3W0.token = w2Token;
        claimA3W2.token = w0Token;

        vm.expectRevert("Invalid Claim");
        vm.prank(claimant3);
        distributor.claim(claimA3W0);

        vm.expectRevert("Invalid Claim");
        vm.prank(claimant3);
        distributor.claim(claimA3W2);

        // put the tokens back
        claimA3W0.token = w0Token;
        claimA3W2.token = w2Token;

        // claims work again
        vm.prank(claimant3);
        distributor.claim(claimA3W0);

        vm.prank(claimant3);
        distributor.claim(claimA3W2);

        assertEq(MockERC20(WETH).balanceOf(claimant3), claimA3W0.amount);
        assertEq(MockERC20(DAI).balanceOf(claimant3), claimA3W2.amount);
    }
}
