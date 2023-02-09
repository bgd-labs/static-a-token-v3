// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool, DataTypes} from 'aave-address-book/AaveV3.sol';
import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

interface IStaticATokenFactory {
  /**
   * @notice Creates a new staticAToken.
   * @return address staticAToken
   */
  function createStaticAToken(address underlying) external returns (address);

  /**
   * @notice Creates multiple new staticATokens.
   * @return address staticAToken
   */
  function batchCreateStaticATokens(address[] memory underlyings)
    external
    returns (address[] memory);

  /**
   * @notice Returns all tokens deployed via this registry.
   * @return address[] list of tokens
   */
  function getStaticATokens() external returns (address[] memory);

  /**
   * @notice Sets the transparentProxyFactory to be used for new token deployments.
   * @param newProxyFactory address of the new factory
   */
  function setTransparentProxyFactor(ITransparentProxyFactory newProxyFactory)
    external;

  /**
   * @notice Returns the transparentProxyFactory to be used for new token deployments.
   * The transparentProxyFactory is mutable and can be updated by the owner (an aave governance controlled executor).
   * @return ITransparentProxyFactory transparentProxyFactory
   */
  function getTransparentProxyFactory()
    external
    view
    returns (ITransparentProxyFactory);

  /**
   * @notice Sets the staticATokenImplementation to be used for new token deployments.
   * @param newStaticATokenImpl address of the new implementation
   */
  function setStaticATokenImpl(address newStaticATokenImpl) external;

  /**
   * @notice Returns the staticATokenImplementation used for new tokens.
   * The implementation is mutable and can be updated by the owner (an aave governance controlled executor).
   * @return address staticATokenImplementation
   */
  function getStaticATokenImpl() external view returns (address);
}
