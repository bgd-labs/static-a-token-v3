// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool, IPoolAddressesProvider} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';

abstract contract BaseTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address internal spender;

  uint256 internal userPrivateKey;
  uint256 internal spenderPrivateKey;

  StaticATokenLM public staticATokenLM;
  address public proxyAdmin;
  StaticATokenFactory public factory;

  function REWARD_TOKEN() external virtual returns (address);

  function UNDERLYING() external virtual returns (address);

  function A_TOKEN() external virtual returns (address);

  function pool() external virtual returns (IPool);

  function setUp() public virtual {
    userPrivateKey = 0xA11CE;
    spenderPrivateKey = 0xB0B0;
    user = address(vm.addr(userPrivateKey));
    user1 = address(vm.addr(2));
    spender = vm.addr(spenderPrivateKey);

    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    proxyAdmin = proxyFactory.createProxyAdmin(ADMIN);
    StaticATokenLM staticImpl = new StaticATokenLM();
    StaticATokenFactory factoryImpl = new StaticATokenFactory(
      this.pool(),
      proxyAdmin,
      proxyFactory,
      address(staticImpl)
    );

    factory = StaticATokenFactory(
      proxyFactory.create(
        address(factoryImpl),
        proxyAdmin,
        abi.encodeWithSelector(StaticATokenFactory.initialize.selector)
      )
    );

    staticATokenLM = StaticATokenLM(
      factory.createStaticAToken(this.UNDERLYING())
    );
    vm.startPrank(user);
  }

  function _fundUser(uint128 amountToDeposit, address targetUser) internal {
    deal(this.UNDERLYING(), targetUser, amountToDeposit);
  }

  function _skipBlocks(uint128 blocks) internal {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _underlyingToAToken(uint256 amountToDeposit, address targetUser)
    internal
  {
    IERC20(this.UNDERLYING()).approve(address(this.pool()), amountToDeposit);
    this.pool().deposit(this.UNDERLYING(), amountToDeposit, targetUser, 0);
  }

  function _depositAToken(uint256 amountToDeposit, address targetUser)
    internal
    returns (uint256)
  {
    _underlyingToAToken(amountToDeposit, targetUser);
    IERC20(this.A_TOKEN()).approve(address(staticATokenLM), amountToDeposit);
    return staticATokenLM.deposit(amountToDeposit, targetUser);
  }

  function testAdmin() public {
    vm.stopPrank();
    vm.startPrank(proxyAdmin);
    assertEq(
      TransparentUpgradeableProxy(payable(address(staticATokenLM))).admin(),
      proxyAdmin
    );
    assertEq(
      TransparentUpgradeableProxy(payable(address(factory))).admin(),
      proxyAdmin
    );
  }
}
