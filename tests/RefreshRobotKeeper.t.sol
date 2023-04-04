// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {AaveV3Avalanche, AaveV3AvalancheAssets, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {RefreshRobotKeeper} from '../src/RefreshRobotKeeper.sol';
import {IEmissionManager, RewardsDataTypes, IEACAggregatorProxy} from 'aave-v3-periphery/contracts/rewards/interfaces/IEmissionManager.sol';
import {ITransferStrategyBase} from 'aave-v3-periphery/contracts/rewards/interfaces/ITransferStrategyBase.sol';
import './TestBase.sol';

contract RefreshRobotKeeperTest is BaseTest {
  uint256 constant TOTAL_DISTRIBUTION = 10000 ether;
  uint88 constant DURATION_DISTRIBUTION = 180 days;

  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  IEACAggregatorProxy REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3AvalancheAssets.AAVEe_ORACLE);

  ITransferStrategyBase TRANSFER_STRATEGY =
    ITransferStrategyBase(0x190110114Eff8B111123BEa9b517Fc86b677D94A);

  IPool public override pool = IPool(AaveV3Avalanche.POOL);
  RefreshRobotKeeper robotKeeper;

  address public constant override UNDERLYING = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  address public constant override A_TOKEN = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  address public constant EMISSION_ADMIN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;
  address public REWARD_TOKEN = AaveV3AvalancheAssets.AAVEe_UNDERLYING;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);

    super.setUp();
    robotKeeper = new RefreshRobotKeeper(
      factory,
      IRewardsController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }

  function testRefreshRewards() public {
    address wethStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address wbtcStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address maiStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address fraxStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);

    _createNewLM();

    assertEq(
      IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      false
    );
    assertEq(
      IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      false
    );
    assertEq(
      IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      false
    );
    assertEq(
      IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      false
    );

    _checkAndPerformUpKeep(robotKeeper);

    assertEq(
      IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      true
    );
    assertEq(
      IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      true
    );
    assertEq(
      IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      true
    );
    assertEq(
      IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(
        REWARD_TOKEN
      ),
      true
    );
  }

  function _checkAndPerformUpKeep(RefreshRobotKeeper votingChainRobotKeeper) internal {
    (bool shouldRunKeeper, bytes memory performData) = votingChainRobotKeeper.checkUpkeep('');
    if (shouldRunKeeper) {
      votingChainRobotKeeper.performUpkeep(performData);
    }
  }

  function _createNewLM() internal {
    deal(
      REWARD_TOKEN,
      EMISSION_ADMIN,
      TOTAL_DISTRIBUTION
    );
    vm.stopPrank();

    vm.startPrank(EMISSION_ADMIN);
    IERC20(AaveV3AvalancheAssets.WBTCe_UNDERLYING).approve(address(TRANSFER_STRATEGY), TOTAL_DISTRIBUTION);
    IEmissionManager(AaveV3Avalanche.EMISSION_MANAGER).configureAssets(_getAssetConfigs());
    vm.stopPrank();
  }

  function _getAssetConfigs() internal view returns (RewardsDataTypes.RewardsConfigInput[] memory) {
    uint32 distributionEnd = uint32(block.timestamp + DURATION_DISTRIBUTION);

    EmissionPerAsset[] memory emissionsPerAsset = _getEmissionsPerAsset();

    RewardsDataTypes.RewardsConfigInput[]
      memory configs = new RewardsDataTypes.RewardsConfigInput[](emissionsPerAsset.length);
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      configs[i] = RewardsDataTypes.RewardsConfigInput({
        emissionPerSecond: _toUint88(emissionsPerAsset[i].emission / DURATION_DISTRIBUTION),
        totalSupply: 0, // IMPORTANT this will not be taken into account by the contracts, so 0 is fine
        distributionEnd: distributionEnd,
        asset: emissionsPerAsset[i].asset,
        reward: REWARD_TOKEN,
        transferStrategy: TRANSFER_STRATEGY,
        rewardOracle: REWARD_ORACLE
      });
    }
    return configs;
  }

  function _getEmissionsPerAsset() internal pure returns (EmissionPerAsset[] memory) {
    EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](4);
    emissionsPerAsset[0] = EmissionPerAsset({
      asset: AaveV3AvalancheAssets.WBTCe_A_TOKEN,
      emission: TOTAL_DISTRIBUTION / 4 // 25% of the distribution
    });
    emissionsPerAsset[1] = EmissionPerAsset({
      asset: AaveV3AvalancheAssets.FRAX_A_TOKEN,
      emission: TOTAL_DISTRIBUTION / 4 // 25% of the distribution
    });
    emissionsPerAsset[2] = EmissionPerAsset({
      asset: AaveV3AvalancheAssets.MAI_A_TOKEN,
      emission: TOTAL_DISTRIBUTION / 4 // 25% of the distribution
    });
    emissionsPerAsset[3] = EmissionPerAsset({
      asset: AaveV3AvalancheAssets.WETHe_A_TOKEN,
      emission: TOTAL_DISTRIBUTION / 4 // 25% of the distribution
    });
    uint256 totalDistribution;
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      totalDistribution += emissionsPerAsset[i].emission;
    }
    require(totalDistribution == TOTAL_DISTRIBUTION, 'INVALID_SUM_OF_EMISSIONS');

    return emissionsPerAsset;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }

}
