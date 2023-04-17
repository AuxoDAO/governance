// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import "@forge-std/StdJson.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Upgradoor} from "@bridge/Upgradoor.sol";
import {PRV} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {RollStaker} from "@prv/RollStaker.sol";
import {PRVRouter} from "@prv/PRVRouter.sol";
import {SharesTimeLock} from "@bridge/SharesTimeLock.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

interface PProxy {
    function getProxyOwner() external view returns (address);
    function getImplementation() external view returns (address);
    function setImplementation(address _newImplementation) external;
}

contract TestUpgradoorFork is Test, UpgradeDeployer {
    using stdJson for string;

    uint32 internal constant AVG_SECONDS_MONTH = 2628000;

    // Setup system
    TokenLocker private tokenLocker;
    ARV private veauxo;
    Auxo private auxo;
    PRV private lsd;
    ERC20 private veDOUGH;
    PRVRouter public router;
    RollStaker roll;

    address GOV = address(1);
    address FEE_BENEFICIARY = address(420);
    bool LONG_ON = true;

    // Upgrador
    Upgradoor private UP;
    SharesTimeLock private OLD;
    address payable oldTimelock = payable(0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45);
    address dough = 0xad32A8e6220741182940c5aBF610bDE99E737b2D;
    address MULTISIG = 0x6458A23B020f489651f2777Bd849ddEd34DfCcd2;

    uint8 NUMLOCKS = 30;

    uint256 constant TESTING_BLOCK_NUMBER = 16076347;
    /// @dev set
    uint256 constant HOLDERS_TO_TEST = 335;

    address[] holders;
    address[] ejectable;
    uint256[] ids;

    function setUp() public {
        uint256 forkId = vm.createFork("https://rpc.ankr.com/eth", TESTING_BLOCK_NUMBER);
        vm.selectFork(forkId);
        assertEq(block.number, TESTING_BLOCK_NUMBER);
        console2.log("[FORKING] Archive Block %d", TESTING_BLOCK_NUMBER);

        // Mock veDOUGH
        veDOUGH = new ERC20("veDOUGHmock", "veDOUGHmock");

        // Reads the entire content of file to string, (path) => (data)
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fork/holders.json");
        string memory file = vm.readFile(path);
        holders = file.readAddressArray("holders");

        // setup the auxo and veauxo tokens
        auxo = new Auxo();
        auxo.mint(address(this), 100000 ether);
        veauxo = new ARV(address(tokenLocker));

        // initialize
        tokenLocker = _deployLocker(
            auxo, IERC20MintableBurnable(address(veauxo)), AVG_SECONDS_MONTH * 6, AVG_SECONDS_MONTH * 36, 0.0001 ether
        );

        lsd = _deployPRV(address(auxo));

        roll = _deployRollStaker(address(lsd));
        router = new PRVRouter(address(auxo), address(lsd), address(roll));

        // ---- Setting Upgrador ------

        // Deploy old timelock
        OLD = SharesTimeLock(oldTimelock);

        // Deploy upgradoor
        UP =
        new Upgradoor(oldTimelock, address(auxo), address(OLD.depositToken()), address(tokenLocker), address(lsd), address(veDOUGH), address(router));

        // We whitelist the Upgradoor contract to auxo on the tokenlocker
        tokenLocker.setWhitelisted(address(UP), true);

        //We give minting role to the Upgradoor
        auxo.grantRole(auxo.MINTER_ROLE(), address(UP));

        // ---- Update implementation ----
        SharesTimeLock stImpl = new SharesTimeLock();
        PProxy stProxy = PProxy(oldTimelock);

        vm.startPrank(MULTISIG);
        stProxy.setImplementation(address(stImpl));
        OLD.setMigrationON();
        OLD.setMigratoor(address(UP));
        vm.stopPrank();
        // ---- END Update implementation ----

        // ---- We are gonna eject everyoneee ----
        console2.log("Testing %d / %d Holders", HOLDERS_TO_TEST, holders.length);
        for (uint256 i = 0; i < HOLDERS_TO_TEST; i++) {
            address checksumed = address(holders[i]);

            uint256 numLocks = OLD.getLocksOfLength(checksumed);
            for (uint256 j = 0; j < numLocks; j++) {
                if (OLD.canEject(checksumed, j)) {
                    ejectable.push(checksumed);
                    ids.push(j);
                }
            }
        }

        // OLD.eject(ejectable, ids);
        // //OLD.ejectNOW(0x0ccA4E5FD4f2Ec0beC7B246e1D1865524A49e1b9, 0);
        // // ejectable.push(0x0ccA4E5FD4f2Ec0beC7B246e1D1865524A49e1b9);
        // // ids.push(0);
        // // OLD.eject(ejectable, ids);
        // uint256 prevBalance = IERC20(OLD.rewardsToken()).balanceOf(address(0x0ccA4E5FD4f2Ec0beC7B246e1D1865524A49e1b9));
        // console.log(prevBalance);
    }

    function testReverUserAllExpiredLocks() public {
        address user = 0x0ccA4E5FD4f2Ec0beC7B246e1D1865524A49e1b9;
        uint256 prevBalance = IERC20(OLD.rewardsToken()).balanceOf(address(user));
        uint256 balanceBefore = veauxo.totalSupply();

        vm.prank(user);
        vm.expectRevert("SharesTimeLockMock: Lock expired");
        UP.aggregateAndBoost();
    }

    function testUserDump() public {
        address user = 0x89d2D4934ee4F1f579056418e6aeb136Ee919d65;
        uint256 prevBalance = IERC20(OLD.rewardsToken()).balanceOf(address(user));
        uint256 balanceBefore = veauxo.totalSupply();

        vm.prank(user);
        UP.aggregateAndBoost();

        uint256 postBalance = IERC20(OLD.rewardsToken()).balanceOf(address(user));
        uint256 balanceAfter = veauxo.totalSupply();

        console.log("Prev veDOUGH balance", prevBalance / 1e18);
        console.log("Post veDOUGH balance", postBalance / 1e18);

        console.log("veAUXO Balance before:", balanceBefore / 1e18);
        console.log("veAUXO Balance after:", balanceAfter / 1e18);
    }

    function testEverybodyAggregatesAndBoost() public {
        uint256 totalEjectable = 0;
        uint256 prevBalance = IERC20(dough).balanceOf(address(OLD));
        for (uint256 index = 0; index < HOLDERS_TO_TEST; index++) {
            vm.startPrank(holders[index]);
            try UP.aggregateAndBoost() {}
            catch Error(string memory reason) {
                uint256 balanceRug = IERC20(OLD.rewardsToken()).balanceOf(holders[index]);
                totalEjectable += balanceRug;
                console2.log("Error with holder %s, balance: %d\n%s", holders[index], balanceRug / 1e18, reason);
            }
            vm.stopPrank();
        }
        uint256 postBalance = IERC20(dough).balanceOf(address(OLD));
        uint256 balanceAfter = veauxo.totalSupply();

        console.log("Prev DOUGH balance", prevBalance / 1e18);
        console.log("Post DOUGH balance", postBalance / 1e18);
        console.log("Tot veDOUGH ejectable:", totalEjectable / 1e18);
        console.log("veAUXO Balance after:", balanceAfter / 1e18);
    }

    function testEverybodyaggregateToARV() public {
        uint256 prevBalance = IERC20(dough).balanceOf(address(OLD));
        for (uint256 index = 0; index < HOLDERS_TO_TEST; index++) {
            vm.startPrank(holders[index]);
            try UP.aggregateToARV() {}
            catch Error(string memory reason) {
                uint256 balanceRug = IERC20(OLD.rewardsToken()).balanceOf(holders[index]);
                console2.log("Error with holder %s, balance: %d\n%s", holders[index], balanceRug / 1e18, reason);
            }
            vm.stopPrank();
        }
        uint256 postBalance = IERC20(dough).balanceOf(address(OLD));
        uint256 balanceAfter = veauxo.totalSupply();

        console.log("Prev DOUGH balance", prevBalance / 1e18);
        console.log("Post DOUGH balance", postBalance / 1e18);
        console.log("veAUXO Balance after:", balanceAfter / 1e18);
    }

    function testEverybodyaggregateToPRV() public {
        uint256 prevBalance = IERC20(dough).balanceOf(address(OLD));
        for (uint256 index = 0; index < HOLDERS_TO_TEST; index++) {
            vm.startPrank(holders[index]);
            try UP.aggregateToPRV() {}
            catch Error(string memory reason) {
                uint256 balanceRug = IERC20(OLD.rewardsToken()).balanceOf(holders[index]);
                console2.log("Error with holder %s, balance: %d\n%s", holders[index], balanceRug / 1e18, reason);
            }
            vm.stopPrank();
        }
        uint256 postBalance = IERC20(dough).balanceOf(address(OLD));
        uint256 balanceAfter = lsd.totalSupply();

        console.log("Prev DOUGH balance", prevBalance / 1e18);
        console.log("Post DOUGH balance", postBalance / 1e18);
        console.log("xAUXO Balance after:", balanceAfter / 1e18);
    }

    // // function testEverybodyupgradeSingleLockARV() public {}
    // // function testEverybodyupgradeSingleLockPRV() public {}
}
