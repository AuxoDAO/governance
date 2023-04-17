// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestARVSetup} from "./Setup.sol";
import {EIP712HashBuilder} from "../utils.sol";

contract TestPermit is TestARVSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    // test gasless permit delegation of veAUXO
    function testFuzz_PermitDelegate(uint128 _pk1, uint128 _pk2, uint256 _deadline) public {
        // private keys are 128 to fit in secp256k1 upper bound
        // 2 > 1 ensures they are different && gt 0
        vm.assume(_pk1 > 0 && _pk2 > _pk1);
        vm.assume(_deadline > 0);

        // derive 2 addresses from Private Keys
        address delegator = vm.addr(_pk1);
        address delegatee = vm.addr(_pk2);

        // generate the typehash then sign it.
        // Slicing the sig gives the ECDSA params required for the permit method
        // In a real application, we'd use metamask, ethersjs or something on the client side to do this
        bytes32 permitMessage = EIP712HashBuilder.generateTypeHashDelegate(delegatee, _deadline, veAuxo);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk1, permitMessage);

        // delegatee, or anyone else, can now use the sig to gasslessly delegate votes without onchain tx
        vm.startPrank(delegatee);
        veAuxo.delegateBySig(delegatee, veAuxo.nonces(delegator), _deadline, v, r, s);
        vm.stopPrank();

        assertEq(veAuxo.delegates(delegator), delegatee);
    }

    // ensure delegation does not also enable approvals through permit
    function testFuzz_Permit(uint128 _pk, address _spender, uint256 _deadline, uint256 _value) public {
        vm.assume(_pk > 0);
        vm.assume(_spender != address(0));

        // these constraints fix overflows at the upper bound
        vm.assume(_deadline > 0 && _deadline <= type(uint64).max);

        // generate an otherwise valid signature
        address _user = vm.addr(_pk);
        bytes32 permitMessage = EIP712HashBuilder.generateTypeHashPermit(_user, _spender, _value, _deadline, veAuxo);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, permitMessage);

        // Even though permit is implemented, we expect a revert because we prevent approvals
        vm.prank(_spender);
        vm.expectRevert("ERC20NonTransferable: Approval not supported");
        veAuxo.permit(_user, _spender, _value, _deadline, v, r, s);
    }
}
