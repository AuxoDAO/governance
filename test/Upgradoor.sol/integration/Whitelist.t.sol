// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MockRewardsToken} from "@mocks/Token.sol";
import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import "@test/utils.sol";

contract MigrateWhitelist is TestUpgradoorIntegrationSetup {

    function setUp() public {
        prepareSetup();
    }

    function testRevertSingleLockARVIfNotWhitelistedSmartContract() public {
        // We create a new contract that should revert
        address _contract = address(new MockRewardsToken());

        vm.expectRevert(Errors.NOT_EOA_OR_WL);
        UP.upgradeSingleLockARV(_contract);

        tokenLocker.setWhitelisted(address(_contract), true);

        vm.expectRevert("Lock expired");
        UP.upgradeSingleLockARV(_contract);
    }

    /**
    * This test is just a reference: you can't prevent someone who is really determined from
    * using a CREATE2 setup to generate a deterministic address, send ARV to it during migration
    * then deploy a contract on top of it.
    * Because of this, just be mindful that we want to *avoid* non WL'd contracts but we can't avoid them completely
    */
    function testAttackSendToSmartContractWithCreate2(
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        address evil = address(0x6576696c);
        vm.label(evil, "EVIL");

        _initLocks(evil, _months, _amounts);

        bytes32 salt = keccak256(abi.encode("I AM EVIL"));
        bytes32 contractHash = keccak256(type(NewContract).creationCode);
        bytes32 create2ContractHash = keccak256(abi.encodePacked(bytes1(0xff), evil, salt, contractHash));
        address create2Contract = address(uint160(uint256(create2ContractHash)));

        vm.prank(evil);
        UP.upgradeSingleLockARV(create2Contract);

        vm.prank(evil);
        new NewContract{salt: salt}();

        uint veAUXOBalanceOfContract = veauxo.balanceOf(create2Contract);
        assertGt(veAUXOBalanceOfContract, 0); // :(
        NewContract(create2Contract).rugged();
    }
}

contract NewContract {
    bool public constant rugged = true;
    constructor() {}
}

