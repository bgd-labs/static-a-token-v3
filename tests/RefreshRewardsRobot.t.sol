// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {AaveV3Avalanche, AaveV3AvalancheAssets, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {RefreshRewardsRobot} from '../src/robots/RefreshRewardsRobot.sol';
import {IEmissionManager, RewardsDataTypes, IEACAggregatorProxy} from 'aave-v3-periphery/contracts/rewards/interfaces/IEmissionManager.sol';
import {ITransferStrategyBase} from 'aave-v3-periphery/contracts/rewards/interfaces/ITransferStrategyBase.sol';
import './TestBase.sol';

contract RefreshRewardsRobotTest is BaseTest {
  uint256 constant TOTAL_DISTRIBUTION = 10000 ether;
  uint88 constant DURATION_DISTRIBUTION = 180 days;

  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  IEACAggregatorProxy REWARD_ORACLE = IEACAggregatorProxy(AaveV3AvalancheAssets.AAVEe_ORACLE);

  ITransferStrategyBase TRANSFER_STRATEGY =
    ITransferStrategyBase(0x190110114Eff8B111123BEa9b517Fc86b677D94A);

  IPool public override pool = IPool(AaveV3Avalanche.POOL);
  RefreshRewardsRobot robotKeeper;

  address public constant override UNDERLYING = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  address public constant override A_TOKEN = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  address public constant EMISSION_ADMIN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;
  address public REWARD_TOKEN = AaveV3AvalancheAssets.AAVEe_UNDERLYING;
  address public GUARDIAN = address(22);

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);

    super.setUp();
    vm.stopPrank();

    vm.prank(GUARDIAN);
    robotKeeper = new RefreshRewardsRobot(
      address(factory),
      AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER
    );
  }

  function testRefreshRewards() public {
    address wethStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WETHe_UNDERLYING);
    address wbtcStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address maiStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.MAI_UNDERLYING);
    address fraxStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.FRAX_UNDERLYING);

    _createNewLM();

    assertEq(IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);

    bool didRobotRun = _checkAndPerformUpKeep(robotKeeper);
    assertTrue(didRobotRun);

    assertEq(IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
  }

  function test_disableAutomation() public {
    address wethStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WETHe_UNDERLYING);
    address wbtcStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address maiStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.MAI_UNDERLYING);
    address fraxStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.FRAX_UNDERLYING);

    _createNewLM();

    assertEq(IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);

    vm.startPrank(GUARDIAN);
    robotKeeper.disableAutomation(wethStaticAToken, true);
    robotKeeper.disableAutomation(wbtcStaticAToken, true);
    robotKeeper.disableAutomation(maiStaticAToken, true);
    robotKeeper.disableAutomation(fraxStaticAToken, true);
    vm.stopPrank();

    assertTrue(robotKeeper.isDisabled(wethStaticAToken));
    assertTrue(robotKeeper.isDisabled(wbtcStaticAToken));
    assertTrue(robotKeeper.isDisabled(maiStaticAToken));
    assertTrue(robotKeeper.isDisabled(wethStaticAToken));

    bool didRobotRun = _checkAndPerformUpKeep(robotKeeper);
    assertFalse(didRobotRun);

    assertEq(IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
    assertEq(IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), false);
  }

  function test_auth_disableAutomation() public {
    address caller = address(54);
    address staticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WETHe_UNDERLYING);

    vm.prank(caller);
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    robotKeeper.disableAutomation(staticAToken, true);

    vm.prank(GUARDIAN);
    robotKeeper.disableAutomation(staticAToken, true);
    assertTrue(robotKeeper.isDisabled(staticAToken));
  }

  function _checkAndPerformUpKeep(
    RefreshRewardsRobot refreshRewardsRobot
  ) internal virtual returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = refreshRewardsRobot.checkUpkeep('');
    if (shouldRunKeeper) {
      refreshRewardsRobot.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }

  function _createNewLM() internal {
    deal(REWARD_TOKEN, EMISSION_ADMIN, TOTAL_DISTRIBUTION);
    vm.stopPrank();

    vm.startPrank(EMISSION_ADMIN);
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
