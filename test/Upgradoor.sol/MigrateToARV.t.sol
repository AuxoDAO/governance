// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MockRewardsToken} from "../mocks/Token.sol";
import {TestUpgradoorSetup} from "./Setup.sol";

contract MigrateToARV is TestUpgradoorSetup {
    function setUp() public {
        prepareSetup();
    }

    function testPreviewupgradeSingleLockARV() public {
        uint256 quote = UP.previewUpgradeSingleLockARV(address(this), address(this));
        uint256 balanceVeAUXOBefore = veauxo.balanceOf(address(this));
        UP.upgradeSingleLockARV(address(this));
        uint256 balanceVeAUXOAfter = veauxo.balanceOf(address(this));
        assertEq(quote, balanceVeAUXOAfter);
    }

    function testUpgradeFailIfReceiverHasVeDOUGH() public {
        veDOUGH.mint(address(420), 1 ether);

        vm.expectRevert("Invalid receiver");
        UP.upgradeSingleLockARV(address(420));
    }

    function testupgradeSingleLockARV() public {
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceAUXOBefore = auxo.totalSupply();

        uint256 prevBlocktime = block.timestamp;

        /// It will revert with expired locks
        vm.warp(block.timestamp + AVG_SECONDS_MONTH * 25);
        vm.expectRevert("Lock expired");
        UP.upgradeSingleLockARV(address(this));

        /// It will succeed with a not expired lock
        // We warp then 5 month from prevBlocktime
        vm.warp(prevBlocktime + AVG_SECONDS_MONTH * 5);

        UP.upgradeSingleLockARV(address(this));

        // Houston we have lock
        assertEq(tokenLocker.hasLock(address(this)), true);

        (,, uint256 newLockDuration) = tokenLocker.lockOf(address(this));

        // LONGEST was 24 months
        // 24 - 5 we warper = 19 months
        assertEq(newLockDuration, AVG_SECONDS_MONTH * 19);

        /// It will fail if a lock exists
        vm.expectRevert("Lock exist");
        UP.upgradeSingleLockARV(address(this));

        /// It will migrate all remaing locks successfully
        for (uint256 index = 1; index <= NUMLOCKS; index++) {
            // We just generate a bunch of random addresses
            address rando = _progressiveAddress(index);
            UP.upgradeSingleLockARV(rando);
        }

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceAUXOAfter = auxo.totalSupply();

        // All dough are migrated
        assertEq(balanceDOUGHAfter, 0);

        // The same amount of migrated dough are minted in auxo
        assertEq(balanceAUXOAfter, balanceAUXOBefore + UP.getRate(balanceDOUGHBefore));
    }

    function testpreviewAggregateARV() public {
        uint256 quote = UP.previewAggregateARV(address(this));
        uint256 balanceVeAUXOBefore = veauxo.balanceOf(address(this));
        UP.aggregateToARV();
        uint256 balanceVeAUXOAfter = veauxo.balanceOf(address(this));
        assertEq(balanceVeAUXOAfter, quote);
    }

    /// @dev we are not testing the amounts
    /// because we know them to be working based on other tests
    /// what we really care is making sure that the new lock has the right duration
    /// we also don't check if the function reverts if a previous lock exists
    /// otherwise we are basically replicating tests all the time
    function testaggregateToARV() public {
        // We can just check the entire balance since we only have one staker in the old system
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceAUXOBefore = auxo.totalSupply();

        UP.aggregateToARV();

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceAUXOAfter = auxo.totalSupply();

        // Houston we have lock
        assertEq(tokenLocker.hasLock(address(this)), true);

        (,, uint256 newLockDuration) = tokenLocker.lockOf(address(this));
        assertEq(newLockDuration, LONGEST.lockDuration);
        // All dough are migrated
        assertEq(balanceDOUGHAfter, 0);

        // The same amount of migrated dough are minted in auxo
        assertEq(balanceAUXOAfter, balanceAUXOBefore + UP.getRate(balanceDOUGHBefore));
    }

    function testPreviewAggregateAndBoost() public {
        uint256 quote = UP.previewAggregateAndBoost(address(this));
        UP.aggregateAndBoost();
        uint256 balanceVeAUXOAfter = veauxo.balanceOf(address(this));

        assertEq(balanceVeAUXOAfter, quote);
    }

    function testAggregateAndBoost() public {
        // We can just check the entire balance since we only have one staker in the old system
        uint256 balanceDOUGHBefore = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceVeAUXOBefore = veauxo.balanceOf(address(this));
        uint256 balanceAUXOBefore = auxo.totalSupply();

        UP.aggregateAndBoost();

        uint256 balanceDOUGHAfter = mockDOUGH.balanceOf(address(OLD));
        uint256 balanceVeAUXOAfter = veauxo.balanceOf(address(this));
        uint256 balanceAUXOAfter = auxo.totalSupply();

        // Houston we have lock
        assertEq(tokenLocker.hasLock(address(this)), true);

        // All dough are migrated
        assertEq(balanceDOUGHAfter, 0);

        // The same amount of migrated dough are minted in auxo
        assertEq(balanceAUXOAfter, balanceAUXOBefore + UP.getRate(balanceDOUGHBefore));

        // Since we are boosting we get a 1:1 ration, we need to have the same amounts
        assertEq(balanceVeAUXOAfter, UP.getRate(balanceDOUGHBefore) - balanceVeAUXOBefore);
    }
}
