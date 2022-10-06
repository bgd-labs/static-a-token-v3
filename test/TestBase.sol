// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';

contract BaseTest is Test {
  //   address constant OWNER = address(1234);
  //   address constant ADMIN = address(2345);
  //   address public user;
  //   address public user1;
  //   address internal spender;
  //   uint256 internal userPrivateKey;
  //   uint256 internal spenderPrivateKey;
  //   function setUp() public {
  //     userPrivateKey = 0xA11CE;
  //     spenderPrivateKey = 0xB0B0;
  //     user = address(vm.addr(userPrivateKey));
  //     user1 = address(vm.addr(2));
  //     spender = vm.addr(spenderPrivateKey);
  //     TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
  //     StaticATokenLM staticATokenLMImpl = new StaticATokenLM();
  //     hoax(OWNER);
  //     staticATokenLM = StaticATokenLM(
  //       proxyFactory.create(
  //         address(staticATokenLMImpl),
  //         ADMIN,
  //         abi.encodeWithSelector(
  //           StaticATokenLM.initialize.selector,
  //           pool,
  //           aWETH,
  //           'Static Aave WETH',
  //           'stataWETH'
  //         )
  //       )
  //     );
  //     vm.startPrank(user);
  //   }
}
