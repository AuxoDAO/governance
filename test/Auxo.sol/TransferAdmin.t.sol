// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestAuxoSetup} from "./Setup.sol";
import "@oz/utils/Strings.sol";

contract TestTransferAdmin is TestAuxoSetup {
    function setUp() public {
        prepareSetup();
    }

    function testFuzz_TransferOfAdminRole(address _newAdmin) public {
        vm.assume(_newAdmin != address(0) && _newAdmin != address(this));
        auxo.grantRole(auxo.DEFAULT_ADMIN_ROLE(), _newAdmin);
        assert(auxo.hasRole(auxo.DEFAULT_ADMIN_ROLE(), _newAdmin));
        auxo.renounceRole(auxo.DEFAULT_ADMIN_ROLE(), address(this));
        assert(!auxo.hasRole(auxo.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    // test changing admin for AUXO
    function testFuzz_ChangingAuxoAdmin(address _newAdmin, address _notAdmin) public {
        vm.assume(_newAdmin != _notAdmin && _newAdmin != address(0) && _newAdmin != address(this));

        bytes32 defaultAdminRole = auxo.DEFAULT_ADMIN_ROLE();
        // set the minter address
        auxo.grantRole(defaultAdminRole, _newAdmin);

        vm.prank(_newAdmin);
        auxo.revokeRole(defaultAdminRole, address(this));

        assert(auxo.hasRole(defaultAdminRole, _newAdmin));
        assert(!auxo.hasRole(defaultAdminRole, address(this)));

        // Strings is needed because otherwise checksummed addr != lowercase addr in OZ vs foundry
        bytes memory err = abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(_notAdmin),
            " is missing role ",
            vm.toString(defaultAdminRole)
        );
        vm.expectRevert(err);
        vm.prank(_notAdmin);
        auxo.grantRole(defaultAdminRole, _notAdmin);
    }
}
