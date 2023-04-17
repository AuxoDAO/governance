pragma solidity 0.8.16;

import "@forge-std/Script.sol";

contract JSONReader is Script {
    /// @param token 'ARV' or 'PRV'
    function getRootOfTree(bytes memory token) public view returns (bytes32 merkleRoot) {
        string memory path = string.concat("./script/merkle-trees/merkle-tree-", string(token), ".json");
        string memory json = vm.readFile(path);
        bytes memory root = vm.parseJson(json, ".root");
        return abi.decode(root, (bytes32));
    }

    function getARVRoot() public view returns (bytes32 merkleRoot) {
        return getRootOfTree("ARV");
    }

    function getPRVRoot() public view returns (bytes32 merkleRoot) {
        return getRootOfTree("PRV");
    }

    // test out
    function run() public {
        console2.logBytes32(getARVRoot());
        console2.logBytes32(getPRVRoot());
    }
}
