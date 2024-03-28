// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

interface IStataOracle {
  /**
   * @notice Returns the prices of an asset address
   * @param asset The asset address
   * @return The prices of the given asset
   */
  function getAssetPrice(address asset) external view returns (uint256);

  /**
   * @notice Returns a list of prices from a list of assets addresses
   * @param assets The list of assets addresses
   * @return The prices of the given assets
   */
  function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);
}
