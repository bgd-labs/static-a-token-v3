// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStaticATokenFactory} from '../interfaces/IStaticATokenFactory.sol';
import {IRefreshRewardsRobot, AutomationCompatibleInterface} from '../interfaces/IRefreshRewardsRobot.sol';
import {IStaticATokenLM} from '../interfaces/IStaticATokenLM.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @title RefreshRewardsRobot
 * @author BGD Labs
 * @notice Automation contract to automate refresh rewards for staticATokens if a reward
 *         is added after staticAToken creation to register the missing rewards.
 */
contract RefreshRewardsRobot is Ownable, IRefreshRewardsRobot {
  mapping(address => bool) internal disabledStaticATokens;

  /// @inheritdoc IRefreshRewardsRobot
  IStaticATokenFactory public immutable STATIC_A_TOKEN_FACTORY;

  /// @inheritdoc IRefreshRewardsRobot
  IRewardsController public immutable REWARDS_CONTROLLER;

  /// @inheritdoc IRefreshRewardsRobot
  uint256 public constant MAX_ACTIONS = 10;

  /**
   * @param staticATokenFactory address of the static a token factory contract.
   * @param rewardsController address of the rewards controller of the protocol.
   */
  constructor(address staticATokenFactory, address rewardsController) {
    STATIC_A_TOKEN_FACTORY = IStaticATokenFactory(staticATokenFactory);
    REWARDS_CONTROLLER = IRewardsController(rewardsController);
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev runs off-chain, checks if there is a reward added after statToken creation which needs to be registered.
   */
  function checkUpkeep(bytes memory) public view virtual override returns (bool, bytes memory) {
    address[] memory staticATokensToRefresh = new address[](MAX_ACTIONS);
    address[] memory staticATokens = STATIC_A_TOKEN_FACTORY.getStaticATokens();
    uint256 actionsCount = 0;

    for (uint i = 0; i < staticATokens.length; i++) {
      address aTokenAddress = address(IStaticATokenLM(staticATokens[i]).aToken());
      address[] memory rewards = REWARDS_CONTROLLER.getRewardsByAsset(aTokenAddress);

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

  /**
   * @dev executes refreshRewardTokens() on the staticAToken to register the missing rewards
   * @param performData array of staticATokens for which refresh needs to be performed
   */
  function performUpkeep(bytes calldata performData) external override {
    address[] memory staticATokensToRefresh = abi.decode(performData, (address[]));

    for (uint256 i = 0; i < staticATokensToRefresh.length; i++) {
      IStaticATokenLM(staticATokensToRefresh[i]).refreshRewardTokens();
      emit RefreshSucceeded(staticATokensToRefresh[i]);
    }
  }

  /// @inheritdoc IRefreshRewardsRobot
  function isDisabled(address staticAToken) public view returns (bool) {
    return disabledStaticATokens[staticAToken];
  }

  /// @inheritdoc IRefreshRewardsRobot
  function disableAutomation(address staticAToken, bool disable) external onlyOwner {
    disabledStaticATokens[staticAToken] = disable;
  }
}
