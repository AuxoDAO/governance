// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";

contract TestMigrateSingleLockARV is TestUpgradoorIntegrationSetup {
    struct BalancesPreVeAuxo {
        uint256 tokenLockerAuxoBalance;
        uint256 upgradoorDoughBalance;
        uint256 depositorVeDoughBalance;
    }

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    function testFuzz_SingleLockVeAuxoNoExpiry(
        address _depositor,
        address[LOCKS_PER_USER] memory _receivers,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts
    ) public {
        _initLocks(_depositor, _months, _amounts);
        SharesTimeLock.Lock[] memory locks = OLD.getLocks(_depositor);

        for (uint256 i; i < locks.length; i++) {
            address _receiver = _receivers[i];
            _receiver = _getValidReceiver(_receiver, _depositor, i);

            (,,, uint256 nextLongestLockIndex) = UP.getNextLongestLock(_depositor);
            SharesTimeLock.Lock memory lock = locks[nextLongestLockIndex];

            uint256 preview = UP.previewUpgradeSingleLockARV(_depositor, _receiver);
            uint256 expected = _calculateVeAuxo(lock);
            assertEq(expected, preview);

            BalancesPreVeAuxo memory balances = BalancesPreVeAuxo({
                tokenLockerAuxoBalance: auxo.balanceOf(address(tokenLocker)),
                upgradoorDoughBalance: mockDOUGH.balanceOf(address(UP)),
                depositorVeDoughBalance: veDOUGH.balanceOf(_depositor)
            });

            vm.prank(_depositor);
            UP.upgradeSingleLockARV(_receiver);

            assertEq(auxo.balanceOf(address(tokenLocker)), balances.tokenLockerAuxoBalance + lock.amount / 100);
            assertEq(veauxo.balanceOf(_receiver), preview);
            assertEq(mockDOUGH.balanceOf(address(UP)), balances.upgradoorDoughBalance + lock.amount);
            assertLt(veDOUGH.balanceOf(_depositor), balances.depositorVeDoughBalance);
        }
    }
}
