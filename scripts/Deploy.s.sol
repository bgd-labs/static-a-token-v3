// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {EthereumScript, PolygonScript, AvalancheScript, ArbitrumScript, OptimismScript, MetisScript, BaseScript, BNBScript, ScrollScript} from 'aave-helpers/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {MiscPolygon} from 'aave-address-book/MiscPolygon.sol';
import {MiscAvalanche} from 'aave-address-book/MiscAvalanche.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {MiscOptimism} from 'aave-address-book/MiscOptimism.sol';
import {MiscMetis} from 'aave-address-book/MiscMetis.sol';
import {MiscBase} from 'aave-address-book/MiscBase.sol';
import {MiscBNB} from 'aave-address-book/MiscBNB.sol';
import {MiscScroll} from 'aave-address-book/MiscScroll.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Metis} from 'aave-address-book/AaveV3Metis.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {AaveV3Scroll} from 'aave-address-book/AaveV3Scroll.sol';
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
    // factory.createStaticATokens(pool.getReservesList());
    return factory;
  }
}

contract DeployMainnet is EthereumScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscEthereum.TRANSPARENT_PROXY_FACTORY),
      MiscEthereum.PROXY_ADMIN,
      AaveV3Ethereum.POOL,
      IRewardsController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployPolygon is PolygonScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscPolygon.TRANSPARENT_PROXY_FACTORY),
      MiscPolygon.PROXY_ADMIN,
      AaveV3Polygon.POOL,
      IRewardsController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployAvalanche is AvalancheScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscAvalanche.TRANSPARENT_PROXY_FACTORY),
      MiscAvalanche.PROXY_ADMIN,
      AaveV3Avalanche.POOL,
      IRewardsController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscOptimism.TRANSPARENT_PROXY_FACTORY),
      MiscOptimism.PROXY_ADMIN,
      AaveV3Optimism.POOL,
      IRewardsController(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployArbitrum is ArbitrumScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscArbitrum.TRANSPARENT_PROXY_FACTORY),
      MiscArbitrum.PROXY_ADMIN,
      AaveV3Arbitrum.POOL,
      IRewardsController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployMetis is MetisScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscMetis.TRANSPARENT_PROXY_FACTORY),
      MiscMetis.PROXY_ADMIN,
      AaveV3Metis.POOL,
      IRewardsController(AaveV3Metis.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

contract DeployBase is BaseScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscBase.TRANSPARENT_PROXY_FACTORY),
      MiscBase.PROXY_ADMIN,
      AaveV3Base.POOL,
      IRewardsController(AaveV3Base.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

/**
 * make deploy-ledger contract=scripts/Deploy.s.sol:DeployBNB chain=bnb
 */
contract DeployBNB is BNBScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscBNB.TRANSPARENT_PROXY_FACTORY),
      MiscBNB.PROXY_ADMIN,
      AaveV3BNB.POOL,
      IRewardsController(AaveV3BNB.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}

/**
 * make deploy-ledger contract=scripts/Deploy.s.sol:DeployScroll chain=scroll
 */
contract DeployScroll is ScrollScript {
  function run() external broadcast {
    DeployATokenFactory._deploy(
      ITransparentProxyFactory(MiscScroll.TRANSPARENT_PROXY_FACTORY),
      MiscScroll.PROXY_ADMIN,
      AaveV3Scroll.POOL,
      IRewardsController(AaveV3Scroll.DEFAULT_INCENTIVES_CONTROLLER)
    );
  }
}
