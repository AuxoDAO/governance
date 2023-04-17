// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {MockRewardsToken} from "../mocks/Token.sol";
import {ITerminatableEvents} from "@governance/EarlyTermination.sol";
import {TestLocker} from "./Setup.t.sol";
import "@test/utils.sol";

contract TestEarlyTermination is Test, ITerminatableEvents {
    TestLocker private locker;

    function setUp() public {
        TestLocker impl = new TestLocker();
        Proxy proxy = new Proxy();
        proxy.setImplementation(address(impl));
        locker = TestLocker(address(proxy));
        locker.initialize();
    }

    function testFuzz_SetPenaltyBeneficiary(address _newBenifiary, address _caller) public {
        vm.assume(_newBenifiary != address(0));
        vm.startPrank(_caller);
        if (locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), _caller)) {
            vm.expectEmit(true, false, false, true);
            emit PenaltyBeneficiaryChanged(_newBenifiary);
            locker.setPenaltyBeneficiary(_newBenifiary);
            assertEq(_newBenifiary, locker.penaltyBeneficiary());
        } else {
            vm.expectRevert(bytes(accessControlRevertString(_caller, locker.DEFAULT_ADMIN_ROLE())));
            locker.setPenaltyBeneficiary(_newBenifiary);
        }
        vm.stopPrank();
    }

    function testCannotSetBeneficiaryToZero() public {
        address admin = locker.getRoleMember(locker.DEFAULT_ADMIN_ROLE(), 0);
        vm.startPrank(admin);
        vm.expectRevert("setPenaltyBeneficiary: Zero address");
        locker.setPenaltyBeneficiary(address(0));
    }

    function testFuzz_SetPenalty(uint256 _penaltyPercentage, address _caller) public {
        vm.assume(_penaltyPercentage < locker.HUNDRED_PERCENT());

        vm.startPrank(_caller);
        if (locker.hasRole(locker.DEFAULT_ADMIN_ROLE(), _caller)) {
            vm.expectEmit(true, false, false, true);
            emit EarlyExitFeeChanged(_penaltyPercentage);
            locker.setPenalty(_penaltyPercentage);
            assertEq(locker.earlyExitFee(), _penaltyPercentage);
        } else {
            vm.expectRevert(bytes(accessControlRevertString(_caller, locker.DEFAULT_ADMIN_ROLE())));
            locker.setPenalty(_penaltyPercentage);
        }
        vm.stopPrank();
    }

    function testFuzz_CannotSetInvalidPenalty(uint256 _penaltyPercentage) public {
        vm.assume(_penaltyPercentage >= locker.HUNDRED_PERCENT());
        address admin = locker.getRoleMember(locker.DEFAULT_ADMIN_ROLE(), 0);
        vm.startPrank(admin);
        vm.expectRevert("setPenalty: Fee to big");
        locker.setPenalty(_penaltyPercentage);
    }
}
