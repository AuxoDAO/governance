pragma solidity 0.8.16;

import "@forge-std/Test.sol";
import {PRV, IPRVEvents} from "@prv/PRV.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";

import {PProxy as Proxy} from "@pproxy/PProxy.sol";
import {TokenLocker, IERC20MintableBurnable, ITokenLockerEvents} from "@governance/TokenLocker.sol";
import {Auxo} from "@src/AUXO.sol";
import {ARV} from "@src/ARV.sol";
import {UpgradeDeployer} from "@test/UpgradeDeployer.sol";

import "../utils.sol";
import {PRVTestBase, MockPRV} from "./PRVBase.t.sol";

contract MockPRVWithdrawalVerifier {
    bool private pass = false;

    function setPass(bool _pass) external {
        pass = _pass;
    }

    function verify(uint256, address, bytes calldata) external view returns (bool) {
        return pass;
    }
}

contract PRVTestCore is PRVTestBase {
    using IsEOA for address;

    function setUp() public virtual override {
        super.setUp();
        // these tests just test the PRV logic
        prv.setWithdrawalManager(address(0));
    }

    function testInitialState(address _auxo, address _governor, uint256 _entryFee, address _feeBeneficiary, address _withdrawalManager) external {
        vm.assume(_governor != address(0));
        vm.assume(_auxo != address(0));
        vm.assume(_entryFee <= prv.MAX_FEE());

        Proxy proxy = new Proxy();
        PRV impl = new PRV();
        proxy.setImplementation(address(impl));
        PRV newPRV = PRV(address(proxy));
        newPRV.initialize(_auxo, _entryFee, _feeBeneficiary, _governor, _withdrawalManager);

        assertEq(newPRV.AUXO(), _auxo);
        assertEq(newPRV.governor(), _governor);
        assertEq(newPRV.fee(), _entryFee);
        assertEq(newPRV.feeBeneficiary(), _feeBeneficiary);
    }

    function testInitialStateReverts(address _auxo, address _governor, uint256 _entryFee, address _feeBeneficiary, address _withdrawalManager)
        external
    {
        vm.assume(_governor != address(0));
        vm.assume(_auxo != address(0));
        vm.assume(_entryFee <= prv.MAX_FEE());

        Proxy proxy = new Proxy();
        PRV impl = new PRV();
        proxy.setImplementation(address(impl));
        PRV newPRV = PRV(address(proxy));

        vm.expectRevert("AUXO:ZERO_ADDR");
        newPRV.initialize(address(0), _entryFee, _feeBeneficiary, _governor, _withdrawalManager);

        vm.expectRevert("GV:ZERO_ADDR");
        newPRV.initialize(_auxo, _entryFee, _feeBeneficiary, address(0), _withdrawalManager);

        uint256 fee = prv.MAX_FEE() + 1;
        vm.expectRevert("FEE TOO BIG");
        newPRV.initialize(_auxo, fee, _feeBeneficiary, _governor, _withdrawalManager);
    }

    function testSetFeeBeneficiary(address _someLuckyGuy) external {
        vm.assume(_someLuckyGuy != address(0));

        vm.expectEmit(true, false, false, true);
        emit FeeBeneficiarySet(_someLuckyGuy);
        prv.setFeeBeneficiary(_someLuckyGuy);

        assertEq(prv.feeBeneficiary(), _someLuckyGuy);
    }

    function testSetFeeBeneficiaryRevertsZeroAddr() external {
        address _someLuckyGuy = address(0);
        vm.expectRevert("ZERO_ADDR");
        prv.setFeeBeneficiary(_someLuckyGuy);
    }

    function testSetGovernor(address _newGov) external {
        vm.assume(_newGov != address(0));

        vm.expectEmit(true, false, false, true);
        emit GovernorSet(_newGov);
        prv.setGovernor(_newGov);

        assertEq(prv.governor(), _newGov);
    }

    function testSetGovernorRevertsZeroAddr() external {
        address _newGov = address(0);
        vm.expectRevert("ZERO_ADDR");
        prv.setGovernor(_newGov);
    }

    function testSetFeePolicy(address _beneficiary, uint256 _fee) external {
        vm.assume(_beneficiary != address(0));
        vm.assume(_fee <= prv.MAX_FEE());

        prv.setFeePolicy(_fee, _beneficiary);

        assertEq(prv.fee(), _fee);
        assertEq(prv.feeBeneficiary(), _beneficiary);
    }

    function testSetFeeRevertAboveMax(uint256 _fee) external {
        vm.assume(_fee > prv.MAX_FEE());
        vm.expectRevert("FEE_TOO_BIG");
        prv.setFee(_fee);
        vm.stopPrank();
    }

    /// included to test vs past iteration of the PRV contract
    function testFeeIsNotChargedOnDeposit(
        uint256 _fee,
        uint184 _deposit /* The deposit is bounded because of overflow */
    ) external {
        vm.assume(_fee <= prv.MAX_FEE());
        vm.assume(_deposit > 0);

        vm.expectEmit(false, false, false, true);
        emit FeeSet(_fee);
        prv.setFee(_fee);

        uint256 expectedFeeBeneficiaryBalance = 0;

        deposit.approve(address(prv), _deposit);
        prv.depositFor(address(this), _deposit);

        assertEq(deposit.balanceOf(FEE_BENEFICIARY), expectedFeeBeneficiaryBalance);
    }

    function testDepositFor(uint184 _deposit, address _receiver, address _sender) external notAdmin(_sender) {
        vm.assume(_deposit > 0);
        vm.assume(_receiver != address(0));
        vm.assume(_sender != _receiver);

        deposit.transfer(_sender, _deposit);

        uint256 depositBalanceBefore = deposit.balanceOf(_sender);
        uint256 prvBalanceBefore = prv.balanceOf(_receiver);
        uint256 contractBalanceBefore = deposit.balanceOf(address(prv));

        vm.startPrank(_sender);
        {
            deposit.approve(address(prv), type(uint256).max);
            prv.depositFor(_receiver, _deposit);
        }
        vm.stopPrank();

        assertEq(deposit.balanceOf(_sender), depositBalanceBefore - _deposit);
        assertEq(prv.balanceOf(_sender), 0);
        assertEq(prv.balanceOf(_receiver), prvBalanceBefore + _deposit);
        assertEq(deposit.balanceOf(address(prv)), contractBalanceBefore + _deposit);
    }

    function testDepositForSignatureValid(uint128 _spenderPk, address _recipient, uint128 _amount, uint256 _deadline)
        external
        notAdmin(_recipient)
    {
        vm.assume(_spenderPk > 0);
        vm.assume(_deadline > 0);
        vm.assume(_amount > 0);
        vm.assume(_recipient != address(0));
        vm.assume(_amount <= deposit.balanceOf(address(this)));
        address spender = vm.addr(_spenderPk);
        vm.assume(!isAdmin(spender));

        bytes32 permitMessage =
            EIP712HashBuilder.generateTypeHashPermit(spender, address(prv), _amount, _deadline, deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_spenderPk, permitMessage);

        deposit.transfer(spender, _amount);

        vm.prank(spender);
        prv.depositForWithSignature(_recipient, _amount, _deadline, v, r, s);
        assertEq(prv.balanceOf(_recipient), _amount);
    }

    function testDepositForSignatureInValid(
        uint128 _spenderPk,
        address _recipient,
        uint128 _amount,
        uint256 _deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        vm.assume(_spenderPk > 0);
        vm.assume(_deadline > 0);
        vm.assume(_amount > 0);
        vm.assume(_recipient != address(0));
        vm.assume(_amount <= deposit.balanceOf(address(this)));

        address spender = vm.addr(_spenderPk);
        vm.assume(!isAdmin(spender));

        deposit.transfer(spender, _amount);

        vm.prank(spender);
        vm.expectRevert();
        prv.depositForWithSignature(_recipient, _amount, _deadline, v, r, s);
    }

    // ==================== WITHDRAWAL ====================

    function testNoZeroWithdrawals() external {
        vm.expectRevert("ZERO_AMOUNT");
        prv.withdraw(0, "");
    }

    function testWillRevertOnWithdrawalFailure() external {
        MockPRVWithdrawalVerifier mock = new MockPRVWithdrawalVerifier();
        prv.setWithdrawalManager(address(mock));

        vm.expectRevert("BAD_WITHDRAW");
        prv.withdraw(1, "");

        // setting manager to pass will have another error
        mock.setPass(true);
        vm.expectRevert(Errors.ERC20_BURN);
        prv.withdraw(1, "");
    }

    function testFuzz_canWithdraw(
        address _beneficiary,
        address _depositor,
        uint256 _entryFee,
        uint256 _depositQty,
        uint256 _withdrawQty
    ) public notAdmin(_beneficiary) notAdmin(_depositor) {
        vm.assume(_entryFee <= prv.MAX_FEE());
        // deposits close to the uint256 limit will overflow when calculating the expected balance
        // 192 bit is larger that we will ever need
        vm.assume(_depositQty > 0 && _depositQty < type(uint192).max);
        vm.assume(_withdrawQty > 0 && _withdrawQty < _depositQty);
        vm.assume(_beneficiary != _depositor);

        // setup fees
        prv.setFeePolicy(_entryFee, _beneficiary);

        // make a deposit
        deposit.approve(address(prv), _depositQty);
        prv.depositFor(_depositor, _depositQty);

        // before withdraw, calculate expected balances
        uint256 expectedFeeBeneficiaryDepositBalance = _withdrawQty - prv.previewWithdraw(_withdrawQty);
        uint256 expectedReceiverDepositBalance = _withdrawQty - expectedFeeBeneficiaryDepositBalance;

        // action the withdraw and check state
        vm.prank(_depositor);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(_depositor, _withdrawQty);
        prv.withdraw(_withdrawQty, bytes(""));

        assertEq(deposit.balanceOf(_beneficiary), expectedFeeBeneficiaryDepositBalance);
        assertEq(deposit.balanceOf(_depositor), expectedReceiverDepositBalance);
        assertEq(prv.balanceOf(_depositor), _depositQty - _withdrawQty);
    }

    function testFuzz_WithdrawalFeeNotChargedIfNoBeneficiarySet(uint256 _entryFee, uint128 _deposit)
        external
        USE_MOCK_PRV
    {
        vm.assume(_entryFee <= prv.MAX_FEE());
        vm.assume(_deposit > 0);

        deposit.approve(address(prv), _deposit);
        prv.depositFor(address(this), _deposit);

        uint256 depositBalanceBefore = deposit.balanceOf(address(this));

        // mock method only
        MockPRV(address(prv)).resetFeeBeneficiary();
        assertEq(prv.feeBeneficiary(), address(0));

        prv.setFee(_entryFee);

        prv.withdraw(_deposit, bytes(""));

        assertEq(deposit.balanceOf(address(this)), depositBalanceBefore + _deposit);
    }

    function testOnlyGovernance(address _notGovernor) external notAdmin(_notGovernor) {
        vm.startPrank(_notGovernor);

        vm.expectRevert("!GOVERNOR");
        prv.setFee(0);

        vm.expectRevert("!GOVERNOR");
        prv.setGovernor(address(0));

        vm.expectRevert("!GOVERNOR");
        prv.setFeeBeneficiary(address(0));

        vm.expectRevert("!GOVERNOR");
        prv.setFeePolicy(0, address(0));

        vm.expectRevert("!GOVERNOR");
        prv.setWithdrawalManager(address(0));

        vm.stopPrank();
    }
}
