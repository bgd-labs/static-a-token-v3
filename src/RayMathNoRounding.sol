// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

library RayMathNoRounding {
  uint256 internal constant RAY = 1e27;
  uint256 internal constant WAD_RAY_RATIO = 1e9;

  function rayMulNoRounding(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
  {
    if (a == 0 || b == 0) {
      return 0;
    }
    return (a * b) / RAY;
  }

  function rayMulRoundUp(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    return ((a * b) + RAY - 1) / RAY;
  }

  function rayDivNoRounding(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
  {
    return (a * RAY) / b;
  }

  function rayDivRoundUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return ((a * RAY) + b - 1) / b;
  }

  function rayToWadNoRounding(uint256 a) internal pure returns (uint256) {
    return a / WAD_RAY_RATIO;
  }
}
