// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestAuxoSetup} from "./Setup.sol";
import {EIP712HashBuilder} from "../utils.sol";

contract TestPermit is TestAuxoSetup {
    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    // testFuzz_ gasless approve of AUXO
    function testFuzz_Permit(uint128 _pk, address _spender, uint256 _deadline, uint256 _value) public {
        vm.assume(_pk > 0);
        vm.assume(_spender != address(0));
        vm.assume(_deadline > 0);

        // derive the address from the pk and send user tokens,
        address _user = vm.addr(_pk);
        auxo.mint(_user, _value);

        // generate the typehash then sign it.
        // Slicing the sig gives the ECDSA params required for the permit method
        // In a real application, we'd use metamask, ethersjs or something on the client side to do this
        bytes32 permitMessage = EIP712HashBuilder.generateTypeHashPermit(_user, _spender, _value, _deadline, auxo);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, permitMessage);

        // spender can now execute the transfer without the _user needing to pay
        vm.startPrank(_spender);
        auxo.permit(_user, _spender, _value, _deadline, v, r, s);
        auxo.transferFrom(_user, _spender, _value);
        vm.stopPrank();

        // half has gone to spender
        assertEq(auxo.balanceOf(_user), 0);
        assertEq(auxo.balanceOf(_spender), _value);
    }

    /**
     * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2612.md#security-considerations
     * Since the ecrecover precompile fails silently and just returns the zero address as signer when given malformed messages
     * it is important to ensure owner != address(0) to avoid permit from creating an approval to spend "zombie funds" belong to the zero address.
     *
     * The OZ implementation makes explicit checks for length of the s ECDSA param, but the easiest
     * way to testFuzz_ this is just to fuzz the permit variables and ensure it's invalid.
     * No need to aggressively bound v,r and s as they are designed to be resistant to brute force
     */
    function testFuzz_MalformedMessageWillNotFailSilently(
        uint128 _pk,
        address _spender,
        uint256 _deadline,
        uint256 _value,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        vm.assume(_pk > 0);
        vm.assume(_deadline > 0);
        // ignores 1 class of errors
        vm.assume(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0);
        address _user = vm.addr(_pk);

        // This should always fail - there are 2 error codes: ERC20Permit and the ECDSA Fail
        // ERC20 permit error will be when a non zero singer is returned, but it does not match the owner
        // ECDSA error will be when the ecrecover function fails
        // to avoid getting into the weeds, we just expect the below never to pass having constrained the class of errors
        vm.expectRevert();
        auxo.permit(_user, _spender, _value, _deadline, v, r, s);
    }
}
