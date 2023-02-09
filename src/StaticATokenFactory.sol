// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool, DataTypes} from 'aave-address-book/AaveV3.sol';
import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {StaticATokenLM} from './StaticATokenLM.sol';
import {IStaticATokenFactory} from './interfaces/IStaticATokenFactory.sol';

/**
 * @title StaticATokenFactory
 * @notice Factory contract that keeps track of all deployed static aToken wrappers for a specified pool.
 * This registry also acts as a factory, allowing to deploy new static aTokens on demand.
 * There can only be one static aToken per underlying on the registry at a time.
 * @author BGD labs
 */
contract StaticATokenFactory is Initializable, IStaticATokenFactory {
  IPool public immutable POOL;
  address public immutable ADMIN;
  ITransparentProxyFactory public immutable TRANSPARENT_PROXY_FACTORY;
  address public immutable STATIC_A_TOKEN_IMPL;

  mapping(address => address) public underlyingToStaticAToken;
  address[] private _staticATokens;

  event StaticTokenCreated(address indexed staticAToken, address indexed underlying);

  constructor(
    IPool pool,
    address proxyAdmin,
    ITransparentProxyFactory transparentProxyFactory,
    address staticATokenImpl
  ) Initializable() {
    POOL = pool;
    ADMIN = proxyAdmin;
    TRANSPARENT_PROXY_FACTORY = transparentProxyFactory;
    STATIC_A_TOKEN_IMPL = staticATokenImpl;
  }

  function initialize() external initializer {}

  ///@inheritdoc IStaticATokenFactory
  function createStaticAToken(address underlying) public returns (address) {
    require(
      underlyingToStaticAToken[underlying] == address(0),
      'STATIC_TOKEN_ALREADY_EXISTS'
    );
    DataTypes.ReserveData memory reserveData = POOL.getReserveData(underlying);
    bytes memory symbol = abi.encodePacked(
      'stat',
      IERC20Metadata(reserveData.aTokenAddress).symbol()
    );
    address staticAToken = TRANSPARENT_PROXY_FACTORY.createDeterministic(
      STATIC_A_TOKEN_IMPL,
      ADMIN,
      abi.encodeWithSelector(
        StaticATokenLM.initialize.selector,
        POOL,
        reserveData.aTokenAddress,
        string(
          abi.encodePacked(
            'Static ',
            IERC20Metadata(reserveData.aTokenAddress).name()
          )
        ),
        string(symbol)
      ),
      bytes32(uint256(uint160(underlying)))
    );
    underlyingToStaticAToken[underlying] = staticAToken;
    _staticATokens.push(staticAToken);
    emit StaticTokenCreated(staticAToken, underlying);
    return staticAToken;
  }

  ///@inheritdoc IStaticATokenFactory
  function batchCreateStaticATokens(address[] memory underlyings)
    external
    returns (address[] memory)
  {
    address[] memory staticATokens = new address[](underlyings.length);
    for (uint256 i = 0; i < underlyings.length; i++) {
      staticATokens[i] = createStaticAToken(underlyings[i]);
    }
    return staticATokens;
  }

  ///@inheritdoc IStaticATokenFactory
  function getStaticATokens() external returns (address[] memory) {
    return _staticATokens;
  }
}
