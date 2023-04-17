pragma solidity 0.8.16;

import "@forge-std/Script.sol";
import {TokenLocker} from "@governance/TokenLocker.sol";
import {Auxo} from "src/AUXO.sol";

contract DepositFor is Script {
    address[] internal recipients;
	// 0xd18a54f89603fe4301b29ef6a8ab11b9ba24f139
	// 0x0810c422e4abd05c752618b403d26cf60bb50b5c
	// 0x3c41e06d85f7fde123d311672ad14b8c70a5e815
	// 0x43079513ebd84afb15be79021c420fe8055bc635
	// 0xb4adb7794432dae7e78c2258ff350fba88250c32
    function run() public {
        // fuji
        TokenLocker locker = TokenLocker(0x9B693Fa603cB036bc73afB136A341c46e23CBc0b);
        Auxo auxo = Auxo(0x439aE4Cf3f753b81BC2B00B24e66423497070ee7);
        recipients = [
            0xBaFC9B585661E6DCf3d5fA6990bA3892a9cF24b2
            // 0x0810C422E4abD05c752618B403d26cf60bB50B5C,
            // 0x3c41E06D85F7FDE123d311672ad14B8c70A5E815,
            // 0x43079513eBD84AFb15BE79021C420Fe8055Bc635,
            // 0xB4ADB7794432dAE7E78C2258fF350fBA88250C32
        ];
        address me = vm.addr(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(me);
        // auxo.approve(address(locker), type(uint256).max);
        locker.setWhitelisted(me, true);
        for (uint i = 0; i < recipients.length; i++) {
            locker.depositByMonths(1000 ether, 36, recipients[i]);
        }
        vm.stopBroadcast();
    }
}
