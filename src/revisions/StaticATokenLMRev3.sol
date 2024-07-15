// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

import {StaticATokenLM} from '../StaticATokenLM.sol';
import {IReinitializer} from './IReinitializer.sol';

/**
 * @title StaticATokenLMRevision3
 * @notice Contract to re initialize the deployed StaticATokenLM with revision 3
 * @author BGD labs
 */
contract StaticATokenLMRevision3 is StaticATokenLM, IReinitializer {
  constructor(
    IPool pool,
    IRewardsController rewardsController
  ) StaticATokenLM(pool, rewardsController) {}

  /// @inheritdoc IReinitializer
  function initializeRevision() external reinitializer(3) {}
}
