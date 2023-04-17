// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@oz/utils/Strings.sol";

import {ARV} from "@src/ARV.sol";
import {EIP712HashBuilder} from "../utils.sol";

/**
 * @notice this is a basic set of tests for the behaviours we want to see with AUXO and veAUXO
 */

contract TestARVSetup is Test {
    // NOTE: extended veAuxo with crypto utils
    ARV public veAuxo;
    address public locker = vm.addr(0x1234567);

    function prepareSetup() public {
        veAuxo = new ARV(locker);
    }
}
