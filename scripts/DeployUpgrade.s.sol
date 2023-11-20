// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {MiscPolygon} from 'aave-address-book/MiscPolygon.sol';
import {MiscAvalanche} from 'aave-address-book/MiscAvalanche.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {MiscOptimism} from 'aave-address-book/MiscOptimism.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';
import {UpgradePayload} from '../src/UpgradePayload.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

library DeployUpgrade {
  function _deploy(
    ITransparentProxyFactory proxyFactory,
    address sharedProxyAdmin,
    IPool pool,
    IRewardsController rewardsController,
    address staticATokenFactory
  ) internal returns (UpgradePayload) {
    // deploy and initialize static token impl
    StaticATokenLM staticImpl = new StaticATokenLM(pool, rewardsController);

    // deploy staticATokenFactory impl
    StaticATokenFactory factoryImpl = new StaticATokenFactory(
      pool,
      sharedProxyAdmin,
      proxyFactory,
      address(staticImpl)
    );

    return
      new UpgradePayload(
        sharedProxyAdmin,
        StaticATokenFactory(staticATokenFactory),
        factoryImpl,
        address(staticImpl)
      );
  }

  function deployMainnet() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscEthereum.TRANSPARENT_PROXY_FACTORY),
        MiscEthereum.PROXY_ADMIN,
        AaveV3Ethereum.POOL,
        IRewardsController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Ethereum.STATIC_A_TOKEN_FACTORY
      );
  }
}

contract DeployMainnet is Script {
  function run() external {
    vm.startBroadcast();
    DeployUpgrade.deployMainnet();
    vm.stopBroadcast();
  }
}

contract DeployPolygon is Script {
  function run() external {
    vm.startBroadcast();
    DeployUpgrade._deploy(
      ITransparentProxyFactory(MiscPolygon.TRANSPARENT_PROXY_FACTORY),
      MiscPolygon.PROXY_ADMIN,
      AaveV3Polygon.POOL,
      IRewardsController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER),
      AaveV3Polygon.STATIC_A_TOKEN_FACTORY
    );
    vm.stopBroadcast();
  }
}

contract DeployAvalanche is Script {
  function run() external {
    vm.startBroadcast();
    DeployUpgrade._deploy(
      ITransparentProxyFactory(MiscAvalanche.TRANSPARENT_PROXY_FACTORY),
      MiscAvalanche.PROXY_ADMIN,
      AaveV3Avalanche.POOL,
      IRewardsController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER),
      AaveV3Avalanche.STATIC_A_TOKEN_FACTORY
    );
    vm.stopBroadcast();
  }
}

contract DeployOptimism is Script {
  function run() external {
    vm.startBroadcast();
    DeployUpgrade._deploy(
      ITransparentProxyFactory(MiscOptimism.TRANSPARENT_PROXY_FACTORY),
      MiscOptimism.PROXY_ADMIN,
      AaveV3Optimism.POOL,
      IRewardsController(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER),
      AaveV3Optimism.STATIC_A_TOKEN_FACTORY
    );
    vm.stopBroadcast();
  }
}

contract DeployArbitrum is Script {
  function run() external {
    vm.startBroadcast();
    DeployUpgrade._deploy(
      ITransparentProxyFactory(MiscArbitrum.TRANSPARENT_PROXY_FACTORY),
      MiscArbitrum.PROXY_ADMIN,
      AaveV3Arbitrum.POOL,
      IRewardsController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER),
      AaveV3Arbitrum.STATIC_A_TOKEN_FACTORY
    );
    vm.stopBroadcast();
  }
}
