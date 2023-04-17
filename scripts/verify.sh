#!/bin/bash

# Verifcation scripts as examples

export CONTRACT_PATH="lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

forge verify-contract 0x05fc909dFca9d4f256A628C15f2c2540Db8c0e00 \
    $CONTRACT_PATH:TransparentUpgradeableProxy $ETHERSCAN_API_KEY \
    --chain goerli \
    --constructor-args-path args.txt \
    --watch
;

export CONTRACT_PATH="lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

forge verify-contract 0x9FFcba2F83084DeaE2f8D707f9B076012623fd13 \
    $CONTRACT_PATH:TimelockController $ETHERSCAN_API_KEY \
    --chain goerli \
    --constructor-args-path args.txt \
    --watch
;



forge verify-contract 0x963866ef17Ee4F20377B52C296B7cd82b7f83C36 \
    AuxoGovernor $ETHERSCAN_API_KEY \
    --chain goerli \
    --constructor-args-path args.txt \
    --watch
;

forge verify-contract 0x963866ef17Ee4F20377B52C296B7cd82b7f83C36 \
    Auxo $ETHERSCAN_API_KEY \
    --chain goerli \
    --constructor-args-path args.txt \
    --watch
;
