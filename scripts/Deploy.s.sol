// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
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

/**
 * This script will deploy the registry (which is also a factory) & transfer ownership to the aave short executor.
 */
contract DeployMainnet is Script, Test {
  ITransparentProxyFactory constant TRANSPARENT_PROXY_FACTORY =
    ITransparentProxyFactory(0xC354ce29aa85e864e55277eF47Fc6a92532Dd6Ca);

  function run() external {
    vm.startBroadcast();
    // deploy shared proxy admin
    address proxyAdmin = TRANSPARENT_PROXY_FACTORY.createProxyAdmin(
      AaveGovernanceV2.SHORT_EXECUTOR
    );

    StaticATokenFactory factory = DeployATokenFactory._deploy(
      TRANSPARENT_PROXY_FACTORY,
      proxyAdmin,
      AaveV3Ethereum.POOL
    );
    emit log_named_address('factory', address(factory));

    // create static tokens for all reserves
    address[] memory reserves = AaveV3Ethereum.POOL.getReservesList();
    address[] memory staticATokens = factory.batchCreateStaticATokens(reserves);

    vm.stopBroadcast();

    for (uint256 i = 0; i < reserves.length; i++) {
      emit log_named_address('underlying', reserves[i]);
      emit log_named_address('staticAToken', staticATokens[i]);
    }
  }
}
