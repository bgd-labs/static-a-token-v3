// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool, DataTypes} from 'aave-address-book/AaveV3.sol';
import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {StaticATokenLM} from './StaticATokenLM.sol';

contract StaticATokenRegistry is Ownable {
  IPool immutable POOL;

  // changable by owner
  ITransparentProxyFactory private _transparentProxyFactory;
  address private _staticATokenImpl;

  //
  mapping(bytes32 => address) private _addresses;
  address[] private _staticATokens;

  constructor(
    IPool pool,
    ITransparentProxyFactory transparentProxyFactory,
    address staticATokenImpl,
    address admin
  ) {
    POOL = pool;

    _transparentProxyFactory = transparentProxyFactory;
    _staticATokenImpl = staticATokenImpl;
  }

  function createStaticAToken(address underlying) public returns (address) {
    DataTypes.ReserveData memory reserveData = POOL.getReserveData(underlying);
    bytes memory symbol = abi.encodePacked(
      'stat',
      IERC20Metadata(reserveData.aTokenAddress).symbol()
    );
    bytes32 salt = keccak256(symbol);
    require(_addresses[salt] == address(0), 'STATIC_TOKEN_ALREADY_EXISTS');
    address staticAToken = _transparentProxyFactory.createDeterministic(
      _staticATokenImpl,
      _owner,
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
      salt
    );
    _addresses[salt] = staticAToken;
    _staticATokens.push(staticAToken);
  }

  function getStaticATokens() external returns (address[] memory) {
    return _staticATokens;
  }

  function setTransparentProxyFactor(ITransparentProxyFactory newProxyFactory)
    public
    onlyOwner
  {
    _transparentProxyFactory = newProxyFactory;
  }

  function getTransparentProxyFactory()
    external
    view
    returns (ITransparentProxyFactory)
  {
    return _transparentProxyFactory;
  }

  function setStaticATokenImpl(address newStaticATokenImpl) public onlyOwner {
    _staticATokenImpl = newStaticATokenImpl;
  }

  function getStaticATokenImpl() external view returns (address) {
    return _staticATokenImpl;
  }
}
