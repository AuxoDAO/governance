// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@oz/utils/Strings.sol";

import {Auxo} from "@src/AUXO.sol";
import {EIP712HashBuilder} from "../utils.sol";

/**
 * @notice this is a basic set of tests for the behaviours we want to see with AUXO and veAUXO
 */

contract TestAuxoSetup is Test {
    // NOTE: extended Auxo with crypto utils
    Auxo public auxo;

    function prepareSetup() public {
        auxo = new Auxo();
    }
}
