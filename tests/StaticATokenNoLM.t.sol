// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AaveV3Polygon, IPool} from 'aave-address-book/AaveV3Polygon.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {StaticATokenLM, IERC20, IERC20Metadata} from '../src/StaticATokenLM.sol';
import {BaseTest} from './TestBase.sol';

/**
 * Testing the static token wrapper on a pool that never had LM enabled (polygon v3 pool at block 33718273)
 * This is a slightly different assumption than a pool that doesn't have LM enabled any more as incentivesController.rewardTokens() will have length=0
 */
contract StaticATokenNoLMTest is BaseTest {
  address public constant override UNDERLYING =
    0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address public constant override A_TOKEN =
    0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;

  IPool public override pool = IPool(AaveV3Polygon.POOL);

  address[] rewardTokens;

  function REWARD_TOKEN() public returns (address) {
    return rewardTokens[0];
  }

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('polygon'), 37747173);
    rewardTokens.push(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    super.setUp();
  }

  // test rewards
  function test_collectAndUpdateRewardsWithLMDisabled() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), 0);
    assertEq(staticATokenLM.collectAndUpdateRewards(REWARD_TOKEN()), 0);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
  }

  function test_claimRewardsToSelfWithLMDisabled() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(
      user,
      REWARD_TOKEN()
    );
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(claimable, 0);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
  }
}
