// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AaveV3Polygon, IPool} from 'aave-address-book/AaveV3Polygon.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {StaticATokenLM, IERC20, IERC20Metadata} from '../src/StaticATokenLM.sol';

contract StaticATokenTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address constant REWARD_TOKEN = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
  address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address constant aWETH = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  IPool pool = IPool(AaveV3Polygon.POOL);
  StaticATokenLM staticATokenLM;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 33718273);
    user = address(vm.addr(1));
    user1 = address(vm.addr(2));
    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    StaticATokenLM staticATokenLMImpl = new StaticATokenLM();
    hoax(OWNER);
    staticATokenLM = StaticATokenLM(
      proxyFactory.create(
        address(staticATokenLMImpl),
        ADMIN,
        abi.encodeWithSelector(
          StaticATokenLM.initialize.selector,
          pool,
          aWETH,
          'Static Aave WETH',
          'stataWETH'
        )
      )
    );
    vm.startPrank(user);
  }

  function _fundUser(uint128 amountToDeposit, address user) private {
    deal(WETH, user, amountToDeposit);
  }

  function _skipBlocks(uint128 blocks) private {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _wethToAWeth(uint256 amountToDeposit, address user) private {
    IERC20(WETH).approve(address(pool), amountToDeposit);
    pool.deposit(WETH, amountToDeposit, user, 0);
  }

  function _depositAWeth(uint256 amountToDeposit, address user)
    private
    returns (uint256)
  {
    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    return staticATokenLM.deposit(amountToDeposit, user);
  }

  // test rewards
  function testCollectAndUpdateRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    IERC20(WETH).approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);

    _skipBlocks(60);
    assertEq(IERC20(REWARD_TOKEN).balanceOf(address(staticATokenLM)), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertEq(staticATokenLM.collectAndUpdateRewards(), 0);
    assertEq(IERC20(REWARD_TOKEN).balanceOf(address(staticATokenLM)), 0);
  }

  function testClaimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    IERC20(WETH).approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }
}
