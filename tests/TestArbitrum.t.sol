// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool, IPoolAddressesProvider} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {IAToken} from '../src/interfaces/IAToken.sol';
import {DeployATokenFactory} from '../scripts/Deploy.s.sol';
import {AaveMisc} from 'aave-address-book/AaveMisc.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';

contract Bla is Test {
  StaticATokenLM staticImpl;
  StaticATokenFactory factoryImpl;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 76569830);
    staticImpl = new StaticATokenLM(
      AaveV3Arbitrum.POOL,
      IRewardsController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER)
    );

    factoryImpl = new StaticATokenFactory(
      AaveV3Arbitrum.POOL,
      AaveMisc.PROXY_ADMIN_ARBITRUM,
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_ARBITRUM),
      address(staticImpl)
    );
  }

  function testDeploy() public {
    ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_ARBITRUM).create(
      address(factoryImpl),
      AaveMisc.PROXY_ADMIN_ARBITRUM,
      abi.encodeWithSelector(StaticATokenFactory.initialize.selector)
    );
  }
}
