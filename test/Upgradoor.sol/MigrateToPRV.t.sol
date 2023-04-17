// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorSetup} from "./Setup.sol";
import {console2} from "@forge-std/console2.sol";

contract TestAggregateToPRV is TestUpgradoorSetup {
    function setUp() public {
        prepareSetup();
    }

    function testPreviewaggregateToPRV() public {
        uint256 balanceXAuxoBefore = lsd.balanceOf(address(this));
        uint256 quote = UP.previewAggregateToPRV(address(this));
        UP.aggregateToPRV();
        uint256 balanceXAuxoAfter = lsd.balanceOf(address(this));
        assertEq(balanceXAuxoAfter - balanceXAuxoBefore, quote);
    }

    function testaggregateToPRV() public {
        // We can just check the entire balance since we only have one staker in the old system
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceXAuxoBefore = lsd.balanceOf(address(this));

        UP.aggregateToPRV();

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceXAuxoAfter = lsd.balanceOf(address(this));

        // Houston we have xAUXO
        assertEq(balanceXAuxoAfter > 0, true);

        //@dev Only true if there are Zero fees
        assertEq(balanceXAuxoAfter - balanceXAuxoBefore, UP.getRate(balanceDOUGHBefore));
    }

    function testaggregateToPRVAndStake() public {
        // We can just check the entire balance since we only have one staker in the old system
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));

        UP.aggregateToPRVAndStake();

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceXAuxoAfter = roll.getTotalBalanceForUser(address(this));

        // Houston we have xAUXO
        assertEq(balanceXAuxoAfter > 0, true);

        assertEq(balanceDOUGHAfter, 0);
        assertEq(lsd.balanceOf(address(roll)), UP.getRate(balanceDOUGHBefore));

        //@dev Only true if there are Zero fees
        assertEq(balanceXAuxoAfter, UP.getRate(balanceDOUGHBefore));
    }

    function testpreviewUpgradeSingleLockPRV() public {
        uint256 balanceXAuxoBefore = lsd.balanceOf(address(this));
        uint256 quote = UP.previewUpgradeSingleLockPRV(address(this));
        UP.upgradeSingleLockPRV(address(this));
        uint256 balanceXAuxoAfter = lsd.balanceOf(address(this));
        assertEq(quote, balanceXAuxoAfter - balanceXAuxoBefore);
    }

    function testupgradeSingleLockPRV() public {
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceXAuxoBefore = lsd.balanceOf(address(this));
        uint256 balanceAUXOBefore = auxo.totalSupply();

        UP.upgradeSingleLockPRV(address(this));

        uint256 balanceXAuxoAfter = lsd.balanceOf(address(this));

        // Houston we have xAUXO
        assertEq(balanceXAuxoAfter > 0, true);

        //@dev Only true if there are Zero fees
        assertEq(balanceXAuxoAfter - balanceXAuxoBefore, UP.getRate(LONGEST.amount));

        for (uint256 index = 1; index <= NUMLOCKS; index++) {
            UP.upgradeSingleLockPRV(address(this));
        }

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceAUXOAfter = auxo.totalSupply();
        balanceXAuxoAfter = lsd.balanceOf(address(this));

        // All dough are migrated
        assertEq(balanceDOUGHAfter, 0);

        // The same amount of migrated dough are minted in auxo
        assertEq(balanceAUXOAfter, balanceAUXOBefore + UP.getRate(balanceDOUGHBefore));

        // The same amount of migrated dough are minted in auxo
        assertEq(balanceXAuxoAfter, balanceXAuxoBefore + UP.getRate(balanceDOUGHBefore));
    }

    function testupgradeSingleLockPRVAndStake() public {
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        UP.upgradeSingleLockPRVAndStake(address(this));

        uint256 balanceXAuxoFirstDeposit = roll.getTotalBalanceForUser(address(this));

        // Houston we have xAUXO
        assertEq(balanceXAuxoFirstDeposit > 0, true);

        for (uint256 index = 1; index <= NUMLOCKS; index++) {
            UP.upgradeSingleLockPRVAndStake(address(this));
        }
        uint256 userStakedXAuxoBalance = roll.getTotalBalanceForUser(address(this));
        assertEq(userStakedXAuxoBalance, UP.getRate(balanceDOUGHBefore));
    }
}
