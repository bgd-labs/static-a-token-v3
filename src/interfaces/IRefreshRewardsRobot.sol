// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from 'chainlink/src/v0.8/interfaces/automation/AutomationCompatibleInterface.sol';
import {IStaticATokenFactory} from './IStaticATokenFactory.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

/**
 * @title IRefreshRewardsRobot
 * @author BGD Labs
 * @notice Defines the interface for the contract to automate refresh rewards for staticATokens.
 **/
interface IRefreshRewardsRobot is AutomationCompatibleInterface {
  /**
   * @notice emitted when rewards are refreshed for a staticAToken.
   * @param staticAToken address of the staticAToken for which rewards have been refreshed.
   */
  event RefreshSucceeded(address indexed staticAToken);

  /**
   * @notice method to check if the staticAToken is disabled for automation.
   * @param staticAToken staticAToken to check if disabled for refresh rewards automation.
   **/
  function isDisabled(address staticAToken) external view returns (bool);

  /**
   * @notice method to disable automation for the staticAToken.
   * @param staticAToken staticAToken to disable automation for refresh rewards.
   * @param disable bool true to disable automation, false to enable it back.
   **/
  function disableAutomation(address staticAToken, bool disable) external;

  /**
   * @notice method to get the maximum number of actions that can be performed by the robot in one performUpkeep.
   * @return max number of actions.
   */
  function MAX_ACTIONS() external returns (uint256);

  /**
   * @notice method to get the rewards controller of the protocol.
   * @return address of the aave rewards controller.
   */
  function REWARDS_CONTROLLER() external returns (IRewardsController);

  /**
   * @notice method to get the static a token factory.
   * @return address of the static a token factory contract.
   */
  function STATIC_A_TOKEN_FACTORY() external returns (IStaticATokenFactory);
}
