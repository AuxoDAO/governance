// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {MockRewardsToken} from "../mocks/Token.sol";
import {SharesTimeLockMock} from "../mocks/SharesTimeLockMock.sol";
import {RollStaker} from "@prv/RollStaker.sol";
import {PRVRouter} from "@prv/PRVRouter.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

contract TestUpgradoorSetup is Test, UpgradeDeployer {
    uint32 public constant AVG_SECONDS_MONTH = 2628000;

    // Setup system
    TokenLocker public tokenLocker;
    ARV public veauxo;
    Auxo public auxo;
    PRV public lsd;
    MockRewardsToken public veDOUGH;
    PRVRouter public router;
    RollStaker roll;
    address GOV = address(1);
    bool LONG_ON = true;

    MockRewardsToken mockDOUGH = new MockRewardsToken();

    // Upgrador
    Upgradoor public UP;
    SharesTimeLockMock public OLD;
    uint256 mainnetFork;

    struct Lock {
        uint256 amount;
        uint32 lockedAt;
        uint32 lockDuration;
    }

    // Time the old lock was deployed
    Lock SHORTER = Lock({amount: 1 ether, lockedAt: 1631434044, lockDuration: 6 * AVG_SECONDS_MONTH});
    Lock MIDDLE = Lock({amount: 1 ether, lockedAt: 1631434044, lockDuration: 12 * AVG_SECONDS_MONTH});
    Lock LONGEST = Lock({amount: 1 ether, lockedAt: 1631434044, lockDuration: 24 * AVG_SECONDS_MONTH});

    uint8 NUMLOCKS = 30;

    function prepareSetup() public {
        // Mock veDOUGH
        veDOUGH = new MockRewardsToken();

        // instantiate a fresh proxy and admin
        // setup the auxo and veauxo tokens
        auxo = new Auxo();
        auxo.mint(address(this), 100000 ether);
        tokenLocker = _deployLockerUninitialized();
        veauxo = new ARV(address(tokenLocker));

        tokenLocker.initialize(
            auxo, IERC20MintableBurnable(address(veauxo)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 0.0001 ether
        );

        lsd = _deployPRV(address(auxo));
        auxo.approve(address(lsd), 1 ether);

        roll = _deployRollStaker(address(lsd));
        router = new PRVRouter(address(auxo), address(lsd), address(roll));

        // ---- Setting Upgrador ------

        // Deploy old timelock
        OLD = new SharesTimeLockMock(address(mockDOUGH));
        // Deploy upgradoor
        UP =
        new Upgradoor(address(OLD), address(auxo), address(mockDOUGH), address(tokenLocker), address(lsd), address(veDOUGH), address(router));

        // Set the migrator on the old timelock
        OLD.setMigrator(address(UP));

        // We whitelist the Upgradoor contract to auxo on the tokenlocker
        tokenLocker.setWhitelisted(address(UP), true);

        // We also allow this address permission to receive tokens
        tokenLocker.setWhitelisted(address(this), true);

        //We give minting role to the Upgradoor
        auxo.grantRole(auxo.MINTER_ROLE(), address(UP));

        uint256 total = 0;
        for (uint256 index = 0; index <= NUMLOCKS; index++) {
            if (index == 0) {
                OLD.add(SHORTER.amount, SHORTER.lockedAt, SHORTER.lockDuration);
                total += SHORTER.amount;
            } else if (index == NUMLOCKS) {
                OLD.add(LONGEST.amount, LONGEST.lockedAt, LONGEST.lockDuration);
                total += LONGEST.amount;
            } else {
                OLD.add(MIDDLE.amount, MIDDLE.lockedAt, MIDDLE.lockDuration);
                total += MIDDLE.amount;
            }
        }

        // We mint the total amount in the OLD tokenlock
        mockDOUGH.mint(address(OLD), total);

        // Warping to the first stake
        vm.warp(1631434044);
    }

    function _progressiveAddress(uint256 nonce) internal pure returns (address) {
        return address(uint160(uint256(nonce)));
    }
}
