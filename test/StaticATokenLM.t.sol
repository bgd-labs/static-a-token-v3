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

contract StaticATokenLMTest is BaseTest {
  address public constant override REWARD_TOKEN =
    0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  address public constant override UNDERLYING =
    0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
  address public constant override A_TOKEN =
    0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;

  IPool public override pool = IPool(AaveV3Avalanche.POOL);

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 25016463);
    super.setUp();
  }

  function test_getters() public {
    assertEq(staticATokenLM.name(), 'Static Aave WETH');
    assertEq(staticATokenLM.symbol(), 'stataWETH');

    IERC20 aToken = staticATokenLM.aToken();
    assertEq(address(aToken), A_TOKEN);

    address aTokenAddress = staticATokenLM.asset();
    assertEq(aTokenAddress, A_TOKEN);

    address underlyingAddress = address(staticATokenLM.aTokenUnderlying());
    assertEq(underlyingAddress, UNDERLYING);

    IERC20Metadata underlying = IERC20Metadata(underlyingAddress);
    assertEq(staticATokenLM.decimals(), underlying.decimals());

    assertEq(
      address(staticATokenLM.incentivesController()),
      address(AToken(A_TOKEN).getIncentivesController())
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
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(address(staticATokenLM)), 0);
    uint256 claimable = staticATokenLM.getTotalClaimableRewards();
    staticATokenLM.collectAndUpdateRewards();
    assertEq(
      IERC20(this.REWARD_TOKEN()).balanceOf(address(staticATokenLM)),
      claimable
    );
  }

  function test_claimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function test_claimRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewards(user1);
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  // should fail as user1 is not a valid claimer
  function testFail_claimRewardsOnBehalfOf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);

    vm.stopPrank();
    vm.startPrank(user1);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsOnBehalf(user, user1);
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function test_depositATokenClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    // deposit aweth
    _depositAToken(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(
      IERC20(this.REWARD_TOKEN()).balanceOf(user),
      claimable1 + claimable0
    );
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(A_TOKEN).balanceOf(user), 5 ether);
  }

  function test_depositWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(
      IERC20(this.REWARD_TOKEN()).balanceOf(user),
      claimable1 + claimable0
    );
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(A_TOKEN).balanceOf(user), 5 ether);
  }

  function test_transfer() public {
    uint128 amountToDeposit = 10 ether;
    _fundUser(amountToDeposit, user);

    _depositAToken(amountToDeposit, user);

    // transfer to 2nd user
    staticATokenLM.transfer(user1, amountToDeposit / 2);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);

    // forward time
    _skipBlocks(60);

    // redeem for both
    uint256 claimableUser = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user), claimableUser);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 claimableUser1 = staticATokenLM.getClaimableRewards(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user1), user1, user1);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(this.REWARD_TOKEN()).balanceOf(user1), claimableUser1);
    assertGt(claimableUser1, 0);

    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);
  }

  // getUnclaimedRewards
  function test_getUnclaimedRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    uint256 shares = _depositAToken(amountToDeposit, user);
    assertEq(staticATokenLM.getUnclaimedRewards(user), 0);
    _skipBlocks(1000);
    staticATokenLM.redeem(shares, user, user);
    assertGt(staticATokenLM.getUnclaimedRewards(user), 0);
  }
}
