// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool, DataTypes} from 'aave-address-book/AaveV3.sol';
import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {StaticATokenLM} from './StaticATokenLM.sol';
import {IStaticATokenFactory} from './interfaces/IStaticATokenFactory.sol';

/**
 * @title StaticATokenFactory
 * @notice Factory contract that keeps track of all deployed static token wrappers for a specified pool.
 * This registry also acts as a factory, allowing to deploy new static tokens on demand.
 * There can only be one static token per underlying on the registry at a time.
 * @author BGD labs
 */
contract StaticATokenFactory is Ownable, IStaticATokenFactory {
  IPool immutable POOL;

  ITransparentProxyFactory private _transparentProxyFactory;
  address private _staticATokenImpl;

  mapping(address => address) private _addresses;
  address[] private _staticATokens;

  constructor(
    IPool pool,
    ITransparentProxyFactory transparentProxyFactory,
    address staticATokenImpl
  ) {
    POOL = pool;

    _transparentProxyFactory = transparentProxyFactory;
    _staticATokenImpl = staticATokenImpl;
  }

  ///@inheritdoc IStaticATokenFactory
  function createStaticAToken(address underlying) public returns (address) {
    require(
      _addresses[underlying] == address(0),
      'STATIC_TOKEN_ALREADY_EXISTS'
    );
    DataTypes.ReserveData memory reserveData = POOL.getReserveData(underlying);
    bytes memory symbol = abi.encodePacked(
      'stat',
      IERC20Metadata(reserveData.aTokenAddress).symbol()
    );
    address staticAToken = _transparentProxyFactory.createDeterministic(
      _staticATokenImpl,
      owner(),
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
    _addresses[underlying] = staticAToken;
    _staticATokens.push(staticAToken);
    return staticAToken;
  }

  ///@inheritdoc IStaticATokenFactory
  function getStaticATokens() external returns (address[] memory) {
    return _staticATokens;
  }

  ///@inheritdoc IStaticATokenFactory
  function setTransparentProxyFactor(ITransparentProxyFactory newProxyFactory)
    public
    onlyOwner
  {
    _transparentProxyFactory = newProxyFactory;
  }

  ///@inheritdoc IStaticATokenFactory
  function getTransparentProxyFactory()
    external
    view
    returns (ITransparentProxyFactory)
  {
    return _transparentProxyFactory;
  }

  ///@inheritdoc IStaticATokenFactory
  function setStaticATokenImpl(address newStaticATokenImpl) public onlyOwner {
    _staticATokenImpl = newStaticATokenImpl;
  }

  ///@inheritdoc IStaticATokenFactory
  function getStaticATokenImpl() external view returns (address) {
    return _staticATokenImpl;
  }
}
