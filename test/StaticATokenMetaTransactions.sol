// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {SigUtils} from './SigUtils.sol';
import {BaseTest} from './TestBase.sol';

/**
 * Testing meta transactions with frax as WETH does not support permit
 */
contract StaticATokenMetaTransactions is BaseTest {
  address public constant override REWARD_TOKEN =
    0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
  address public constant override WETH =
    0xD24C2Ad096400B6FBcd2ad8B24E7acBc21A1da64;
  address public constant override aWETH =
    0xc45A479877e1e9Dfe9FcD4056c699575a1045dAA;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 20389332);
    super.setUp();
  }

  function test_metaDepositATokenUnderlying() public {
    uint128 amountToDeposit = 5 ether;
    deal(WETH, user, amountToDeposit);

    // permit for aToken deposit
    SigUtils.Permit memory permit = SigUtils.Permit({
      owner: user,
      spender: address(staticATokenLM),
      value: 1 ether,
      nonce: ERC20(WETH).nonces(user),
      deadline: block.timestamp + 1 days
    });

    bytes32 permitDigest = SigUtils.getTypedDataHash(
      permit,
      ERC20(WETH).DOMAIN_SEPARATOR()
    );

    (uint8 pV, bytes32 pR, bytes32 pS) = vm.sign(userPrivateKey, permitDigest);

    IStaticATokenLM.PermitParams memory permitParams = IStaticATokenLM
      .PermitParams(
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
    bytes32 digest = SigUtils.getTypedDepositHash(
      depositPermit,
      staticATokenLM.METADEPOSIT_TYPEHASH(),
      staticATokenLM.DOMAIN_SEPARATOR()
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM
      .SignatureParams(v, r, s);

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

  function test_metaDepositAToken() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _wethToAWeth(amountToDeposit, user);

    // permit for aToken deposit
    SigUtils.Permit memory permit = SigUtils.Permit({
      owner: user,
      spender: address(staticATokenLM),
      value: 1 ether,
      nonce: ERC20(this.aWETH()).nonces(user),
      deadline: block.timestamp + 1 days
    });

    bytes32 permitDigest = SigUtils.getTypedDataHash(
      permit,
      ERC20(this.aWETH()).DOMAIN_SEPARATOR()
    );

    (uint8 pV, bytes32 pR, bytes32 pS) = vm.sign(userPrivateKey, permitDigest);

    IStaticATokenLM.PermitParams memory permitParams = IStaticATokenLM
      .PermitParams(
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

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM
      .SignatureParams(v, r, s);

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

    _depositAWeth(amountToDeposit, user);

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

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM
      .SignatureParams(v, r, s);

    staticATokenLM.metaWithdraw(
      permit.owner,
      permit.spender,
      permit.staticAmount,
      permit.dynamicAmount,
      permit.toUnderlying,
      permit.deadline,
      sigParams
    );

    assertEq(
      IERC20(this.aWETH()).balanceOf(permit.spender),
      permit.dynamicAmount
    );
  }
}
