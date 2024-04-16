// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {GelatoGasCappedRefreshRewardsRobot} from '../src/robots/GelatoGasCappedRefreshRewardsRobot.sol';
import './GasCappedRefreshRewardsRobot.t.sol';

contract GelatoGasCappedRefreshRewardsRobotTest is GasCappedRefreshRewardsRobotTest {
  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(GUARDIAN);
    robotKeeper = new GelatoGasCappedRefreshRewardsRobot(
      address(factory),
      AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER
    );
    GasCappedRefreshRewardsRobot(address(robotKeeper)).setMaxGasPrice(CURRENT_GAS_PRICE);

    vm.stopPrank();

    // set the gasPrice of the network, as the default is 0
    vm.txGasPrice(CURRENT_GAS_PRICE);
  }
}
