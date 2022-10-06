// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';

contract BaseTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address internal spender;

  uint256 internal userPrivateKey;
  uint256 internal spenderPrivateKey;

  StaticATokenLM public staticATokenLM;

  function REWARD_TOKEN() external virtual returns (address) {
    return 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  }

  function WETH() external virtual returns (address) {
    return 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  }

  function aWETH() external virtual returns (address) {
    return 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  }

  function pool() external virtual returns (IPool) {
    return IPool(AaveV3Avalanche.POOL);
  }

  function setUp() public virtual {
    userPrivateKey = 0xA11CE;
    spenderPrivateKey = 0xB0B0;
    user = address(vm.addr(userPrivateKey));
    user1 = address(vm.addr(2));
    spender = vm.addr(spenderPrivateKey);
    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    StaticATokenLM staticATokenLMImpl = new StaticATokenLM();
    hoax(OWNER);
    staticATokenLM = StaticATokenLM(
      proxyFactory.create(
        address(staticATokenLMImpl),
        ADMIN,
        abi.encodeWithSelector(
          StaticATokenLM.initialize.selector,
          this.pool(),
          this.aWETH(),
          'Static Aave WETH',
          'stataWETH'
        )
      )
    );
    vm.startPrank(user);
  }

  function _fundUser(uint128 amountToDeposit, address targetUser) internal {
    deal(this.WETH(), targetUser, amountToDeposit);
  }

  function _skipBlocks(uint128 blocks) internal {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _wethToAWeth(uint256 amountToDeposit, address targetUser) internal {
    IERC20(this.WETH()).approve(address(this.pool()), amountToDeposit);
    this.pool().deposit(this.WETH(), amountToDeposit, targetUser, 0);
  }

  function _depositAWeth(uint256 amountToDeposit, address targetUser)
    internal
    returns (uint256)
  {
    _wethToAWeth(amountToDeposit, targetUser);
    IERC20(this.aWETH()).approve(address(staticATokenLM), amountToDeposit);
    return staticATokenLM.deposit(amountToDeposit, targetUser);
  }
}
