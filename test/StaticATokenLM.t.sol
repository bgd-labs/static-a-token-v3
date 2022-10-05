// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {StaticATokenLM, IERC20, IERC20Metadata} from '../src/StaticATokenLM.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {SigUtils} from './SigUtils.sol';

contract StaticATokenLMTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address internal spender;

  uint256 internal userPrivateKey;
  uint256 internal spenderPrivateKey;

  address constant REWARD_TOKEN = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  address constant WETH = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  address constant aWETH = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  IPool pool = IPool(AaveV3Avalanche.POOL);
  StaticATokenLM staticATokenLM;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 20389332);

    userPrivateKey = 0xA11CE;
    spenderPrivateKey = 0xB0B0;

    user = address(vm.addr(userPrivateKey));
    user1 = address(vm.addr(2));
    spender = vm.addr(spenderPrivateKey);

    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    StaticATokenLM staticATokenLMImpl = new StaticATokenLM();
    hoax(OWNER);
    staticATokenLM = StaticATokenLM(
      proxyFactory.create(
        address(staticATokenLMImpl),
        ADMIN,
        abi.encodeWithSelector(
          StaticATokenLM.initialize.selector,
          pool,
          aWETH,
          'Static Aave WETH',
          'stataWETH'
        )
      )
    );
    vm.startPrank(user);
  }

  function _fundUser(uint128 amountToDeposit, address user) private {
    deal(WETH, user, amountToDeposit);
  }

  function _skipBlocks(uint128 blocks) private {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _wethToAWeth(uint256 amountToDeposit, address user) private {
    IERC20(WETH).approve(address(pool), amountToDeposit);
    pool.deposit(WETH, amountToDeposit, user, 0);
  }

  function _depositAWeth(uint256 amountToDeposit, address user)
    private
    returns (uint256)
  {
    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    return staticATokenLM.deposit(amountToDeposit, user);
  }

  function test_getters() public {
    assertEq(staticATokenLM.name(), 'Static Aave WETH');
    assertEq(staticATokenLM.symbol(), 'stataWETH');

    IERC20 aToken = staticATokenLM.aToken();
    assertEq(address(aToken), aWETH);

    address aTokenAddress = staticATokenLM.asset();
    assertEq(aTokenAddress, aWETH);

    address underlyingAddress = address(staticATokenLM.aTokenUnderlying());
    assertEq(underlyingAddress, WETH);

    IERC20Metadata underlying = IERC20Metadata(underlyingAddress);
    assertEq(staticATokenLM.decimals(), underlying.decimals());

    assertEq(
      address(staticATokenLM.incentivesController()),
      address(AToken(aWETH).getIncentivesController())
    );
  }

  function test_convertersAndPreviews() public {
    uint128 amount = 5 ether;
    uint256 shares = staticATokenLM.convertToShares(amount);
    assertLe(shares, amount, 'SHARES LOWER');
    assertEq(shares, staticATokenLM.previewDeposit(amount), 'PREVIEW_DEPOSIT');
    assertLe(
      shares,
      staticATokenLM.previewWithdraw(amount),
      'PREVIEW_WITHDRAW'
    );
    uint256 assets = staticATokenLM.convertToAssets(amount);
    assertGe(assets, shares, 'ASSETS GREATER');
    assertLe(assets, staticATokenLM.previewMint(amount), 'PREVIEW_MINT');
    assertEq(assets, staticATokenLM.previewRedeem(amount), 'PREVIEW_REDEEM');
  }

  // Redeem tests
  function test_redeem() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(aWETH).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(aWETH).balanceOf(user), amountToDeposit, 1);
  }

  function test_redeemUnderlying() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user, true);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(WETH).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(WETH).balanceOf(user), amountToDeposit, 1);
  }

  function test_redeemAllowance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    staticATokenLM.approve(user1, staticATokenLM.maxRedeem(user));
    vm.stopPrank();
    vm.startPrank(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user1, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(aWETH).balanceOf(user1), amountToDeposit);
    assertApproxEqAbs(IERC20(aWETH).balanceOf(user1), amountToDeposit, 1);
  }

  function testFail_redeemOverflowAllowance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    staticATokenLM.approve(user1, staticATokenLM.maxRedeem(user) / 2);
    vm.stopPrank();
    vm.startPrank(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user1, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(aWETH).balanceOf(user1), amountToDeposit);
  }

  function testFail_redeemAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user) + 1, user, user);
  }

  // Withdraw tests
  function test_withdraw() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertLe(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(aWETH).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(aWETH).balanceOf(user), amountToDeposit, 1);
  }

  function test_metaDeposit() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);

    SigUtils.DepositPermit memory permit = SigUtils.DepositPermit({
      owner: user,
      spender: spender,
      value: 1 ether,
      referralCode: 0,
      fromUnderlying: false,
      nonce: staticATokenLM.nonces(user),
      deadline: block.timestamp + 1 days
    });
    bytes32 digest = SigUtils.getTypedDepositHash(
      permit,
      staticATokenLM.METADEPOSIT_TYPEHASH(),
      staticATokenLM.DOMAIN_SEPARATOR()
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

    IStaticATokenLM.SignatureParams memory sigParams = IStaticATokenLM
      .SignatureParams(v, r, s);

    uint256 previewDeposit = staticATokenLM.previewDeposit(permit.value);
    staticATokenLM.metaDeposit(
      permit.owner,
      permit.spender,
      permit.value,
      permit.referralCode,
      permit.fromUnderlying,
      permit.deadline,
      sigParams
    );

    assertEq(staticATokenLM.balanceOf(permit.spender), previewDeposit);
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

    assertEq(IERC20(aWETH).balanceOf(permit.spender), permit.dynamicAmount);
  }

  function testFail_withdrawAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _fundUser(amountToDeposit, user1);

    _depositAWeth(amountToDeposit, user);
    _depositAWeth(amountToDeposit, user1);

    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user) + 1, user, user);
  }

  // mint
  function test_mint() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    uint256 shares = 1 ether;
    uint256 assets = staticATokenLM.mint(shares, user);
    assertEq(shares, staticATokenLM.balanceOf(user));
  }

  function testFail_mintAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    uint256 assets = staticATokenLM.mint(amountToDeposit, user);
  }

  // test rewards
  function test_collectAndUpdateRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    _skipBlocks(60);
    assertEq(IERC20(REWARD_TOKEN).balanceOf(address(staticATokenLM)), 0);
    uint256 claimable = staticATokenLM.getTotalClaimableRewards();
    staticATokenLM.collectAndUpdateRewards();
    assertEq(
      IERC20(REWARD_TOKEN).balanceOf(address(staticATokenLM)),
      claimable
    );
  }

  function test_claimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function test_claimRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewards(user1);
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  // should fail as user1 is not a valid claimer
  function testFail_claimRewardsOnBehalfOf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);

    vm.stopPrank();
    vm.startPrank(user1);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsOnBehalf(user, user1);
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function test_depositAWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    // deposit aweth
    _depositAWeth(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(aWETH).balanceOf(user), 5 ether);
  }

  function test_depositWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(aWETH).balanceOf(user), 5 ether);
  }

  function test_transfer() public {
    uint128 amountToDeposit = 10 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    // transfer to 2nd user
    staticATokenLM.transfer(user1, amountToDeposit / 2);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);

    // forward time
    _skipBlocks(60);

    // redeem for both
    uint256 claimableUser = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user), claimableUser);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 claimableUser1 = staticATokenLM.getClaimableRewards(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user1), user1, user1);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(REWARD_TOKEN).balanceOf(user1), claimableUser1);
    assertGt(claimableUser1, 0);

    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);
  }

  // getUnclaimedRewards
  function test_getUnclaimedRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    uint256 shares = _depositAWeth(amountToDeposit, user);
    assertEq(staticATokenLM.getUnclaimedRewards(user), 0);
    _skipBlocks(1000);
    staticATokenLM.redeem(shares, user, user);
    assertGt(staticATokenLM.getUnclaimedRewards(user), 0);
  }
}
