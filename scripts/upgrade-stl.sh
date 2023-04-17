#!/bin/sh

# Impersonate the multisig and call set implementation
# on the STL with the new contract

STL=0x6Bd0D8c8aD8D3F1f97810d5Cc57E9296db73DC45
MULTISIG_OPS=0x6458A23B020f489651f2777Bd849ddEd34DfCcd2
NEW_IMPL=0x25A1DF485cFBb93117f12fc673D87D1cddEb845a
UPGRADOOR=0x85495222Fd7069B987Ca38C2142732EbBFb7175D

RPC="http://localhost:8545"
RPC_FLAG="--rpc-url $RPC"

echo "impersonating ops"
cast rpc $RPC_FLAG anvil_impersonateAccount $MULTISIG_OPS

echo "setting new implementation"
cast send $STL --from $MULTISIG_OPS "setImplementation(address)" $NEW_IMPL $RPC_FLAG

echo "setting migrator"
cast send $STL --from $MULTISIG_OPS "setMigratoor(address)" $UPGRADOOR $RPC_FLAG

echo "enabling migration"
cast send $STL --from $MULTISIG_OPS "setMigrationON()" $RPC_FLAG
