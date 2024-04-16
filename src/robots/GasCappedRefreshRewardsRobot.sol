// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from 'chainlink/src/v0.8/interfaces/automation/AutomationCompatibleInterface.sol';
import {GasCappedRobotBase} from 'aave-governance-v3-robot/contracts/gasprice-capped-robots/GasCappedRobotBase.sol';
import {RefreshRewardsRobot} from './RefreshRewardsRobot.sol';

/**
 * @title GasCappedRefreshRewardsRobot
 * @author BGD Labs
 * @notice Automation contract to automate refresh rewards for staticATokens if a reward
 *         is added after staticAToken creation to register the missing rewards.
 *         The difference from RefreshRewardsRobot is that automation is only
 *         performed when the network gas price in within the maximum configured range.
 */
contract GasCappedRefreshRewardsRobot is RefreshRewardsRobot, GasCappedRobotBase {
  /**
   * @param staticATokenFactory address of the static a token factory contract.
   * @param rewardsController address of the rewards controller of the protocol.
   * @param gasPriceOracle address of the gas price oracle contract.
   */
  constructor(
    address staticATokenFactory, 
    address rewardsController, address 
    gasPriceOracle
  ) RefreshRewardsRobot(staticATokenFactory, rewardsController) GasCappedRobotBase(gasPriceOracle) {}

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev runs off-chain, checks if there is a reward added after statToken creation which needs to be registered.
   *      also checks that the gas price of the network in within range to perform actions.
   */
  function checkUpkeep(bytes memory) public view override returns (bool, bytes memory) {
    if (!isGasPriceInRange()) return (false, '');

    return super.checkUpkeep('');
  }
}
