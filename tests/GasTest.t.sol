// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {AaveV3Ethereum, IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {DeployATokenFactory} from '../scripts/Deploy.s.sol';

/**
 * Testing the static token wrapper on a pool that never had LM enabled (polygon v3 pool at block 33718273)
 * This is a slightly different assumption than a pool that doesn't have LM enabled any more as incentivesController.rewardTokens() will have length=0
 */
contract GasTest is Test {
  ITransparentProxyFactory constant TRANSPARENT_PROXY_FACTORY =
    ITransparentProxyFactory(0xC354ce29aa85e864e55277eF47Fc6a92532Dd6Ca);

  address public proxyAdmin;
  StaticATokenFactory public factory;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16591074);

    proxyAdmin = TRANSPARENT_PROXY_FACTORY.createProxyAdmin(
      AaveGovernanceV2.SHORT_EXECUTOR
    );

    factory = DeployATokenFactory._deploy(
      TRANSPARENT_PROXY_FACTORY,
      proxyAdmin,
      AaveV3Ethereum.POOL
    );
  }

  function testDeploy() public {
    DeployATokenFactory._deploy(
      TRANSPARENT_PROXY_FACTORY,
      proxyAdmin,
      AaveV3Ethereum.POOL
    );
  }

  function testListAll() public {
    factory.batchCreateStaticATokens(AaveV3Ethereum.POOL.getReservesList());
  }

  function testListOne() public {
    factory.createStaticAToken(AaveV3Ethereum.POOL.getReservesList()[0]);
  }
}
