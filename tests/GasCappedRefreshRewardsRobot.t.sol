// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {GasCappedRefreshRewardsRobot} from '../src/robots/GasCappedRefreshRewardsRobot.sol';
import {AggregatorInterface} from 'aave-address-book/AaveV3.sol';
import './RefreshRewardsRobot.t.sol';

contract GasCappedRefreshRewardsRobotTest is RefreshRewardsRobotTest {
  address public constant FAST_GAS_FEED = 0xd1cC11c5102bE7Dd8919715E6b04e1Af1e43fdc4;
  uint256 public constant CURRENT_GAS_PRICE = 10 gwei;

  event MaxGasPriceSet(uint256 indexed maxGasPrice);

  function setUp() virtual public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);

    super.setUp();
    vm.stopPrank();

    vm.startPrank(GUARDIAN);
    robotKeeper = new GasCappedRefreshRewardsRobot(
      address(factory),
      AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER,
      FAST_GAS_FEED
    );
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(CURRENT_GAS_PRICE);

    vm.stopPrank();

    // mock the gas price feed to return current gas price as the deployed one is a placeholder feed
    vm.mockCall(
      FAST_GAS_FEED,
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(CURRENT_GAS_PRICE)
    );
  }

  function test_setMaxGasPrice(uint256 newMaxGasPrice) public {
    vm.expectEmit();
    emit MaxGasPriceSet(newMaxGasPrice);

    vm.startPrank(GUARDIAN);
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(newMaxGasPrice);
    vm.stopPrank();

    assertEq(
      GasCappedRefreshRewardsRobot(address(robotKeeper)).getMaxGasPrice(),
      newMaxGasPrice
    );

    vm.expectRevert('Ownable: caller is not the owner');
    vm.startPrank(address(5));
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(newMaxGasPrice);
    vm.stopPrank();
  }

  function test_isGasPriceInRange() virtual public {
    assertEq(GasCappedRefreshRewardsRobot(address(robotKeeper)).isGasPriceInRange(), true);

    vm.startPrank(GUARDIAN);
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(
      uint256(AggregatorInterface(FAST_GAS_FEED).latestAnswer()) - 1
    );
    vm.stopPrank();

    assertEq(GasCappedRefreshRewardsRobot(address(robotKeeper)).isGasPriceInRange(), false);
  }

  function test_robotExecutionOnlyWhenGasPriceInRange() virtual public {
    // set the max gas price of the robot to lesser than the current gas price
    vm.startPrank(GUARDIAN);
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(
      uint256(AggregatorInterface(FAST_GAS_FEED).latestAnswer()) - 1
    );
    vm.stopPrank();

    address wethStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WETHe_UNDERLYING);
    address wbtcStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.WBTCe_UNDERLYING);
    address maiStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.MAI_UNDERLYING);
    address fraxStaticAToken = factory.getStaticAToken(AaveV3AvalancheAssets.FRAX_UNDERLYING);

    _createNewLM();

    // robot did not run as the network gas price is more than the max configured gas price of the robot
    bool didRobotRun = _checkAndPerformUpKeep(robotKeeper);
    assertEq(didRobotRun, false);
    
    vm.startPrank(GUARDIAN);
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(
      uint256(AggregatorInterface(FAST_GAS_FEED).latestAnswer())
    );
    vm.stopPrank();

    didRobotRun = _checkAndPerformUpKeep(robotKeeper);
    assertEq(didRobotRun, true);

    assertEq(IStaticATokenLM(wethStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(wbtcStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(maiStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
    assertEq(IStaticATokenLM(fraxStaticAToken).isRegisteredRewardToken(REWARD_TOKEN), true);
  }
}
