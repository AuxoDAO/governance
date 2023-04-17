// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestARVSetup} from "./Setup.sol";

contract TestNonTransferability is TestARVSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    // test veAUXO is not transferrable
    function testFuzz_CannotBeTransferred(address _recipient) public {
        vm.assume(_recipient != address(0));

        vm.prank(locker);
        veAuxo.mint(_recipient, 100);

        vm.startPrank(_recipient);

        vm.expectRevert("ERC20NonTransferable: Transfer not supported");
        veAuxo.transfer(locker, 100);

        vm.expectRevert("ERC20NonTransferable: Approval not supported");
        veAuxo.approve(locker, 100);

        vm.stopPrank();
    }
}
