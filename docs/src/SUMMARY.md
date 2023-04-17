# Summary
- [Home](README.md)
# src
  - [❱ interfaces](src/interfaces/README.md)
    - [IERC20MintableBurnable](src/interfaces/IERC20MintableBurnable.sol/interface.IERC20MintableBurnable.md)
    - [IPRV](src/interfaces/IPRV.sol/interface.IPRV.md)
    - [IPRVRouter](src/interfaces/IPRVRouter.sol/interface.IPRVRouter.md)
    - [IPolicy](src/interfaces/IPolicy.sol/interface.IPolicy.md)
    - [IRollStaker](src/interfaces/IRollStaker.sol/interface.IRollStaker.md)
    - [ITokenLocker](src/interfaces/ITokenLocker.sol/interface.ITokenLocker.md)
    - [IWithdrawalManager](src/interfaces/IWithdrawalManager.sol/interface.IWithdrawalManager.md)
  - [❱ modules](src/modules/README.md)
    - [❱ PRV](src/modules/PRV/README.md)
      - [IPRVEvents](src/modules/PRV/PRV.sol/interface.IPRVEvents.md)
      - [PRV](src/modules/PRV/PRV.sol/contract.PRV.md)
      - [IPRVMerkleVerifier](src/modules/PRV/PRVMerkleVerifier.sol/interface.IPRVMerkleVerifier.md)
      - [PRVMerkleVerifier](src/modules/PRV/PRVMerkleVerifier.sol/contract.PRVMerkleVerifier.md)
      - [PRVRouter](src/modules/PRV/PRVRouter.sol/contract.PRVRouter.md)
      - [IRollStaker](src/modules/PRV/RollStaker.sol/interface.IRollStaker.md)
      - [RollStaker](src/modules/PRV/RollStaker.sol/contract.RollStaker.md)
      - [IStakingManagerEvents](src/modules/PRV/StakingManager.sol/interface.IStakingManagerEvents.md)
      - [StakingManager](src/modules/PRV/StakingManager.sol/contract.StakingManager.md)
      - [Bitfields](src/modules/PRV/bitfield.sol/library.Bitfields.md)
    - [❱ governance](src/modules/governance/README.md)
      - [ITerminatableEvents](src/modules/governance/EarlyTermination.sol/interface.ITerminatableEvents.md)
      - [Terminatable](src/modules/governance/EarlyTermination.sol/abstract.Terminatable.md)
      - [AuxoGovernor](src/modules/governance/Governor.sol/contract.AuxoGovernor.md)
      - [IncentiveCurve](src/modules/governance/IncentiveCurve.sol/abstract.IncentiveCurve.md)
      - [IMigrateableEvents](src/modules/governance/Migrator.sol/interface.IMigrateableEvents.md)
      - [Migrateable](src/modules/governance/Migrator.sol/abstract.Migrateable.md)
      - [ITokenLockerEvents](src/modules/governance/TokenLocker.sol/interface.ITokenLockerEvents.md)
      - [TokenLocker](src/modules/governance/TokenLocker.sol/contract.TokenLocker.md)
    - [❱ reward-policies](src/modules/reward-policies/README.md)
      - [❱ policies](src/modules/reward-policies/policies/README.md)
        - [DecayPolicy](src/modules/reward-policies/policies/DecayPolicy.sol/contract.DecayPolicy.md)
      - [PolicyManager](src/modules/reward-policies/PolicyManager.sol/contract.PolicyManager.md)
      - [SimpleDecayOracle](src/modules/reward-policies/SimpleDecayOracle.sol/contract.SimpleDecayOracle.md)
    - [❱ rewards](src/modules/rewards/README.md)
      - [DelegationRegistry](src/modules/rewards/DelegationRegistry.sol/abstract.DelegationRegistry.md)
      - [IMerkleDistributorCore](src/modules/rewards/MerkleDistributor.sol/interface.IMerkleDistributorCore.md)
      - [MerkleDistributor](src/modules/rewards/MerkleDistributor.sol/contract.MerkleDistributor.md)
    - [❱ vedough-bridge](src/modules/vedough-bridge/README.md)
      - [LowGasSafeMath](src/modules/vedough-bridge/SharesTimeLock.sol/library.LowGasSafeMath.md)
      - [TransferHelper](src/modules/vedough-bridge/SharesTimeLock.sol/library.TransferHelper.md)
      - [SharesTimeLock](src/modules/vedough-bridge/SharesTimeLock.sol/contract.SharesTimeLock.md)
      - [ISharesTimelocker](src/modules/vedough-bridge/Upgradoor.sol/interface.ISharesTimelocker.md)
      - [Upgradoor](src/modules/vedough-bridge/Upgradoor.sol/contract.Upgradoor.md)
  - [❱ utils](src/utils/README.md)
    - [InitializableBy](src/utils/InitializableBy.sol/contract.InitializableBy.md)
  - [ARV](src/ARV.sol/contract.ARV.md)
  - [Auxo](src/AUXO.sol/contract.Auxo.md)