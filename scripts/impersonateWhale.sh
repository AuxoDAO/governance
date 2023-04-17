#!/bin/bash

HOST="127.0.0.1"
PORT="8545"

ID='team-testing'
RPC=https://bestnet.alexintosh.com/rpc/$ID


WETH_WHALE="0xE831C8903de820137c13681E78A5780afDdf7697"
ETH_WHALE="0x2B6eD29A95753C3Ad948348e3e7b1A251080Ffb9"
WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
# anvil unlocked address
RECIPIENT="0x9964d3cBCCF02Ab5A13e9339C4e8FD7278bb584a"
TRANSFER_QTY="100000000000000000000"

# cast rpc --rpc-url $RPC anvil_impersonateAccount $WETH_WHALE
# cast send $WETH --from $WETH_WHALE "transfer(address,uint256)" $RECIPIENT $TRANSFER_QTY --rpc-url http://$HOST:$PORT

cast rpc --rpc-url $RPC anvil_impersonateAccount $ETH_WHALE
cast send --from $ETH_WHALE $RECIPIENT --value $TRANSFER_QTY --rpc-url $RPC
