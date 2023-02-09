// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';

/**
 * This script will deploy the registry (which is also a factory) & transfer ownership to the aave short executor.
 */
contract Deploy is Script {
  ITransparentProxyFactory constant TRANSPARENT_PROXY_FACTORY =
    ITransparentProxyFactory(0xC354ce29aa85e864e55277eF47Fc6a92532Dd6Ca);

  function run() external {
    vm.startBroadcast();
    // deploy shared proxy admin
    address proxyAdmin = TRANSPARENT_PROXY_FACTORY.createProxyAdmin(
      AaveGovernanceV2.SHORT_EXECUTOR
    );

    // deploy and initialize static token impl
    StaticATokenLM staticImpl = new StaticATokenLM();
    staticImpl.initialize(
      AaveV3Ethereum.POOL,
      address(0), // TODO: it needs to be initialized with some token
      'STATIC_A_TOKEN_NAME',
      'STATIC_A_TOKEN_SYMBOL'
    );

    // deploy staticATokenFactory
    StaticATokenFactory factoryImpl = new StaticATokenFactory(
      AaveV3Ethereum.POOL,
      proxyAdmin,
      TRANSPARENT_PROXY_FACTORY,
      address(staticImpl)
    );
    StaticATokenFactory factory = StaticATokenFactory(
      TRANSPARENT_PROXY_FACTORY.create(
        address(factoryImpl),
        proxyAdmin,
        abi.encodeWithSelector(StaticATokenFactory.initialize.selector)
      )
    );

    // create static tokens for all reserves
    factory.batchCreateStaticATokens(AaveV3Ethereum.POOL.getReservesList());
    vm.stopBroadcast();
  }
}
