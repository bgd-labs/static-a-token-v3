// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StaticATokenFactory} from './StaticATokenFactory.sol';
import {IRefreshRobotKeeper} from './interfaces/IRefreshRobotKeeper.sol';
import {IStaticATokenLM} from './interfaces/IStaticATokenLM.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @title RefreshRobotKeeper
 * @author BGD Labs
 * @notice Automation contract to automate refresh rewards for staticATokens if a reward
 *         is added after staticAToken creation to register the missing rewards.
 */
contract RefreshRobotKeeper is Ownable, IRefreshRobotKeeper {
  mapping(address => bool) internal disabledStaticATokens;

  StaticATokenFactory public immutable STATIC_A_TOKEN_FACTORY;
  IRewardsController public immutable REWARDS_CONTROLLER;

  uint256 public constant MAX_ACTIONS = 10;
  error NoActionCanBePerformed();

  constructor(StaticATokenFactory staticATokenFactory, IRewardsController rewardsController) {
    STATIC_A_TOKEN_FACTORY = staticATokenFactory;
    REWARDS_CONTROLLER = rewardsController;
  }

  /**
   * @dev runs off-chain, checks if there is a reward added after statToken creation which needs to be registered.
   */
  function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
    address[] memory staticATokensToRefresh = new address[](MAX_ACTIONS);
    address[] memory staticATokens = STATIC_A_TOKEN_FACTORY.getStaticATokens();
    uint256 actionsCount = 0;

    for (uint i = 0; i < staticATokens.length; i++) {
      address aTokenAddress = address(IStaticATokenLM(staticATokens[i]).aToken());
      address[] memory rewards = REWARDS_CONTROLLER.getRewardsByAsset(
        aTokenAddress
      );

      for (uint256 j = 0; j < rewards.length; j++) {
        bool isRegisteredReward = IStaticATokenLM(staticATokens[i]).isRegisteredRewardToken(
          rewards[j]
        );
        if (!isRegisteredReward && actionsCount < MAX_ACTIONS && !isDisabled(staticATokens[i])) {
          staticATokensToRefresh[actionsCount] = staticATokens[i];
          actionsCount++;
        }
      }
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with MAX_ACTIONS
      // and then squeeze the array using mstore
      assembly {
        mstore(staticATokensToRefresh, actionsCount)
      }
      bytes memory performData = abi.encode(staticATokensToRefresh);
      return (true, performData);
    }

    return (false, '');
  }

  function performUpkeep(bytes calldata performData) external override {
    address[] memory staticATokensToRefresh = abi.decode(performData, (address[]));
    bool isActionPerformed;

    for (uint256 i = 0; i < staticATokensToRefresh.length; i++) {
      try IStaticATokenLM(staticATokensToRefresh[i]).refreshRewardTokens() {
        isActionPerformed = true;
      } catch Error(string memory reason) {
        emit ActionFailed(staticATokensToRefresh[i], reason);
      }
    }

    if (!isActionPerformed) revert NoActionCanBePerformed();
  }

  /// @inheritdoc IRefreshRobotKeeper
  function isDisabled(address staticAToken) public view returns (bool) {
    return disabledStaticATokens[staticAToken];
  }

  /// @inheritdoc IRefreshRobotKeeper
  function disableAutomation(address staticAToken) external onlyOwner {
    disabledStaticATokens[staticAToken] = true;
  }
}
