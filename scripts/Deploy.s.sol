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
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

library DeployATokenFactory {
  function _deploy(
    ITransparentProxyFactory proxyFactory,
    address sharedProxyAdmin,
    IPool pool,
    IRewardsController rewardsController
  ) internal returns (StaticATokenFactory) {
    // deploy and initialize static token impl
    StaticATokenLM staticImpl = new StaticATokenLM(pool, rewardsController);

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
    factory.createStaticATokens(pool.getReservesList());
    return factory;
  }
}

contract DeployMainnet is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_ETHEREUM),
      AaveMisc.PROXY_ADMIN_ETHEREUM,
      AaveV3Ethereum.POOL,
      IRewardsController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER)
    );
    vm.stopBroadcast();
  }
}

contract DeployPolygon is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_POLYGON),
      AaveMisc.PROXY_ADMIN_POLYGON,
      AaveV3Polygon.POOL,
      IRewardsController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER)
    );
    vm.stopBroadcast();
  }
}

contract DeployAvalanche is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_AVALANCHE),
      AaveMisc.PROXY_ADMIN_AVALANCHE,
      AaveV3Avalanche.POOL,
      IRewardsController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER)
    );
    vm.stopBroadcast();
  }
}

contract DeployOptimism is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_OPTIMISM),
      AaveMisc.PROXY_ADMIN_OPTIMISM,
      AaveV3Optimism.POOL,
      IRewardsController(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER)
    );
    vm.stopBroadcast();
  }
}

contract DeployArbitrum is Script {
  function run() external {
    vm.startBroadcast();
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_ARBITRUM),
      AaveMisc.PROXY_ADMIN_ARBITRUM,
      AaveV3Arbitrum.POOL,
      IRewardsController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER)
    );
    vm.stopBroadcast();
  }
}

contract DeployAvalancheTokens is Script {
  function run() external {
    vm.startBroadcast();
    address[] memory chunk1 = new address[](6);
    chunk1[0] = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    chunk1[1] = 0x5947BB275c521040051D82396192181b413227A3;
    chunk1[2] = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    chunk1[3] = 0x50b7545627a5162F82A992c33b87aDc75187B218;
    chunk1[4] = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    chunk1[5] = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;

    address[] memory chunk2 = new address[](6);
    chunk2[0] = 0x63a72806098Bd3D9520cC43356dD78afe5D386D9;
    chunk2[1] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    chunk2[2] = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
    chunk2[3] = 0xD24C2Ad096400B6FBcd2ad8B24E7acBc21A1da64;
    chunk2[4] = 0x5c49b268c9841AFF1Cc3B0a418ff5c3442eE3F3b;
    chunk2[5] = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    StaticATokenFactory(0xcC47c4Fe1F7f29ff31A8b62197023aC8553C7896).createStaticATokens(chunk1);
    StaticATokenFactory(0xcC47c4Fe1F7f29ff31A8b62197023aC8553C7896).createStaticATokens(chunk2);
    vm.stopBroadcast();
  }
}
