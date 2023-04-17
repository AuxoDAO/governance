#!/bin/sh

ID='team-testing'
RPC=https://bestnet.alexintosh.com/rpc/$ID
RPC=http://localhost:8545

STL=0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45
USER=0x1A1087Bf077f74fb21fD838a8a25Cf9Fe0818450

cast call $STL "getLocksOfLength(address)(uint256)" $USER --rpc-url $RPC
