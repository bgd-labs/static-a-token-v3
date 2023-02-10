// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
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
  ) internal returns (StaticATokenFactory) {
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

    return factory;
  }
}

contract FactoryDeployment is Script, Test {
  IPool immutable POOL;
  ITransparentProxyFactory immutable TRANSPARENT_PROXY_FACTORY;

  constructor(IPool pool, ITransparentProxyFactory proxyFactory) {
    POOL = pool;
    TRANSPARENT_PROXY_FACTORY = proxyFactory;
  }

  /**
   * Deployes the factory
   */
  function _deployFactory(address proxyAdmin)
    internal
    returns (StaticATokenFactory)
  {
    StaticATokenFactory factory = DeployATokenFactory._deploy(
      TRANSPARENT_PROXY_FACTORY,
      proxyAdmin,
      POOL
    );
    emit log_named_address('factory', address(factory));
    return factory;
  }

  /**
   * Creates static tokens for all reserves.
   */
  function _deployAllTokens(StaticATokenFactory factory) internal {
    address[] memory reserves = POOL.getReservesList();
    address[] memory staticATokens = factory.batchCreateStaticATokens(reserves);

    for (uint256 i = 0; i < reserves.length; i++) {
      emit log_named_address('underlying', reserves[i]);
      emit log_named_address('staticAToken', staticATokens[i]);
    }
  }
}

/**
 * This script will deploy the registry (which is also a factory) & transfer ownership to the aave short executor.
 */
contract DeployMainnet is FactoryDeployment {
  constructor()
    FactoryDeployment(
      AaveV3Ethereum.POOL,
      // TODO: fetch from address book
      ITransparentProxyFactory(0xC354ce29aa85e864e55277eF47Fc6a92532Dd6Ca)
    )
  {}

  function run() external {
    vm.startBroadcast();
    // deploy shared proxy admin
    // TODO: should be pre-deployed and fetched from address book
    address proxyAdmin = ITransparentProxyFactory(
      0xC354ce29aa85e864e55277eF47Fc6a92532Dd6Ca
    ).createProxyAdmin(AaveGovernanceV2.SHORT_EXECUTOR);

    StaticATokenFactory factory = _deployFactory(proxyAdmin);

    _deployAllTokens(factory);

    vm.stopBroadcast();
  }
}
