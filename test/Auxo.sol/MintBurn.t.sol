// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestAuxoSetup} from "./Setup.sol";
import "@oz/utils/Strings.sol";

contract TestMintBurn is TestAuxoSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======

    // test restricted mint of AUXO to minter
    function testFuzz_RestrictedMint(address _minter, address _notMinter, uint256 _value) public {
        vm.assume(_minter != _notMinter && _minter != address(0) && _notMinter != address(this));

        // set the minter address
        auxo.grantRole(auxo.MINTER_ROLE(), _minter);

        vm.prank(_minter);
        auxo.mint(_minter, _value);

        // Strings is needed because otherwise checksummed addr != lowercase addr in OZ vs foundry
        bytes memory err = abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(_notMinter),
            " is missing role ",
            vm.toString(auxo.MINTER_ROLE())
        );
        vm.expectRevert(err);
        vm.prank(_notMinter);
        auxo.mint(_notMinter, _value);
    }
}
