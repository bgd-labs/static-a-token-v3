// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import '../src/StaticATokenLMV2.sol';
import {WETH9} from 'aave-v3-core/contracts/dependencies/weth/WETH9.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

contract StaticATokenLMTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
  address constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  address payable constant WETH =
    payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address constant aWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
  IPool pool = IPool(LENDING_POOL);
  StaticATokenLMV2 staticATokenLM;
  WETH9 weth;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 15573889);
    user = address(vm.addr(1));
    user1 = address(vm.addr(2));
    weth = WETH9(WETH);
    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    StaticATokenLMV2 staticATokenLMImpl = new StaticATokenLMV2();
    hoax(OWNER);
    staticATokenLM = StaticATokenLMV2(
      proxyFactory.create(
        address(staticATokenLMImpl),
        ADMIN,
        abi.encodeWithSelector(
          StaticATokenLMV2.initialize.selector,
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
    vm.deal(user, 100 ether);
    weth.deposit{value: amountToDeposit}();
  }

  function _skipBlocks(uint128 blocks) private {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _wethToAWeth(uint256 amountToDeposit, address user) private {
    weth.approve(address(pool), amountToDeposit);
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

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);

    _skipBlocks(60);
    assertEq(IERC20(STK_AAVE).balanceOf(address(staticATokenLM)), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertEq(staticATokenLM.collectAndUpdateRewards(), 0);
    assertEq(IERC20(STK_AAVE).balanceOf(address(staticATokenLM)), 0);
  }

  function testClaimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }
}
