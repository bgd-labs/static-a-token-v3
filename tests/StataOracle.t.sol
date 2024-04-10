// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AaveV3Avalanche, IPool, AaveV3AvalancheAssets} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {StataOracle} from '../src/StataOracle.sol';
import {RayMathExplicitRounding, Rounding} from '../src/RayMathExplicitRounding.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {BaseTest} from './TestBase.sol';

contract StataOracleTest is BaseTest {
  using RayMathExplicitRounding for uint256;

  address public constant override UNDERLYING = AaveV3AvalancheAssets.DAIe_UNDERLYING;
  address public constant override A_TOKEN = AaveV3AvalancheAssets.DAIe_A_TOKEN;
  address public constant EMISSION_ADMIN = 0xCba0B614f13eCdd98B8C0026fcAD11cec8Eb4343;

  IPool public override pool = IPool(AaveV3Avalanche.POOL);
  StataOracle public oracle;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 38011791);
    super.setUp();
    oracle = new StataOracle(AaveV3Avalanche.POOL_ADDRESSES_PROVIDER);
  }

  function test_oraclePrice() public {
    uint256 stataPrice = oracle.getAssetPrice(address(staticATokenLM));
    uint256 underlyingPrice = AaveV3Avalanche.ORACLE.getAssetPrice(UNDERLYING);
    assertGt(stataPrice, underlyingPrice);
    assertEq(stataPrice, (underlyingPrice * staticATokenLM.convertToAssets(1e18)) / 1e18);
  }

  function test_error(uint256 shares) public {
    vm.assume(shares <= staticATokenLM.maxMint(address(0)));
    uint256 pricePerShare = oracle.getAssetPrice(address(staticATokenLM));
    uint256 pricePerAsset = AaveV3Avalanche.ORACLE.getAssetPrice(UNDERLYING);
    uint256 assets = staticATokenLM.convertToAssets(shares);

    assertApproxEqAbs(
      (pricePerShare * shares) / 1e18,
      (pricePerAsset * assets) / 1e18,
      (assets / 1e18) + 1 // there can be imprecision of 1 wei, which will accumulate for each asset
    );
  }
}
