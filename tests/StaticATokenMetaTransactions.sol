// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, AaveV3AvalancheAssets, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenLM, IERC20, IERC20Metadata} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {SigUtils} from './SigUtils.sol';
import {BaseTest} from './TestBase.sol';

/**
 * Testing meta transactions with frax as WETH does not support permit
 */
contract StaticATokenMetaTransactions is BaseTest {
  address public constant override UNDERLYING = AaveV3AvalancheAssets.FRAX_UNDERLYING;
  address public constant override A_TOKEN = AaveV3AvalancheAssets.FRAX_A_TOKEN;

  IPool public override pool = IPool(AaveV3Avalanche.POOL);

  address[] rewardTokens;

  function REWARD_TOKEN() public returns (address) {
    return rewardTokens[0];
  }

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);
    rewardTokens.push(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    super.setUp();
  }

  function test_validateDomainSeparator() public {
    address[] memory staticATokens = factory.getStaticATokens();
    for (uint256 i = 0; i < staticATokens.length; i++) {
      bytes32 separator1 = StaticATokenLM(staticATokens[i]).DOMAIN_SEPARATOR();
      for (uint256 j = 0; j < staticATokens.length; j++) {
        if (i != j) {
          bytes32 separator2 = StaticATokenLM(staticATokens[j]).DOMAIN_SEPARATOR();
          assertNotEq(separator1, separator2, 'DOMAIN_SEPARATOR_MUST_BE_UNIQUE');
        }
      }
    }
  }

  function test_metaDepositATokenUnderlyingNoPermit() public {
    uint128 amountToDeposit = 5 ether;
    deal(UNDERLYING, user, amountToDeposit);
    IERC20(UNDERLYING).approve(address(staticATokenLM), 1 ether);
    IStaticATokenLM.PermitParams memory permitParams;

    // generate combined permit
    SigUtils.DepositPermit memory depositPermit = SigUtils.DepositPermit({
      owner: user,
      spender: spender,
      value: 1 ether,
      referralCode: 0,
      fromUnderlying: true,
      nonce: staticATokenLM.nonces(user),
      deadline: block.timestamp + 1 days,
      permit: permitParams
    });
    bytes32 digest = SigUtils.getTypedDepositHash(
      depositPermit,
      staticATokenLM.METADEPOSIT_TYPEHASH(),
      staticATokenLM.DOMAIN_SEPARATOR()
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM.SignatureParams(v, r, s);

    uint256 previewDeposit = staticATokenLM.previewDeposit(depositPermit.value);
    staticATokenLM.metaDeposit(
      depositPermit.owner,
      depositPermit.spender,
      depositPermit.value,
      depositPermit.referralCode,
      depositPermit.fromUnderlying,
      depositPermit.deadline,
      permitParams,
      sigParams
    );

    assertEq(staticATokenLM.balanceOf(depositPermit.spender), previewDeposit);
  }

  function test_metaDepositATokenUnderlying() public {
    uint128 amountToDeposit = 5 ether;
    deal(UNDERLYING, user, amountToDeposit);

    // permit for aToken deposit
    SigUtils.Permit memory permit = SigUtils.Permit({
      owner: user,
      spender: address(staticATokenLM),
      value: 1 ether,
      nonce: IERC20WithPermit(UNDERLYING).nonces(user),
      deadline: block.timestamp + 1 days
    });

    bytes32 permitDigest = SigUtils.getTypedDataHash(
      permit,
      staticATokenLM.PERMIT_TYPEHASH(),
      IERC20WithPermit(UNDERLYING).DOMAIN_SEPARATOR()
    );

    (uint8 pV, bytes32 pR, bytes32 pS) = vm.sign(userPrivateKey, permitDigest);

    IStaticATokenLM.PermitParams memory permitParams = IStaticATokenLM.PermitParams(
      permit.owner,
      permit.spender,
      permit.value,
      permit.deadline,
      pV,
      pR,
      pS
    );

    // generate combined permit
    SigUtils.DepositPermit memory depositPermit = SigUtils.DepositPermit({
      owner: user,
      spender: spender,
      value: permit.value,
      referralCode: 0,
      fromUnderlying: true,
      nonce: staticATokenLM.nonces(user),
      deadline: permit.deadline,
      permit: permitParams
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      userPrivateKey,
      SigUtils.getTypedDepositHash(
        depositPermit,
        staticATokenLM.METADEPOSIT_TYPEHASH(),
        staticATokenLM.DOMAIN_SEPARATOR()
      )
    );

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM.SignatureParams(v, r, s);

    uint256 previewDeposit = staticATokenLM.previewDeposit(depositPermit.value);
    uint256 shares = staticATokenLM.metaDeposit(
      depositPermit.owner,
      depositPermit.spender,
      depositPermit.value,
      depositPermit.referralCode,
      depositPermit.fromUnderlying,
      depositPermit.deadline,
      permitParams,
      sigParams
    );
    assertEq(shares, previewDeposit);
    assertEq(staticATokenLM.balanceOf(depositPermit.spender), previewDeposit);
  }

  function test_metaDepositAToken() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _underlyingToAToken(amountToDeposit, user);

    // permit for aToken deposit
    SigUtils.Permit memory permit = SigUtils.Permit({
      owner: user,
      spender: address(staticATokenLM),
      value: 1 ether,
      nonce: IERC20WithPermit(A_TOKEN).nonces(user),
      deadline: block.timestamp + 1 days
    });

    bytes32 permitDigest = SigUtils.getTypedDataHash(
      permit,
      staticATokenLM.PERMIT_TYPEHASH(),
      IERC20WithPermit(A_TOKEN).DOMAIN_SEPARATOR()
    );

    (uint8 pV, bytes32 pR, bytes32 pS) = vm.sign(userPrivateKey, permitDigest);

    IStaticATokenLM.PermitParams memory permitParams = IStaticATokenLM.PermitParams(
      permit.owner,
      permit.spender,
      permit.value,
      permit.deadline,
      pV,
      pR,
      pS
    );

    // generate combined permit
    SigUtils.DepositPermit memory depositPermit = SigUtils.DepositPermit({
      owner: user,
      spender: spender,
      value: permit.value,
      referralCode: 0,
      fromUnderlying: false,
      nonce: staticATokenLM.nonces(user),
      deadline: permit.deadline,
      permit: permitParams
    });
    bytes32 digest = SigUtils.getTypedDepositHash(
      depositPermit,
      staticATokenLM.METADEPOSIT_TYPEHASH(),
      staticATokenLM.DOMAIN_SEPARATOR()
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM.SignatureParams(v, r, s);

    uint256 previewDeposit = staticATokenLM.previewDeposit(depositPermit.value);
    staticATokenLM.metaDeposit(
      depositPermit.owner,
      depositPermit.spender,
      depositPermit.value,
      depositPermit.referralCode,
      depositPermit.fromUnderlying,
      depositPermit.deadline,
      permitParams,
      sigParams
    );

    assertEq(staticATokenLM.balanceOf(depositPermit.spender), previewDeposit);
  }

  function test_metaWithdraw() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    SigUtils.WithdrawPermit memory permit = SigUtils.WithdrawPermit({
      owner: user,
      spender: spender,
      staticAmount: 0,
      dynamicAmount: 1e18,
      toUnderlying: false,
      nonce: staticATokenLM.nonces(user),
      deadline: block.timestamp + 1 days
    });
    bytes32 digest = SigUtils.getTypedWithdrawHash(
      permit,
      staticATokenLM.METAWITHDRAWAL_TYPEHASH(),
      staticATokenLM.DOMAIN_SEPARATOR()
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM.SignatureParams(v, r, s);

    staticATokenLM.metaWithdraw(
      permit.owner,
      permit.spender,
      permit.staticAmount,
      permit.dynamicAmount,
      permit.toUnderlying,
      permit.deadline,
      sigParams
    );

    assertEq(IERC20(A_TOKEN).balanceOf(permit.spender), permit.dynamicAmount);
  }
}
