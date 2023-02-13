// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {AaveMisc} from 'aave-address-book/AaveMisc.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';

library DeployATokenFactory {
  function _deploy(
    ITransparentProxyFactory proxyFactory,
    address sharedProxyAdmin,
    IPool pool
  ) internal {
    // deploy and initialize static token impl
    StaticATokenLM staticImpl = new StaticATokenLM();

    // deploy staticATokenFactory impl
    StaticATokenFactory factoryImpl = new StaticATokenFactory(
      pool,
      sharedProxyAdmin,
      proxyFactory,
      address(staticImpl)
    );

    // deploy factory proxy
    StaticATokenFactory factory = StaticATokenFactory(
      proxyFactory.create(
        address(factoryImpl),
        sharedProxyAdmin,
        abi.encodeWithSelector(StaticATokenFactory.initialize.selector)
      )
    );
    factory.batchCreateStaticATokens(POOL.getReservesList());
  }
}

contract DeployMainnet is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      AaveMisc.TRANSPARENT_PROXY_FACTORY_ETHEREUM,
      AaveMisc.PROXY_ADMIN_ETHEREUM,
      AaveV3Ethereum.POOL
    );
    vm.stopBroadcast();
  }
}

contract DeployPolygon is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      AaveMisc.TRANSPARENT_PROXY_FACTORY_POLYGON,
      AaveMisc.PROXY_ADMIN_POLYGON,
      AaveV3Polygon.POOL
    );
    vm.stopBroadcast();
  }
}

contract DeployAvalanche is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      AaveMisc.TRANSPARENT_PROXY_FACTORY_AVALANCHE,
      AaveMisc.PROXY_ADMIN_AVALANCHE,
      AaveV3Avalanche.POOL
    );
    vm.stopBroadcast();
  }
}

contract DeployOptimism is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      AaveMisc.TRANSPARENT_PROXY_FACTORY_OPTIMISM,
      AaveMisc.PROXY_ADMIN_OPTIMISM,
      AaveV3Optimism.POOL
    );
    vm.stopBroadcast();
  }
}

contract DeployArbitrum is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      AaveMisc.TRANSPARENT_PROXY_FACTORY_ARBITRUM,
      AaveMisc.PROXY_ADMIN_ARBITRUM,
      AaveV3Arbitrum.POOL
    );
    vm.stopBroadcast();
  }
}
