// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestARVSetup} from "./Setup.sol";

contract TestMintBurn is TestARVSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    // test restricted mint and burn of veAUXO
    function testFuzz_RestrictedMintBurn(address _notLocker) public {
        vm.assume(_notLocker != locker);

        vm.startPrank(_notLocker);

        vm.expectRevert("ARV: caller is not the TokenLocker");
        veAuxo.mint(locker, 100);

        vm.expectRevert("ARV: caller is not the TokenLocker");
        veAuxo.burn(locker, 100);

        vm.stopPrank();
    }
}
