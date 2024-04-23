// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EthereumScript, PolygonScript, AvalancheScript, ArbitrumScript, OptimismScript, MetisScript, BaseScript, BNBScript, GnosisScript} from 'aave-helpers/ScriptUtils.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Metis} from 'aave-address-book/AaveV3Metis.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {AaveV3Gnosis} from 'aave-address-book/AaveV3Gnosis.sol';
import {GasCappedRefreshRewardsRobot} from '../src/robots/GasCappedRefreshRewardsRobot.sol';
import {GelatoGasCappedRefreshRewardsRobot} from '../src/robots/GelatoGasCappedRefreshRewardsRobot.sol';
import {RefreshRewardsRobot} from '../src/robots/RefreshRewardsRobot.sol';

// make deploy-ledger contract=scripts/Robots.s.sol:DeployMainnet chain=mainnet
contract DeployMainnet is EthereumScript {
  function run() external broadcast {
    GasCappedRefreshRewardsRobot robot = new GasCappedRefreshRewardsRobot(
      AaveV3Ethereum.STATIC_A_TOKEN_FACTORY,
      AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
      0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C // chainlink fast gas feed
    );
    robot.setMaxGasPrice(150 gwei);
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployPolygon chain=polygon
contract DeployPolygon is PolygonScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3Polygon.STATIC_A_TOKEN_FACTORY,
      AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3Avalanche.STATIC_A_TOKEN_FACTORY,
      AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3Optimism.STATIC_A_TOKEN_FACTORY,
      AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3Arbitrum.STATIC_A_TOKEN_FACTORY,
      AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3Base.STATIC_A_TOKEN_FACTORY,
      AaveV3Base.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployBNB chain=bnb
contract DeployBNB is BNBScript {
  function run() external broadcast {
    new RefreshRewardsRobot(
      AaveV3BNB.STATIC_A_TOKEN_FACTORY,
      AaveV3BNB.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployMetis chain=metis
contract DeployMetis is MetisScript {
  function run() external broadcast {
    new GelatoGasCappedRefreshRewardsRobot(
      AaveV3Metis.STATIC_A_TOKEN_FACTORY,
      AaveV3Metis.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}

// make deploy-ledger contract=scripts/Robots.s.sol:DeployGnosis chain=gnosis
contract DeployGnosis is GnosisScript {
  function run() external broadcast {
    new GelatoGasCappedRefreshRewardsRobot(
      AaveV3Gnosis.STATIC_A_TOKEN_FACTORY,
      AaveV3Gnosis.DEFAULT_INCENTIVES_CONTROLLER
    );
  }
}