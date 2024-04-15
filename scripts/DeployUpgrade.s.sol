// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {EthereumScript, PolygonScript, AvalancheScript, ArbitrumScript, OptimismScript, MetisScript, BaseScript, BNBScript, ScrollScript, BaseScript, GnosisScript} from 'aave-helpers/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {MiscPolygon} from 'aave-address-book/MiscPolygon.sol';
import {MiscAvalanche} from 'aave-address-book/MiscAvalanche.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {MiscOptimism} from 'aave-address-book/MiscOptimism.sol';
import {MiscMetis} from 'aave-address-book/MiscMetis.sol';
import {MiscBNB} from 'aave-address-book/MiscBNB.sol';
import {MiscScroll} from 'aave-address-book/MiscScroll.sol';
import {MiscGnosis} from 'aave-address-book/MiscGnosis.sol';
import {MiscBase} from 'aave-address-book/MiscBase.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {AaveV3Scroll} from 'aave-address-book/AaveV3Scroll.sol';
import {AaveV3Metis} from 'aave-address-book/AaveV3Metis.sol';
import {AaveV3Gnosis} from 'aave-address-book/AaveV3Gnosis.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
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

  function deployPolygon() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscPolygon.TRANSPARENT_PROXY_FACTORY),
        MiscPolygon.PROXY_ADMIN,
        AaveV3Polygon.POOL,
        IRewardsController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Polygon.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployAvalanche() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscAvalanche.TRANSPARENT_PROXY_FACTORY),
        MiscAvalanche.PROXY_ADMIN,
        AaveV3Avalanche.POOL,
        IRewardsController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Avalanche.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployOptimism() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscOptimism.TRANSPARENT_PROXY_FACTORY),
        MiscOptimism.PROXY_ADMIN,
        AaveV3Optimism.POOL,
        IRewardsController(AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Optimism.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployArbitrum() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscArbitrum.TRANSPARENT_PROXY_FACTORY),
        MiscArbitrum.PROXY_ADMIN,
        AaveV3Arbitrum.POOL,
        IRewardsController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Arbitrum.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployMetis() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscMetis.TRANSPARENT_PROXY_FACTORY),
        MiscMetis.PROXY_ADMIN,
        AaveV3Metis.POOL,
        IRewardsController(AaveV3Metis.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Metis.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployBNB() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscBNB.TRANSPARENT_PROXY_FACTORY),
        MiscBNB.PROXY_ADMIN,
        AaveV3BNB.POOL,
        IRewardsController(AaveV3BNB.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3BNB.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployScroll() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscScroll.TRANSPARENT_PROXY_FACTORY),
        MiscScroll.PROXY_ADMIN,
        AaveV3Scroll.POOL,
        IRewardsController(AaveV3Scroll.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Scroll.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployBase() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscBase.TRANSPARENT_PROXY_FACTORY),
        MiscBase.PROXY_ADMIN,
        AaveV3Base.POOL,
        IRewardsController(AaveV3Base.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Base.STATIC_A_TOKEN_FACTORY
      );
  }

  function deployGnosis() internal returns (UpgradePayload) {
    return
      _deploy(
        ITransparentProxyFactory(MiscGnosis.TRANSPARENT_PROXY_FACTORY),
        MiscGnosis.PROXY_ADMIN,
        AaveV3Gnosis.POOL,
        IRewardsController(AaveV3Gnosis.DEFAULT_INCENTIVES_CONTROLLER),
        AaveV3Gnosis.STATIC_A_TOKEN_FACTORY
      );
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployMainnet chain=mainnet
contract DeployMainnet is EthereumScript {
  function run() external broadcast {
    DeployUpgrade.deployMainnet();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployPolygon chain=polygon
contract DeployPolygon is PolygonScript {
  function run() external broadcast {
    DeployUpgrade.deployPolygon();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external broadcast {
    DeployUpgrade.deployAvalanche();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    DeployUpgrade.deployOptimism();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external broadcast {
    DeployUpgrade.deployArbitrum();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployMetis chain=metis
contract DeployMetis is MetisScript {
  function run() external broadcast {
    DeployUpgrade.deployMetis();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployBNB chain=bnb
contract DeployBNB is BNBScript {
  function run() external broadcast {
    DeployUpgrade.deployBNB();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployScroll chain=scroll
contract DeployScroll is ScrollScript {
  function run() external broadcast {
    DeployUpgrade.deployScroll();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external broadcast {
    DeployUpgrade.deployBase();
  }
}

// make deploy-ledger contract=scripts/DeployUpgrade.s.sol:DeployGnosis chain=gnosis
contract DeployGnosis is GnosisScript {
  function run() external broadcast {
    DeployUpgrade.deployGnosis();
  }
}
