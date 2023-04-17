pragma solidity 0.8.16;

import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";
import {IERC20Metadata} from "@oz/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@oz/token/ERC20/extensions/IERC20Permit.sol";
import "@oz/utils/Strings.sol";

import {TokenLocker} from "@governance/TokenLocker.sol";
import "@forge-std/console2.sol";
import "@forge-std/Vm.sol";

address constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

function accessControlRevertString(address _account, bytes32 _role) pure returns (string memory) {
    return string(
        abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(_account),
            " is missing role ",
            Strings.toHexString(uint256(_role), 32)
        )
    );
}

library Errors {
    bytes public constant OWNABLE = bytes("Ownable: caller is not the owner");
    bytes public constant PAUSABLE = bytes("Pausable: paused");
    bytes public constant ROLLSTAKER_UNSTAKE = bytes("Unstake next epoch first");
    bytes public constant INITIALIZED = bytes("Initializable: contract is already initialized");
    bytes public constant NOT_PROXY_ADMIN = bytes("PProxy.onlyProxyOwner: msg sender not owner");
    bytes public constant NOT_EOA_OR_WL = bytes("Not EOA or WL");
    bytes public constant REENTRANCY_GUARD = bytes("ReentrancyGuard: reentrant call");
    bytes public constant MIGRATION_DISABLED = bytes("SharesTimeLock: !migrationEnabled");
    bytes public constant NOT_MIGRATOR = bytes("SharesTimeLock: Not Migrator");
    bytes public constant LOCK_EXPIRED = bytes("SharesTimeLock: Lock expired");
    bytes public constant CLAIM_TOO_HIGH = bytes("CLAIM_TOO_HIGH");
    bytes public constant INVALID_CLAIM = bytes("!VALID");
    bytes public constant BAD_WINDOW = bytes("!WINDOW");
    bytes public constant NOT_PRV = bytes("!PRV");
    bytes public constant NO_BUDGET = bytes("!BUDGET");
    bytes public constant NOT_OPEN = bytes("!OPEN");
    bytes public constant INVALID_EPOCH = bytes("END <= START");
    bytes public constant LOCKED = bytes("LOCKED");
    bytes public constant ERC20_BURN = bytes("ERC20: burn amount exceeds balance");
    bytes public constant ERC20_TRANSFER = bytes("ERC20: transfer amount exceeds balance");
    bytes public constant INSUFFICIENT_AUXO = bytes("MAX > AUXO");
}

library IsEOA {
    function isEOA(address _account) external view returns (bool) {
        if (_account == address(0)) return false;
        uint256 size;
        // solhint-disable no-inline-assembly
        assembly {
            size := extcodesize(_account)
        }
        return size == 0;
    }
}

/**
 * @notice EIP712-signature-compliant hash generator that can be signed by a user
 * @dev use in foundry tests with `vm.sign(pk, EIP712HashBuilder.generateTypeHashPermit( ...args));`
 */
library EIP712HashBuilder {
    bytes32 public constant VERSION_HASH = keccak256(bytes("1"));

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    bytes32 public constant typeHash =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @param _nameHash bytes32 hashedName = keccak256(bytes(_name)); Will be the name of the target contract
    /// @param _target address of the target contract
    function buildDomainSeparator(bytes32 _nameHash, address _target) public view returns (bytes32) {
        return keccak256(abi.encode(typeHash, _nameHash, VERSION_HASH, block.chainid, _target));
    }

    /// @notice generate the signature for permit (off-chain approval)
    function generateTypeHashPermit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        IERC20Permit _contract
    ) external view returns (bytes32) {
        string memory name = IERC20Metadata(address(_contract)).name();
        bytes32 nameHash = keccak256((bytes(name)));
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, _contract.nonces(_owner), _deadline));
        return ECDSA.toTypedDataHash(buildDomainSeparator(nameHash, address(_contract)), structHash);
    }

    /// @notice generate the signature for delegation
    function generateTypeHashDelegate(address _delegatee, uint256 _deadline, IERC20Permit _contract)
        external
        view
        returns (bytes32)
    {
        string memory name = IERC20Metadata(address(_contract)).name();
        bytes32 nameHash = keccak256((bytes(name)));
        bytes32 structHash =
            keccak256(abi.encode(DELEGATION_TYPEHASH, _delegatee, _contract.nonces(_delegatee), _deadline));
        return ECDSA.toTypedDataHash(buildDomainSeparator(nameHash, address(_contract)), structHash);
    }
}

/// array helpers

function nonZeroUniqueAddressArray(uint128 _startPk, uint8 _len) returns (address[] memory) {
    address[] memory addresses = new address[](_len);
    require(_startPk > 0, "Private Key == 0");

    uint128 pk = _startPk;
    for (uint256 i = 0; i < _len; i++) {
        addresses[i] = Vm(VM_ADDRESS).addr(pk);
        pk++;
    }
    return addresses;
}

function nonZeroUint192Array(uint192[] memory _in, uint256 _len) pure returns (uint192[] memory) {
    return aboveMinUint192Array(_in, _len, 0);
}

function aboveMinUint192Array(uint192[] memory _in, uint256 _len, uint256 _min) pure returns (uint192[] memory) {
    uint192[] memory out = new uint192[](_len);
    for (uint256 i = 0; i < _len; i++) {
        if (_in[i] <= _min) out[i] = uint192(uint256(keccak256(abi.encode(i, _in[i]))));
        else out[i] = _in[i];
    }
    return out;
}

function nonZeroUint128Array(uint128[] memory _in, uint256 _len) pure returns (uint128[] memory) {
    return aboveMinUint128Array(_in, _len, 0);
}

function aboveMinUint128Array(uint128[] memory _in, uint256 _len, uint256 _min) pure returns (uint128[] memory) {
    uint128[] memory out = new uint128[](_len);
    for (uint256 i = 0; i < _len; i++) {
        if (_in[i] <= _min) out[i] = uint128(uint256(keccak256(abi.encode(i, _in[i]))));
        else out[i] = _in[i];
    }
    return out;
}

function castArray128To192(uint128[] memory _in) pure returns (uint192[] memory) {
    uint192[] memory arr = new uint192[](_in.length);
    for (uint256 a; a < _in.length; a++) {
        arr[a] = _in[a];
    }
    return arr;
}

function castArray256to8(uint[] memory _in) pure returns (uint8[] memory) {
    uint8[] memory arr = new uint8[](_in.length);
    for (uint256 a; a < _in.length; a++) {
        arr[a] = uint8(_in[a]);
    }
    return arr;
}

function castArray8to256(uint8[] memory _in) pure returns (uint[] memory) {
    uint[] memory arr = new uint[](_in.length);
    for (uint256 a; a < _in.length; a++) {
        arr[a] = _in[a];
    }
    return arr;
}

// pass an address to return definitely not the same address
function deriveAddressFrom(address _existing) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encode(_existing)))));
}
