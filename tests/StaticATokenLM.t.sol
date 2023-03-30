// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool} from 'aave-address-book/AaveV3Avalanche.sol';
import {DataTypes, ReserveConfiguration} from 'aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {RayMathExplicitRounding, Rounding} from '../src/RayMathExplicitRounding.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {SigUtils} from './SigUtils.sol';
import {BaseTest} from './TestBase.sol';

contract StaticATokenLMTest is BaseTest {
  using RayMathExplicitRounding for uint256;

  address public constant override UNDERLYING = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  address public constant override A_TOKEN = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
  address public constant EMISSION_ADMIN = 0xCba0B614f13eCdd98B8C0026fcAD11cec8Eb4343;

  IPool public override pool = IPool(AaveV3Avalanche.POOL);

  address[] rewardTokens;

  function REWARD_TOKEN() public returns (address) {
    return rewardTokens[0];
  }

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);
    rewardTokens.push(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    super.setUp();
  }

  function test_getters() public {
    assertEq(staticATokenLM.name(), 'Static Aave Avalanche WETH');
    assertEq(staticATokenLM.symbol(), 'stataAvaWETH');

    IERC20 aToken = staticATokenLM.aToken();
    assertEq(address(aToken), A_TOKEN);

    address aTokenAddress = staticATokenLM.asset();
    assertEq(aTokenAddress, A_TOKEN);

    address underlyingAddress = address(staticATokenLM.aTokenUnderlying());
    assertEq(underlyingAddress, UNDERLYING);

    IERC20Metadata underlying = IERC20Metadata(underlyingAddress);
    assertEq(staticATokenLM.decimals(), underlying.decimals());

    assertEq(
      address(staticATokenLM.INCENTIVES_CONTROLLER()),
      address(AToken(A_TOKEN).getIncentivesController())
    );
  }

  function test_convertersAndPreviews() public {
    uint128 amount = 5 ether;
    uint256 shares = staticATokenLM.convertToShares(amount);
    assertLe(shares, amount, 'SHARES LOWER');
    assertEq(shares, staticATokenLM.previewDeposit(amount), 'PREVIEW_DEPOSIT');
    assertLe(shares, staticATokenLM.previewWithdraw(amount), 'PREVIEW_WITHDRAW');
    uint256 assets = staticATokenLM.convertToAssets(amount);
    assertGe(assets, shares, 'ASSETS GREATER');
    assertLe(assets, staticATokenLM.previewMint(amount), 'PREVIEW_MINT');
    assertEq(assets, staticATokenLM.previewRedeem(amount), 'PREVIEW_REDEEM');
  }

  // Redeem tests
  function test_redeem() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(A_TOKEN).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(A_TOKEN).balanceOf(user), amountToDeposit, 1);
  }

  function test_redeemUnderlying() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user, true);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(UNDERLYING).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(UNDERLYING).balanceOf(user), amountToDeposit, 1);
  }

  function test_redeemAllowance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    staticATokenLM.approve(user1, staticATokenLM.maxRedeem(user));
    vm.stopPrank();
    vm.startPrank(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user1, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(A_TOKEN).balanceOf(user1), amountToDeposit);
    assertApproxEqAbs(IERC20(A_TOKEN).balanceOf(user1), amountToDeposit, 1);
  }

  function testFail_redeemOverflowAllowance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    staticATokenLM.approve(user1, staticATokenLM.maxRedeem(user) / 2);
    vm.stopPrank();
    vm.startPrank(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user1, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(A_TOKEN).balanceOf(user1), amountToDeposit);
  }

  function testFail_redeemAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user) + 1, user, user);
  }

  // Withdraw tests
  function test_withdraw() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    assertLe(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertLe(IERC20(A_TOKEN).balanceOf(user), amountToDeposit);
    assertApproxEqAbs(IERC20(A_TOKEN).balanceOf(user), amountToDeposit, 1);
  }

  function testFail_withdrawAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _fundUser(amountToDeposit, user1);

    _depositAToken(amountToDeposit, user);
    _depositAToken(amountToDeposit, user1);

    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user) + 1, user, user);
  }

  // mint
  function test_mint() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _underlyingToAToken(amountToDeposit, user);
    IERC20(A_TOKEN).approve(address(staticATokenLM), amountToDeposit);
    uint256 shares = 1 ether;
    staticATokenLM.mint(shares, user);
    assertEq(shares, staticATokenLM.balanceOf(user));
  }

  function testFail_mintAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _underlyingToAToken(amountToDeposit, user);
    IERC20(A_TOKEN).approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.mint(amountToDeposit, user);
  }

  // test rewards
  function test_collectAndUpdateRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
    uint256 claimable = staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN());
    staticATokenLM.collectAndUpdateRewards(REWARD_TOKEN());
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), claimable);
  }

  function test_claimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
  }

  function test_claimRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    staticATokenLM.claimRewards(user, rewardTokens);
    assertEq(claimable, IERC20(REWARD_TOKEN()).balanceOf(user));
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
  }

  // should fail as user1 is not a valid claimer
  function testFail_claimRewardsOnBehalfOf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    vm.stopPrank();
    vm.startPrank(user1);

    uint256 claimable = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    staticATokenLM.claimRewardsOnBehalf(user, user1, rewardTokens);
  }

  function test_depositATokenClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    // deposit aweth
    _depositAToken(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), 0);
    assertGt(AToken(A_TOKEN).balanceOf(user), 5 ether);
  }

  function test_depositWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), 0);
    assertGt(AToken(A_TOKEN).balanceOf(user), 5 ether);
  }

  function test_transfer() public {
    uint128 amountToDeposit = 10 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    // transfer to 2nd user
    staticATokenLM.transfer(user1, amountToDeposit / 2);
    assertEq(staticATokenLM.getClaimableRewards(user1, REWARD_TOKEN()), 0);

    // forward time
    _skipBlocks(60);

    // redeem for both
    uint256 claimableUser = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN());
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user), claimableUser);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 claimableUser1 = staticATokenLM.getClaimableRewards(user1, REWARD_TOKEN());
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user1), user1, user1);
    staticATokenLM.claimRewardsToSelf(rewardTokens);
    assertEq(IERC20(REWARD_TOKEN()).balanceOf(user1), claimableUser1);
    assertGt(claimableUser1, 0);

    assertEq(staticATokenLM.getTotalClaimableRewards(REWARD_TOKEN()), 0);
    assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
    assertEq(staticATokenLM.getClaimableRewards(user1, REWARD_TOKEN()), 0);
  }

  // getUnclaimedRewards
  function test_getUnclaimedRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    uint256 shares = _depositAToken(amountToDeposit, user);
    assertEq(staticATokenLM.getUnclaimedRewards(user, REWARD_TOKEN()), 0);
    _skipBlocks(1000);
    staticATokenLM.redeem(shares, user, user);
    assertGt(staticATokenLM.getUnclaimedRewards(user, REWARD_TOKEN()), 0);
  }

  /**
   * maxDepositUnderlying test
   */
  function test_maxDepositUnderlying_freeze() public {
    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setReserveFreeze(UNDERLYING, true);

    uint256 max = staticATokenLM.maxDepositUnderlying(address(0));

    assertEq(max, 0);
  }

  function test_maxDepositUnderlying_paused() public {
    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setReservePause(UNDERLYING, true);

    uint256 max = staticATokenLM.maxDepositUnderlying(address(0));

    assertEq(max, 0);
  }

  function test_maxDepositUnderlying_noCap() public {
    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setSupplyCap(UNDERLYING, 0);

    uint256 max = staticATokenLM.maxDepositUnderlying(address(0));

    assertEq(max, type(uint256).max);
  }

  // should be 0 as supply is ~24.7k in forked block
  function test_maxDepositUnderlying_20kCap() public {
    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setSupplyCap(UNDERLYING, 20_000);

    uint256 max = staticATokenLM.maxDepositUnderlying(address(0));
    assertEq(max, 0);
  }

  function test_maxDepositUnderlying_50kCap() public {
    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setSupplyCap(UNDERLYING, 50_000);

    uint256 max = staticATokenLM.maxDepositUnderlying(address(0));
    DataTypes.ReserveData memory reserveData = this.pool().getReserveData(UNDERLYING);
    assertEq(
      max,
      50_000 *
        (10 ** IERC20Metadata(UNDERLYING).decimals()) -
        (IERC20Metadata(A_TOKEN).totalSupply() +
          uint256(reserveData.accruedToTreasury).rayMulRoundUp(staticATokenLM.rate()))
    );
  }

  /**
   * maxRedeemUnderlying test
   */
  function test_maxRedeemUnderlying_paused() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    vm.stopPrank();
    vm.startPrank(address(AaveV3Avalanche.ACL_ADMIN));
    AaveV3Avalanche.POOL_CONFIGURATOR.setReservePause(UNDERLYING, true);

    uint256 max = staticATokenLM.maxRedeemUnderlying(address(user));

    assertEq(max, 0);
  }

  function test_maxRedeemUnderlying_allAvailable() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    uint256 max = staticATokenLM.maxRedeemUnderlying(address(user));

    assertEq(max, staticATokenLM.balanceOf(user));
  }

  function test_maxRedeemUnderlying_partAvailable() public {
    uint128 amountToDeposit = 50 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);
    vm.stopPrank();

    uint256 maxRedeemBefore = staticATokenLM.previewRedeem(
      staticATokenLM.maxRedeemUnderlying(address(user))
    );
    uint256 underlyingBalanceBefore = IERC20Metadata(UNDERLYING).balanceOf(A_TOKEN);
    // create rich user
    address borrowUser = 0xAD69de0CE8aB50B729d3f798d7bC9ac7b4e79267;
    address usdc = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    vm.startPrank(borrowUser);
    deal(usdc, borrowUser, 200_000_000_000000);
    AaveV3Avalanche.POOL.deposit(usdc, 200_000_000_000000, borrowUser, 0);

    // borrow all available
    AaveV3Avalanche.POOL.borrow(
      UNDERLYING,
      underlyingBalanceBefore - (maxRedeemBefore / 2),
      2,
      0,
      borrowUser
    );

    uint256 maxRedeemAfter = staticATokenLM.previewRedeem(
      staticATokenLM.maxRedeemUnderlying(address(user))
    );
    assertApproxEqAbs(maxRedeemAfter, (maxRedeemBefore / 2), 1);
  }

  function test_maxRedeemUnderlying_nonAvailable() public {
    uint128 amountToDeposit = 50 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);
    vm.stopPrank();

    uint256 underlyingBalanceBefore = IERC20Metadata(UNDERLYING).balanceOf(A_TOKEN);
    // create rich user
    address borrowUser = 0xAD69de0CE8aB50B729d3f798d7bC9ac7b4e79267;
    address usdc = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    vm.startPrank(borrowUser);
    deal(usdc, borrowUser, 200_000_000_000000);
    AaveV3Avalanche.POOL.deposit(usdc, 200_000_000_000000, borrowUser, 0);

    // borrow all available
    AaveV3Avalanche.POOL.borrow(UNDERLYING, underlyingBalanceBefore, 2, 0, borrowUser);

    uint256 maxRedeemAfter = staticATokenLM.maxRedeemUnderlying(address(user));
    assertEq(maxRedeemAfter, 0);
  }

  /**
   * This test is a bit artificial and tests, what would happen if for some reason `_claimRewards` would no longer revert on insufficient funds.
   * Therefore we reduce the claimable amount for the staticAtoken itself.
   */
  // function test_claimMoreThanAvailable() public {
  //   uint128 amountToDeposit = 5 ether;
  //   _fundUser(amountToDeposit, user);

  //   _depositAToken(amountToDeposit, user);

  //   _skipBlocks(60);

  //   uint256 claimable = staticATokenLM.getClaimableRewards(
  //     user,
  //     REWARD_TOKEN()
  //   );

  //   // transfer out funds
  //   vm.stopPrank();
  //   uint256 emissionAdminBalance = IERC20(REWARD_TOKEN()).balanceOf(
  //     EMISSION_ADMIN
  //   );
  //   uint256 transferOut = emissionAdminBalance - (claimable / 2);
  //   vm.startPrank(EMISSION_ADMIN);
  //   IERC20(REWARD_TOKEN()).approve(address(1234), transferOut);
  //   IERC20(REWARD_TOKEN()).transfer(address(1234), transferOut);
  //   vm.stopPrank();
  //   vm.startPrank(user);
  //   // claim
  //   staticATokenLM.claimRewards(user, rewardTokens);
  //   // assertEq(claimable, IERC20(REWARD_TOKEN()).balanceOf(user));
  //   // assertEq(IERC20(REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
  //   // assertEq(staticATokenLM.getClaimableRewards(user, REWARD_TOKEN()), 0);
  // }
}
