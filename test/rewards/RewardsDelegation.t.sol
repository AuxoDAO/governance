// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import "@forge-std/StdJson.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";

import {IMerkleDistributorCore, MerkleDistributor} from "@rewards/MerkleDistributor.sol";

import "./MerkleTreeInitializer.sol";
import {DelegationRegistry} from "@rewards/DelegationRegistry.sol";

contract TestDistributorDelegate is MerkleRewardsTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotDelegateUnlessWhiteListed(address _user, address _delegate) public notAdmin(_user) {
        vm.prank(_user);
        vm.expectRevert("!whitelisted");
        distributor.setRewardsDelegate(_delegate);

        distributor.setWhitelisted(_delegate, true);

        vm.prank(_user);
        distributor.setRewardsDelegate(_delegate);
        assertEq(distributor.isRewardsDelegate(_user, _delegate), true);

        distributor.setWhitelisted(_delegate, false);

        vm.prank(_user);
        vm.expectRevert("!whitelisted");
        distributor.setRewardsDelegate(_delegate);
    }

    function testCanAddRemoveDelegate(address _user, address _delegate) public notAdmin(_user) {
        vm.assume(_delegate != address(0));
        distributor.setWhitelisted(_delegate, true);

        vm.prank(_user);
        distributor.setRewardsDelegate(_delegate);
        assertEq(distributor.isRewardsDelegate(_user, _delegate), true);

        vm.prank(_user);
        distributor.removeRewardsDelegate();
        assertEq(distributor.isRewardsDelegate(_user, _delegate), false);
    }

    function testDelegatedClaim(address _delegatee) public notAdmin(_delegatee) {
        vm.assume(_delegatee != address(0) && _delegatee != address(distributor) && _delegatee != address(this));

        // delegatee must first be whitelisted
        distributor.setWhitelisted(_delegatee, true);

        // now the claimant must delegate to them
        vm.prank(claimant9);
        distributor.setRewardsDelegate(_delegatee);

        // check initial state
        (Claim memory claimA9W0,,) = _initializeClaims();
        assertEq(distributor.isClaimed(claimA9W0.windowIndex, claimA9W0.accountIndex), false);

        // as the delegatee, make the claim on behalf of the user
        vm.startPrank(_delegatee);
        {
            vm.expectEmit(true, true, true, true);
            emit ClaimDelegated(
                _delegatee, 0, claimA9W0.account, claimA9W0.accountIndex, claimA9W0.amount, claimA9W0.token
                );
            distributor.claimDelegated(claimA9W0);
            uint256 claimantRewardBalance = MockERC20(claimA9W0.token).balanceOf(_delegatee);
            assertEq(claimantRewardBalance, claimA9W0.amount);
        }
        vm.stopPrank();

        assertEq(distributor.isClaimed(claimA9W0.windowIndex, claimA9W0.accountIndex), true);
    }

    function testCannotClaimIfInvalidDelegate(address _notDelegatee) public notAdmin(_notDelegatee) {
        (Claim memory claimA9W0,,) = _initializeClaims();

        // test that nobody other than the delegate can make the claim
        vm.prank(_notDelegatee);
        vm.expectRevert("!whitelisted");
        distributor.claimDelegated(claimA9W0);

        distributor.setWhitelisted(_notDelegatee, true);

        vm.prank(_notDelegatee);
        vm.expectRevert("!whitelisted for user");
        distributor.claimDelegated(claimA9W0);
    }

    function testCannotClaimIfSomeoneElsesDelegate(address _delegateeA, address _delegateeB)
        public
        notAdmin(_delegateeA)
        notAdmin(_delegateeB)
    {
        vm.assume(_delegateeA != _delegateeB);
        (Claim memory claimA9W0,, Claim memory claimA3W0) = _initializeClaims();

        distributor.setWhitelisted(_delegateeA, true);
        distributor.setWhitelisted(_delegateeB, true);

        vm.prank(claimant9);
        distributor.setRewardsDelegate(_delegateeA);

        vm.prank(claimant3);
        distributor.setRewardsDelegate(_delegateeB);

        // test that nobody other than the delegate can make the claim
        vm.startPrank(_delegateeB);
        {
            vm.expectRevert("!whitelisted for user");
            distributor.claimDelegated(claimA9W0);
        }
        vm.stopPrank();

        vm.startPrank(_delegateeA);
        {
            vm.expectRevert("!whitelisted for user");
            distributor.claimDelegated(claimA3W0);
        }
        vm.stopPrank();
    }

    function testSuccessfulDelegatedMultiClaim(address _delegate) public notAdmin(_delegate) {
        vm.assume(_delegate != address(distributor) && _delegate != address(0) && _delegate != address(this));
        distributor.setWhitelisted(_delegate, true);

        vm.prank(claimant9);
        distributor.setRewardsDelegate(_delegate);

        vm.prank(claimant3);
        distributor.setRewardsDelegate(_delegate);

        (Claim memory claimA9W0, Claim memory claimA9W1, Claim memory claimA3W0) = _initializeClaims();

        Claim[] memory claims = new Claim[](3);
        claims[0] = claimA9W0;
        claims[1] = claimA9W1;
        claims[2] = claimA3W0;

        // setup the expected arrays for the event
        uint8[] memory windowIndexes = new uint8[](3);
        uint16[] memory accountIndexes = new uint16[](3);

        for (uint256 c; c < claims.length; c++) {
            windowIndexes[c] = uint8(claims[c].windowIndex);
            accountIndexes[c] = uint16(claims[c].accountIndex);
        }

        vm.prank(_delegate);
        vm.expectEmit(true, true, false, true);
        emit ClaimDelegatedMulti(_delegate, WETH, windowIndexes, accountIndexes);
        distributor.claimMultiDelegated(claims);

        {
            uint256 delegateRewardBalance = MockERC20(claimA9W0.token).balanceOf(_delegate);
            assertEq(delegateRewardBalance, claimA9W0.amount + claimA9W1.amount + claimA3W0.amount);
        }

        for (uint256 c; c < claims.length; c++) {
            assertEq(distributor.isClaimed(claims[c].windowIndex, claims[c].accountIndex), true);
        }
    }

    function testInvalidDelegatedMultiClaim(address _delegate, address _notWeth) public notAdmin(_delegate) {
        vm.assume(_delegate != address(0));
        vm.assume(_notWeth != WETH);

        (Claim memory claimA9W0, Claim memory claimA9W1,) = _initializeClaims();

        Claim[] memory claims = new Claim[](2);
        claims[0] = claimA9W0;
        claims[1] = claimA9W1;

        // not set at all
        vm.prank(_delegate);
        vm.expectRevert("!whitelisted");
        distributor.claimMultiDelegated(claims);

        // set the _delegate as whitelisted
        distributor.setWhitelisted(_delegate, true);

        // can claim but not for this user
        vm.prank(_delegate);
        vm.expectRevert("!whitelisted for user");
        distributor.claimMultiDelegated(claims);

        // claimant allows delegation to _delegate
        vm.prank(claimant9);
        distributor.setRewardsDelegate(_delegate);

        // can claim but has invalid token
        claims[1].token = _notWeth;
        vm.prank(_delegate);
        vm.expectRevert("Multiple Tokens");
        distributor.claimMultiDelegated(claims);
    }

    function testNoEmptyClaims(address _delegate) public {
        Claim[] memory _claims = new Claim[](0);

        distributor.setWhitelisted(_delegate, true);

        vm.expectRevert("No Claims");
        vm.prank(_delegate);
        distributor.claimMultiDelegated(_claims);
    }
}
