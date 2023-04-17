pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV} from "@prv/PRV.sol";
import {PRVRouter} from "@prv/PRVRouter.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {RollStaker} from "@prv/RollStaker.sol";

import {PRVTestBase} from "./PRVBase.t.sol";
import "../utils.sol";

contract PRVTestRouter is PRVTestBase {
    using IsEOA for address;

    PRVRouter public router;
    RollStaker public roll;

    function setUp() public override {
        super.setUp();
        roll = _deployRollStaker(address(prv));
        router = new PRVRouter(address(deposit), address(prv), address(roll));
    }

    function testFuzz_CanConvertAndStakeWithFee(address _converter, uint120 _amount, uint _fee, address _feeBeneficiary) external notAdmin(_converter) {
        vm.assume(_amount > 0);
        vm.assume(_converter != address(0));
        vm.assume(_feeBeneficiary != address(0));
        vm.assume(_fee <= prv.MAX_FEE());

        vm.prank(prv.governor());
        prv.setFeePolicy(_fee, _feeBeneficiary);

        deposit.transfer(_converter, _amount);

        vm.startPrank(_converter);
        deposit.approve(address(router), _amount);
        router.convertAndStake(_amount);

        // assertEq(roll.getTotalBalanceForUser(_converter), prv.previewDeposit(_amount));
        assertEq(deposit.balanceOf(_converter), 0);
        assertEq(deposit.balanceOf(address(router)), 0);
    }

    function testFuzz_CanConvertAndStake(address _converter, uint120 _amount) external notAdmin(_converter) {
        vm.assume(_amount > 0);
        vm.assume(_converter != address(0));

        deposit.transfer(_converter, _amount);

        vm.startPrank(_converter);
        deposit.approve(address(router), _amount);
        router.convertAndStake(_amount);

        assertEq(roll.getTotalBalanceForUser(_converter), _amount);
        assertEq(deposit.balanceOf(_converter), 0);
        assertEq(deposit.balanceOf(address(router)), 0);
    }

    function testFuzz_CanConvertAndStakeWithReceiver(address _converter, address _receiver, uint120 _amount)
        external
        notAdmin(_receiver)
        notAdmin(_converter)
    {
        vm.assume(_amount > 0);
        vm.assume(_converter != address(0));

        deposit.transfer(_converter, _amount);

        vm.startPrank(_converter);
        deposit.approve(address(router), _amount);
        router.convertAndStake(_amount, _receiver);

        assertEq(roll.getTotalBalanceForUser(_receiver), _amount);
        assertEq(deposit.balanceOf(_converter), 0);
        assertEq(deposit.balanceOf(address(router)), 0);
    }

    function testFuzz_convertAndStakeWithSignatureValid(
        uint128 _spenderPk,
        address _recipient,
        uint120 _amount,
        uint256 _deadline
    ) external notAdmin(_recipient) {
        vm.assume(_spenderPk > 0);
        vm.assume(_deadline > 0);
        vm.assume(_amount > 0);
        vm.assume(_recipient != address(0));
        address spender = vm.addr(_spenderPk);
        vm.assume(!isAdmin(spender));

        bytes32 permitMessage =
            EIP712HashBuilder.generateTypeHashPermit(spender, address(router), _amount, _deadline, deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_spenderPk, permitMessage);

        deposit.transfer(spender, _amount);

        vm.prank(spender);
        router.convertAndStakeWithSignature(_amount, _recipient, _deadline, v, r, s);
        assertEq(roll.getTotalBalanceForUser(_recipient), _amount);
        assertEq(deposit.balanceOf(spender), 0);
        assertEq(deposit.balanceOf(address(router)), 0);
    }

    function testFuzz_convertAndStakeWithSignatureInValid(
        uint128 _spenderPk,
        address _recipient,
        uint120 _amount,
        uint256 _deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external notAdmin(_recipient) {
        vm.assume(_spenderPk > 0);
        vm.assume(_deadline > 0);
        vm.assume(_amount > 0);
        vm.assume(_recipient != address(0));

        address spender = vm.addr(_spenderPk);
        vm.assume(!isAdmin(spender));

        deposit.transfer(spender, _amount);

        vm.prank(spender);
        vm.expectRevert();
        router.convertAndStakeWithSignature(_amount, _recipient, _deadline, v, r, s);
    }
}
