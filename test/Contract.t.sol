// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/StaticATokenLM.sol";
import {WETH9} from 'aave-v3-core/contracts/dependencies/weth/WETH9.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';


contract ContractTest is DSTest {
    using stdStorage for StdStorage;
    Vm private vm = Vm(HEVM_ADDRESS);

    address public user;
    address public user1;
    address constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
    address payable constant WETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant aWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    IPool pool = IPool(LENDING_POOL);
    StaticATokenLM staticATokenLM;

    function setUp() public {
        user = address(vm.addr(1));
        user1 = address(vm.addr(2));
        vm.startPrank(user);
        staticATokenLM = new StaticATokenLM();
        staticATokenLM.initialize(pool, aWETH, "Static Aave Interest Bearing WETH", "stataWETH");
    }

    function testGetters() public {
        assertEq(staticATokenLM.name(), "Static Aave Interest Bearing WETH");
        assertEq(staticATokenLM.symbol(), "stataWETH");

        IERC20 aToken = staticATokenLM.ATOKEN();
        assertEq(address(aToken), aWETH);
        
        address underlyingAddress = staticATokenLM.UNDERLYING_ASSET_ADDRESS();
        assertEq(underlyingAddress, WETH);

        IERC20Detailed underlying = IERC20Detailed(underlyingAddress);
        assertEq(staticATokenLM.decimals(), underlying.decimals());
    }

    function testDepositClaimWithdrawClaimToOtherUser() public {
        vm.deal(user,100 ether);
        uint128 amountToDeposit = 5 ether;
        WETH9 weth = WETH9(WETH);
        weth.deposit{value: amountToDeposit * 2}();
        assertEq(weth.balanceOf(user), amountToDeposit * 2);
        assertEq(staticATokenLM.getTotalClaimableRewards(), 0);

        // deposit aweth
        weth.approve(LENDING_POOL, amountToDeposit);
        pool.deposit(WETH, amountToDeposit, user, 0);
        assertEq(IERC20(aWETH).balanceOf(user), amountToDeposit);
        IERC20(aWETH).approve(address(staticATokenLM), amountToDeposit);
        staticATokenLM.deposit(user, amountToDeposit, 0, false);
        assertEq(staticATokenLM.dynamicBalanceOf(user), amountToDeposit);

        // deposit weth
        weth.approve(address(staticATokenLM), amountToDeposit);
        staticATokenLM.deposit(user, amountToDeposit, 0, true);
        assertGt(staticATokenLM.dynamicBalanceOf(user), amountToDeposit * 2);

        // forward time
        vm.roll(block.number + 60 * 60);
        vm.warp(block.timestamp + 60 * 60 *12);

        // claim
        assertEq(IERC20(STK_AAVE).balanceOf(user), 0);
        uint256 claimable0 = staticATokenLM.getClaimableRewards(user);
        assertEq(staticATokenLM.getTotalClaimableRewards(), claimable0);
        assertGt(claimable0, 0);
        staticATokenLM.claimRewardsToSelf();
        assertEq(IERC20(STK_AAVE).balanceOf(user), claimable0);

        // forward time
        vm.roll(block.number + 60 * 60);
        vm.warp(block.timestamp + 60 * 60 *12);

        // withdraw
        staticATokenLM.withdraw(user, type(uint256).max, true);
        uint256 claimable1 = staticATokenLM.getClaimableRewards(user);
        assertEq(staticATokenLM.getTotalClaimableRewards(), claimable1);
        assertGt(claimable1, 0);

        // claim on behalf of other user
        staticATokenLM.claimRewards(user1);
        assertEq(IERC20(STK_AAVE).balanceOf(user1), claimable1);
        assertEq(staticATokenLM.balanceOf(user), 0);
        assertEq(staticATokenLM.getClaimableRewards(user), 0);
        assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
        assertGt(weth.balanceOf(user), 10 ether);
    }

    function testTransfer() public {
        vm.deal(user,100 ether);
        uint128 amountToDeposit = 5 ether;
        WETH9 weth = WETH9(WETH);
        weth.deposit{value: amountToDeposit * 2}();
        assertEq(weth.balanceOf(user), amountToDeposit * 2);
        assertEq(staticATokenLM.getTotalClaimableRewards(), 0);

        // deposit weth
        weth.approve(address(staticATokenLM), amountToDeposit * 2);
        staticATokenLM.deposit(user, amountToDeposit * 2, 0, true);
        assertEq(staticATokenLM.dynamicBalanceOf(user), amountToDeposit * 2);

        // transfer to 2nd user
        staticATokenLM.transfer(user1, amountToDeposit);
        assertEq(staticATokenLM.getClaimableRewards(user1), 0);

        // forward time
        vm.roll(block.number + 60 * 60);
        vm.warp(block.timestamp + 60 * 60 *12);

        // withdraw for both
        uint256 claimambleUser = staticATokenLM.getClaimableRewards(user);
        staticATokenLM.withdraw(user, type(uint256).max, true);
        staticATokenLM.claimRewardsToSelf();
        assertEq(IERC20(STK_AAVE).balanceOf(user), claimambleUser);
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 claimambleUser1 = staticATokenLM.getClaimableRewards(user1);
        staticATokenLM.withdraw(user1, type(uint256).max, true);
        staticATokenLM.claimRewardsToSelf();
        assertEq(IERC20(STK_AAVE).balanceOf(user1), claimambleUser1);
        assertGt(claimambleUser1, 0);

        assertEq(staticATokenLM.getTotalClaimableRewards(), 0);
        assertEq(staticATokenLM.getClaimableRewards(user), 0);
        assertEq(staticATokenLM.getClaimableRewards(user1), 0);
    }
}
