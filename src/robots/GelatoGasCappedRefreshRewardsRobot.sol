// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {GasCappedRefreshRewardsRobot} from './GasCappedRefreshRewardsRobot.sol';
import {IGasPriceCappedRobot} from 'aave-governance-v3-robot/interfaces/IGasPriceCappedRobot.sol';

/**
 * @title GelatoGasCappedRefreshRewardsRobot
 * @author BGD Labs
 * @notice Automation contract to automate refresh rewards for staticATokens.
 *         The difference from GasCappedRefreshRewardsRobot is that we use tx.gasprice
 *         instead of gas price oracle in order to limit the execution of the robot.
 */
contract GelatoGasCappedRefreshRewardsRobot is GasCappedRefreshRewardsRobot {
  /**
   * @param staticATokenFactory address of the static a token factory contract.
   * @param rewardsController address of the rewards controller of the protocol.
   */
  constructor(
    address staticATokenFactory,
    address rewardsController
  ) GasCappedRefreshRewardsRobot(staticATokenFactory, rewardsController, address(0)) {}

  /// @inheritdoc IGasPriceCappedRobot
  function isGasPriceInRange() public view virtual override returns (bool) {
    if (tx.gasprice > _maxGasPrice) {
      return false;
    }
    return true;
  }
}
