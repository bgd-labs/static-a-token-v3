// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import '../src/StaticATokenLM.sol';
import {WETH9} from 'aave-v3-core/contracts/dependencies/weth/WETH9.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

contract StaticATokenLMTest is Test {
  address constant OWNER = address(1234);
  address constant ADMIN = address(2345);

  address public user;
  address public user1;
  address constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
  address constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  address payable constant WETH =
    payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address constant aWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
  IPool pool = IPool(LENDING_POOL);
  StaticATokenLM staticATokenLM;
  WETH9 weth;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 14590438);
    user = address(vm.addr(1));
    user1 = address(vm.addr(2));
    weth = WETH9(WETH);
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
    vm.deal(user, 100 ether);
    weth.deposit{value: amountToDeposit}();
  }

  function _skipBlocks(uint128 blocks) private {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _wethToAWeth(uint256 amountToDeposit, address user) private {
    weth.approve(address(pool), amountToDeposit);
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

  function testGetters() public {
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

  function testConvertersAndPreviews() public {
    uint128 amount = 5 ether;
    uint256 shares = staticATokenLM.convertToShares(amount);
    assertLt(shares, amount, 'SHARES LOWER');
    assertLt(shares, staticATokenLM.previewDeposit(amount), 'PREVIEW_DEPOSIT');
    assertLt(
      shares,
      staticATokenLM.previewWithdraw(amount),
      'PREVIEW_WITHDRAW'
    );
    uint256 assets = staticATokenLM.convertToAssets(shares);
    assertGt(assets, shares, 'ASSETS GREATER');
    assertEq(assets, staticATokenLM.previewMint(shares), 'PREVIEW_MINT');
    assertEq(assets, staticATokenLM.previewRedeem(shares), 'PREVIEW_REDEEM');
  }

  // Redeem tests
  function testRedeem() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(aWETH).balanceOf(user), amountToDeposit);
  }

  function testRedeemUnderlying() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertEq(staticATokenLM.maxRedeem(user), staticATokenLM.balanceOf(user));
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user, true);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(WETH).balanceOf(user), amountToDeposit);
  }

  function testRedeemAllowance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    staticATokenLM.approve(user1, staticATokenLM.maxRedeem(user));
    vm.stopPrank();
    vm.startPrank(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user1, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(aWETH).balanceOf(user1), amountToDeposit);
  }

  function testFailRedeemOverflowAllowance() public {
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

  function testFailRedeemAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user) + 1, user, user);
  }

  // Withdraw tests
  function testWithdraw() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _depositAWeth(amountToDeposit, user);

    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user), user, user);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(IERC20(aWETH).balanceOf(user), amountToDeposit);
  }

  // function testMetaWithdraw() public {
  //   staticATokenLM.metaWithdraw(user, user, 100, 0, false, deadline, sigParams);
  // }

  function testFailWithdrawAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);
    _fundUser(amountToDeposit, user1);

    _depositAWeth(amountToDeposit, user);
    _depositAWeth(amountToDeposit, user1);

    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    staticATokenLM.withdraw(staticATokenLM.maxWithdraw(user) + 1, user, user);
  }

  // mint
  function testMint() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    uint256 shares = 1 ether;
    uint256 assets = staticATokenLM.mint(shares, user);
    assertEq(shares, staticATokenLM.balanceOf(user));
  }

  function testFailMintAboveBalance() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    _wethToAWeth(amountToDeposit, user);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    uint256 assets = staticATokenLM.mint(amountToDeposit, user);
  }

  // test rewards
  function testCollectAndUpdateRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);
    assertEq(IERC20(STK_AAVE).balanceOf(address(staticATokenLM)), 0);
    uint256 claimable = staticATokenLM.getTotalClaimableRewards();
    staticATokenLM.collectAndUpdateRewards();
    assertEq(IERC20(STK_AAVE).balanceOf(address(staticATokenLM)), claimable);
  }

  function testClaimRewardsToSelf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function testClaimRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewards(user1);
    assertEq(IERC20(STK_AAVE).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  // should fail as user1 is not a valid claimer
  function testFailClaimRewardsOnBehalfOf() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);

    _skipBlocks(60);

    vm.stopPrank();
    vm.startPrank(user1);

    uint256 claimable = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.claimRewardsOnBehalf(user, user1);
    assertEq(IERC20(STK_AAVE).balanceOf(user1), claimable);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
  }

  function testDepositAWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    // deposit aweth
    weth.approve(LENDING_POOL, amountToDeposit);
    pool.deposit(WETH, amountToDeposit, user, 0);
    assertEq(IERC20(aWETH).balanceOf(user), amountToDeposit);
    IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, false);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    // assertEq(staticATokenLM.balanceOf(user), amountToDeposit); // it's not

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(STK_AAVE).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(aWETH).balanceOf(user), 5 ether);
  }

  function testDepositWETHClaimWithdrawClaim() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    // deposit weth
    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);
    assertEq(staticATokenLM.maxWithdraw(user), amountToDeposit);
    // assertEq(staticATokenLM.balanceOf(user), amountToDeposit); // it's not

    // forward time
    _skipBlocks(60);

    // claim
    assertEq(IERC20(STK_AAVE).balanceOf(user), 0);
    uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
    assertGt(claimable0, 0);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable0);

    // forward time
    _skipBlocks(60);

    // redeem
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
    assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
    assertGt(claimable1, 0);

    // claim on behalf of other user
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimable1 + claimable0);
    assertEq(staticATokenLM.balanceOf(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertGt(AToken(aWETH).balanceOf(user), 5 ether);
  }

  function testTransfer() public {
    uint128 amountToDeposit = 10 ether;
    _fundUser(amountToDeposit, user);

    // deposit weth
    weth.approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 0, true);

    // transfer to 2nd user
    staticATokenLM.transfer(user1, amountToDeposit / 2);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);

    // forward time
    _skipBlocks(60);

    // redeem for both
    uint256 claimambleUser = staticATokenLM.getClaimableRewards(user);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user), user, user);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user), claimambleUser);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 claimambleUser1 = staticATokenLM.getClaimableRewards(user1);
    staticATokenLM.redeem(staticATokenLM.maxRedeem(user1), user1, user1);
    staticATokenLM.claimRewardsToSelf();
    assertEq(IERC20(STK_AAVE).balanceOf(user1), claimambleUser1);
    assertGt(claimambleUser1, 0);

    assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
    assertEq(staticATokenLM.getClaimableRewards(user), 0);
    assertEq(staticATokenLM.getClaimableRewards(user1), 0);
  }

  // getUnclaimedRewards
  function testGetUnclaimedRewards() public {
    uint128 amountToDeposit = 5 ether;
    _fundUser(amountToDeposit, user);

    uint256 shares = _depositAWeth(amountToDeposit, user);
    assertEq(staticATokenLM.getUnclaimedRewards(user), 0);
    _skipBlocks(1000);
    staticATokenLM.redeem(shares, user, user);
    assertGt(staticATokenLM.getUnclaimedRewards(user), 0);
  }
}
