pragma solidity 0.8.16;

import "./Deploy-v1.s.sol";

/**
 * The base deploy script has a couple of config settings that can be used to
 * customize the deployment. This file contains a few presets that can be called
 * directly in the Makefile.
 */

/// basic deploy that can be run locally with no additional setup
/// it is not possible to run the simulation as veDOUGH has not been deployed
contract DeployAuxoLocal is DeployAuxo {
    constructor() DeployAuxo(
        /* _setting: */ SETTING.MOCK,
        /* _simulation: */ false,
        /* _enableFrontendTesting: */ false
    ) {}
}

/// deploy on a forked url
/// this also runs the simulation which will check actual veDOUGH migrations and governance actions
contract DeployAuxoForked is DeployAuxo {
    constructor() DeployAuxo(
        /* _setting: */ SETTING.UPGRADE,
        /* _simulation: */ true,
        /* _enableFrontendTesting: */ false
    ) {}
}

/// Deploy to a persistent forked network, such as anvil
/// This allows for testing the frontend with a persistent forked network
/// This requires that the deployment account has enough WETH to seed the distributors
contract DeployAuxoPersistentFork is DeployAuxo {
    constructor() DeployAuxo(
        /* _setting: */ SETTING.IMPLEMENTATION,
        /* _simulation: */ false,
        /* _enableFrontendTesting: */ true
    ) {}
}
