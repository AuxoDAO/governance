// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {TestUpgradoorIntegrationSetup} from "./Setup.t.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import "../../utils.sol";

contract PreviewSingleLock is TestUpgradoorIntegrationSetup {
    using IsEOA for address;

    struct BalancesPreXAuxo {
        uint256 tokenLockerAuxoBalance;
        uint256 upgradoorDoughBalance;
        uint256 receiverXAuxoBalance;
        uint256 depositorVeDoughBalance;
    }

    struct BalancesPreVeAuxo {
        uint256 tokenLockerAuxoBalance;
        uint256 upgradoorDoughBalance;
        uint256 depositorVeDoughBalance;
    }

    function setUp() public {
        prepareSetup();
    }

    /// ======= FUZZ ======
    function testFuzz_PreviewSingleLockXAuxoNoExpiry(
        address _depositor,
        address[LOCKS_PER_USER] memory _receivers,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary
    ) public {
        _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);
        _initLocks(_depositor, _months, _amounts);
        SharesTimeLock.Lock[] memory locks = OLD.getLocks(_depositor);

        for (uint256 i; i < locks.length; i++) {
            address _receiver = _receivers[i];
            vm.assume(_receiver.isEOA());

            SharesTimeLock.Lock memory lock;
            {
                (,,, uint256 nextLongestLockIndex) = UP.getNextLongestLock(_depositor);
                lock = locks[nextLongestLockIndex];
            }

            uint256 expected = lock.amount/100;
            {
                uint256 preview = UP.previewUpgradeSingleLockPRV(_depositor);
                assertEq(expected, preview);
            }

            // need to collect this into a struct to avoid stack depth errors
            BalancesPreXAuxo memory balances = BalancesPreXAuxo({
                tokenLockerAuxoBalance: auxo.balanceOf(address(tokenLocker)),
                receiverXAuxoBalance: lsd.balanceOf(_receiver),
                upgradoorDoughBalance: mockDOUGH.balanceOf(address(UP)),
                depositorVeDoughBalance: veDOUGH.balanceOf(_depositor)
            });

            vm.prank(_depositor);
            UP.upgradeSingleLockPRV(_receiver);

            assertEq(auxo.balanceOf(address(tokenLocker)), balances.tokenLockerAuxoBalance);
            assertEq(veauxo.balanceOf(_receiver), 0);
            assertEq(mockDOUGH.balanceOf(address(UP)), balances.upgradoorDoughBalance + lock.amount);
            assertEq(lsd.balanceOf(_receiver), balances.receiverXAuxoBalance + expected);
            assertLt(veDOUGH.balanceOf(_depositor), balances.depositorVeDoughBalance);
        }
    }

    /**
     * @dev kitchen sink test
     *      Goes through and randomly tests combos of xAuxo, veAuxo, receivers at various times
     * @param _choices array of booleans deciding whether to move the lock to ve or x auxo
     */
    function testFuzz_PreviewSingleLockVeAndXAuxoWithExpiry(
        address _depositor,
        address[LOCKS_PER_USER] memory _receivers,
        uint8[LOCKS_PER_USER] memory _months,
        uint128[LOCKS_PER_USER] memory _amounts,
        bool[LOCKS_PER_USER] memory _choices,
        uint256 _xAuxoEntryFee,
        address _feeBeneficiary,
        uint64 _fastForward
    ) public {
        _initXAuxo(_xAuxoEntryFee, _feeBeneficiary);
        _initLocks(_depositor, _months, _amounts);
        _warpTo(_fastForward);

        (,,, uint256 numberOfValidLocks) = _getLongestValidLock(_depositor);

        for (uint256 i; i < numberOfValidLocks; i++) {
            SharesTimeLock.Lock memory lock = _getNextLongestLockAsLock(_depositor);

            if (_choices[i] == true) {
                _receivers[i] = _getValidReceiver(_receivers[i], _depositor, i);

                BalancesPreVeAuxo memory balances = BalancesPreVeAuxo({
                    tokenLockerAuxoBalance: auxo.balanceOf(address(tokenLocker)),
                    upgradoorDoughBalance: mockDOUGH.balanceOf(address(UP)),
                    depositorVeDoughBalance: veDOUGH.balanceOf(_depositor)
                });

                vm.prank(_depositor);
                if (numberOfValidLocks == 0) vm.expectRevert("Lock Expired");
                UP.upgradeSingleLockARV(_receivers[i]);

                assertEq(auxo.balanceOf(address(tokenLocker)), balances.tokenLockerAuxoBalance + lock.amount / 100);
                assertEq(veauxo.balanceOf(_receivers[i]), _calculateVeAuxo(lock));
                assertEq(mockDOUGH.balanceOf(address(UP)), balances.upgradoorDoughBalance + lock.amount);
                assertLt(veDOUGH.balanceOf(_depositor), balances.depositorVeDoughBalance);
            } else {
                vm.assume(_receivers[i].isEOA());

                BalancesPreXAuxo memory balances = BalancesPreXAuxo({
                    tokenLockerAuxoBalance: auxo.balanceOf(address(tokenLocker)),
                    receiverXAuxoBalance: lsd.balanceOf(_receivers[i]),
                    upgradoorDoughBalance: mockDOUGH.balanceOf(address(UP)),
                    depositorVeDoughBalance: veDOUGH.balanceOf(_depositor)
                });

                vm.prank(_depositor);
                if (numberOfValidLocks == 0) vm.expectRevert("SharesTimeLockMock: Lock expired");
                UP.upgradeSingleLockPRV(_receivers[i]);

                uint256 expected = lock.amount/100;

                assertEq(auxo.balanceOf(address(tokenLocker)), balances.tokenLockerAuxoBalance);
                assertEq(veauxo.balanceOf(_receivers[i]), 0);
                assertEq(mockDOUGH.balanceOf(address(UP)), balances.upgradoorDoughBalance + lock.amount);
                assertEq(lsd.balanceOf(_receivers[i]), balances.receiverXAuxoBalance + expected);
                assertLt(veDOUGH.balanceOf(_depositor), balances.depositorVeDoughBalance);
            }
        }
    }
}
