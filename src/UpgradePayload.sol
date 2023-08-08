// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import {StaticATokenFactory} from './StaticATokenFactory.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from 'solidity-utils/contracts/transparent-proxy/ProxyAdmin.sol';

contract UpgradePayload {
  ProxyAdmin immutable ADMIN;
  address immutable FACTORY;
  address immutable NEW_TOKEN_IMPLEMENTATION;
  address immutable NEW_FACTORY_IMPLEMENTATION;

  constructor(
    address admin,
    address factory,
    address newFactoryImpl,
    address newTokenImplementation
  ) {
    ADMIN = ProxyAdmin(admin);
    FACTORY = factory;
    NEW_FACTORY_IMPLEMENTATION = newFactoryImpl;
    NEW_TOKEN_IMPLEMENTATION = newTokenImplementation;
  }

  function execute() external {
    address[] memory tokens = StaticATokenFactory(FACTORY).getStaticATokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      ADMIN.upgrade(TransparentUpgradeableProxy(payable(tokens[i])), NEW_TOKEN_IMPLEMENTATION);
    }
    ADMIN.upgrade(TransparentUpgradeableProxy(payable(FACTORY)), NEW_FACTORY_IMPLEMENTATION);
  }
}
