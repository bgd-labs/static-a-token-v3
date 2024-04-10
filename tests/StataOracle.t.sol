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
    assertApproxEqAbs(
      stataPrice,
      underlyingPrice,
      ((underlyingPrice * AaveV3Avalanche.POOL.getReserveNormalizedIncome(UNDERLYING)) / 1e27) -
        underlyingPrice
    );
  }

  function test_deposit() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _depositAToken(amountToDeposit, user);

    uint256 stataPrice = oracle.getAssetPrice(address(staticATokenLM));
    uint256 underlyingPrice = AaveV3Avalanche.ORACLE.getAssetPrice(UNDERLYING);

    assertApproxEqAbs(
      (stataPrice * staticATokenLM.balanceOf(user)) / 1e18,
      (underlyingPrice * amountToDeposit) / 1e18,
      10
    );
  }
}
