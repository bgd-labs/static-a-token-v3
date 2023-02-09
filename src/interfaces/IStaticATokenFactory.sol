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
}
