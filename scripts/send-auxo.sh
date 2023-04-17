#!/bin/bash

'''
Sends AUXO to yourself
'''

# change id and rpc as needed
ID="team-testing"
RPC="--rpc-url https://bestnet.alexintosh.com/rpc/$ID"
# local fork
# RPC="--rpc-url http://localhost:8545"
MULTISIG_OPS="0x4Ac45Cb9627240Faf54122a743066E0dcdbAB5Db" # timelock not ops
RECIPIENT="0xd18a54f89603Fe4301b29EF6a8ab11b9Ba24f139"
AUXO="0xc5B524357934e45B26a01A37CC0525C5a3939D08"
# ID='team-testing'
# RPC=https://bestnet.alexintosh.com/rpc/$ID

WETH_WHALE="0xE831C8903de820137c13681E78A5780afDdf7697"
ETH_WHALE="0x2B6eD29A95753C3Ad948348e3e7b1A251080Ffb9"
WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

# cast rpc --rpc-url $RPC anvil_impersonateAccount $WETH_WHALE
# cast send $WETH --from $WETH_WHALE "transfer(address,uint256)" $RECIPIENT $TRANSFER_QTY --rpc-url http://$HOST:$PORT

echo "sending eth to lock"
cast rpc $RPC anvil_impersonateAccount $ETH_WHALE
cast send --from $ETH_WHALE $MULTISIG_OPS --value 100ether $RPC

echo "unlocking minter"
cast rpc $RPC anvil_impersonateAccount $MULTISIG_OPS

echo 'minting to recipient'
cast send $AUXO --from $MULTISIG_OPS "mint(address,uint256)" $RECIPIENT 1000ether $RPC
