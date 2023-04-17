pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@prv/bitfield.sol";
import "../utils.sol";

contract TestBitfields is Test {
    using Bitfields for Bitfields.Bitfield;

    Bitfields.Bitfield internal claims;
    Bitfields.Bitfield internal empty;

    function testRepeatedActivationsAndDeactivationsAreIdempotent(uint8 _startEpoch, uint8 _leaveEpoch, uint8 _resumeEpoch) public {
        vm.assume(_startEpoch < type(uint8).max);
        // save value before we modify it
        uint savedClaims;
        claims = Bitfields.initialize(_startEpoch);

        // deactivate and save
        claims.deactivateFrom(_leaveEpoch);
        savedClaims = claims._value;

        // deactivate again
        claims.deactivateFrom(_leaveEpoch);
        assertEq(claims._value, savedClaims);

        // now try with activate
        claims.activateFrom(_resumeEpoch);
        savedClaims = claims._value;

        // activate again and check same result
        claims.activateFrom(_resumeEpoch);
        assertEq(claims._value, savedClaims);
    }


    /// @dev wanted to make sure changing the epoch locally in the pure function doesn't affect the passed in variable
    function testLastActiveDoesNotModifyLocalVariable(uint8 _startEpoch, uint8 _leaveEpoch, uint8 _currentEpoch) public {
        vm.assume(_startEpoch < type(uint8).max);
        claims = Bitfields.initialize(_startEpoch);
        claims.deactivateFrom(_leaveEpoch);
        // save the value
        uint8 currentEpochCache = _currentEpoch;
        // it'll get decremented within the scope of the function
        claims.lastActive(_currentEpoch);
        // but now it should be unchanged
        assertEq(_currentEpoch, currentEpochCache);
    }

    /// @dev ensure the library behaves consistently in terms of internal state
    function testBitFieldLib(uint8 _startEpoch, uint8 _leaveEpoch, uint8 _resumeEpoch) public {
        vm.assume(_startEpoch < type(uint8).max);
        uint8 maxEpochs = type(uint8).max;

        claims = Bitfields.initialize(_startEpoch);

        for (uint8 epoch; epoch < maxEpochs; epoch++) {
            bool shouldBeActive = epoch >= _startEpoch;
            assertEq(claims.isActive(epoch), shouldBeActive);
        }

        claims.deactivateFrom(_leaveEpoch);

        for (uint8 epoch; epoch < maxEpochs; epoch++) {
            bool shouldBeActive = (epoch >= _startEpoch && epoch < _leaveEpoch);
            assertEq(claims.isActive(epoch), shouldBeActive);
            // epoch > _leaveEpoch: we should definitely be deactivated
            if (epoch > _leaveEpoch) {
                assertEq(claims.isActive(epoch), false);
                // if leave epoch is after start epoch then we should have a last active epoch
                if (_startEpoch < _leaveEpoch) {
                    assertEq(claims.lastActive(epoch), _leaveEpoch - 1);
                // otherwise we never activated before we deactivated
                } else {
                    assertEq(claims.lastActive(epoch), 0);
                }
            }
        }

        claims.activateFrom(_resumeEpoch);

        for (uint8 epoch; epoch < maxEpochs; epoch++) {
            // we will be active for all epochs after the resume epoch
            if (epoch >= _resumeEpoch) assertEq(claims.isActive(epoch), true);
            // we should also be active for all epochs between the start and leave epochs
            if (epoch >= _startEpoch && epoch < _leaveEpoch) {
            // but only if leave is after start
                if (_startEpoch < _leaveEpoch) {
                    assertEq(claims.isActive(epoch), true);
                }
            }
            // otherwise we will be inactive
            if (epoch < _resumeEpoch && epoch >= _leaveEpoch) {
                assertEq(claims.isActive(epoch), false);
                // for inactive epochs, we should have a last active epoch
                // we are before the resume epoch, so assuming leave is after start
                // last active will be just before the leave epoch
                if (_startEpoch < _leaveEpoch) {
                    assertEq(claims.lastActive(epoch), _leaveEpoch - 1);
                } else {
                    // if we are inactive before we ever activated, then we should have last active epoch 0
                    assertEq(claims.lastActive(epoch), 0);
                }
            }
        }
    }

}
