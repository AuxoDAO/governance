#!/bin/bash

'''
Post deployment script to setup the ARV and PRV distributors
You must have cast enabled and be sending transactions to an anvil fork.
'''

# change id and rpc as needed
# ID="jordan-gab-testing"
# RPCFLAG="--rpc-url https://bestnet.alexintosh.com/rpc/$ID"
# local fork
RPCFLAG="--rpc-url http://localhost:8545"

# addresses
WETH_WHALE="0xE831C8903de820137c13681E78A5780afDdf7697"
ETH_WHALE="0x7d715351c41B32e26DA45d1A35366eABE42C3720"
RECIPIENT="0x6458a23b020f489651f2777bd849dded34dfccd2" # owns distributors

# smart contracts - these may change based on deploy logs
WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
CLAIM_HELPER="0xce830DA8667097BB491A70da268b76a081211814"
ARV_DISTRIBUTOR="0x46d4674578a2daBbD0CEAB0500c6c7867999db34"
PRV_DISTRIBUTOR="0xC220Ed128102d888af857d137a54b9B7573A41b2"

# transfers
TRANSFER_QTY="70000000000000000000" # 70 WETH
TRANSFER_QTY_PRV="30000000000000000000" # 30 WETH
TRANSFER_QTY_TOTAL="100000000000000000000" # 100 WETH

# merkle roots - update to encode different merkle tree data
ARV_MERKLE_ROOT="0x594650792f69103dc621a1c1a62ba2b3ed2828c2c7eee8f6af4fd96d59500d05"
PRV_MERKLE_ROOT="0xa77cd76d4732dc897e7e6732b3bb8f04ce24956fac63773a9229ceec8dfe3505"
ARV_MERKLE_ROOT_1="0xa3dcd97c8f4f0dfe98c12970dfb1fcc12345452784cb9d22fee9dbd3dcbcc294"
PRV_MERKLE_ROOT_1="0x5fc5ccc83e96f4c7df32e35db9cde87637c8e6065def33b79165460f417fe709"

# script unlocks a WETH whale using anvil and then transfers some additional WETH to the ARV distributor
setWindow () {
    echo "begin set window"
    local TRANSFER_QTY=$1
    local MERKLE_ROOT=$2
    local DISTRIBUTOR=$3

    echo "transferring to recipient $RECIPIENT"
    cast send $WETH --from $WETH_WHALE "transfer(address,uint256)" $RECIPIENT $TRANSFER_QTY $RPCFLAG

    echo "approving $TRANSFER_QTY weth to distributor at $DISTRIBUTOR"
    cast rpc $RPCFLAG anvil_impersonateAccount $RECIPIENT
    cast send $WETH --from $RECIPIENT "approve(address,uint256)" $DISTRIBUTOR $TRANSFER_QTY $RPCFLAG

    echo "setting merkle root $MERKLE_ROOT on distributor at $DISTRIBUTOR"
    cast send $DISTRIBUTOR --from $RECIPIENT "setWindow(uint256,address,bytes32,string memory)" \
    $TRANSFER_QTY \
    $WETH \
    $MERKLE_ROOT \
    "Distributor" \
    $RPCFLAG
}

# SCRIPT BEGINS

# if cast is not installed exit with error
if ! command -v cast &> /dev/null
then
    echo "cast could not be found - install foundry"
    exit
fi

# unlock whale
cast rpc $RPCFLAG anvil_impersonateAccount $WETH_WHALE

# execute the function
setWindow $TRANSFER_QTY $ARV_MERKLE_ROOT $ARV_DISTRIBUTOR
setWindow $TRANSFER_QTY_PRV $PRV_MERKLE_ROOT $PRV_DISTRIBUTOR
setWindow $TRANSFER_QTY $ARV_MERKLE_ROOT_1 $ARV_DISTRIBUTOR
setWindow $TRANSFER_QTY_PRV $PRV_MERKLE_ROOT_1 $PRV_DISTRIBUTOR
