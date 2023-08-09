// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from 'chainlink/src/v0.8/interfaces/automation/AutomationCompatibleInterface.sol';

/**
 * @title IRefreshRobotKeeper
 * @author BGD Labs
 * @notice Defines the interface for the contract to automate refresh rewards for staticATokens.
 **/
interface IRefreshRobotKeeper is AutomationCompatibleInterface {
  event RefreshFailed(address staticAToken, string reason);

  /**
   * @notice method to check if the staticAToken is disabled for automation.
   * @param staticAToken - staticAToken to check if disabled for refresh rewards automation.
   **/
  function isDisabled(address staticAToken) external view returns (bool);

  /**
   * @notice method to disable automation for the staticAToken.
   * @param staticAToken - staticAToken to disable automation for refresh rewards.
   **/
  function disableAutomation(address staticAToken) external;
}
