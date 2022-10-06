// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
import {IInitializableStaticATokenLM} from './IInitializableStaticATokenLM.sol';

interface IStaticATokenLM is IInitializableStaticATokenLM {
  struct SignatureParams {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct PermitParams {
    address owner;
    address spender;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  /**
   * @notice Burns `amount` of static aToken, with recipient receiving the corresponding amount of `ASSET`
   * @param shares The amount to withdraw, in static balance of StaticAToken
   * @param recipient The address that will receive the amount of `ASSET` withdrawn from the Aave protocol
   * @param toUnderlying bool
   * - `true` for the recipient to get underlying tokens (e.g. USDC)
   * - `false` for the recipient to get aTokens (e.g. aUSDC)
   * @return amountToBurn: StaticATokens burnt, static balance
   * @return amountToWithdraw: underlying/aToken send to `recipient`, dynamic balance
   **/
  function redeem(
    uint256 shares,
    address recipient,
    address owner,
    bool toUnderlying
  ) external returns (uint256, uint256);

  /**
   * @notice Deposits `ASSET` in the Aave protocol and mints static aTokens to msg.sender
   * @param assets The amount of underlying `ASSET` to deposit (e.g. deposit of 100 USDC)
   * @param recipient The address that will receive the static aTokens
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param fromUnderlying bool
   * - `true` if the msg.sender comes with underlying tokens (e.g. USDC)
   * - `false` if the msg.sender comes already with aTokens (e.g. aUSDC)
   * @return uint256 The amount of StaticAToken minted, static balance
   **/
  function deposit(
    uint256 assets,
    address recipient,
    uint16 referralCode,
    bool fromUnderlying
  ) external returns (uint256);

  /**
   * @notice Allows to deposit on Aave via meta-transaction
   * https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param depositor Address from which the funds to deposit are going to be pulled
   * @param recipient Address that will receive the staticATokens, in the average case, same as the `depositor`
   * @param value The amount to deposit
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param fromUnderlying bool
   * - `true` if the msg.sender comes with underlying tokens (e.g. USDC)
   * - `false` if the msg.sender comes already with aTokens (e.g. aUSDC)
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param sigParams Signature params: v,r,s
   * @return uint256 The amount of StaticAToken minted, static balance
   */
  function metaDeposit(
    address depositor,
    address recipient,
    uint256 value,
    uint16 referralCode,
    bool fromUnderlying,
    uint256 deadline,
    PermitParams calldata permit,
    SignatureParams calldata sigParams
  ) external returns (uint256);

  /**
   * @notice Allows to withdraw from Aave via meta-transaction
   * https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner Address owning the staticATokens
   * @param recipient Address that will receive the underlying withdrawn from Aave
   * @param staticAmount The amount of staticAToken to withdraw. If > 0, `dynamicAmount` needs to be 0
   * @param dynamicAmount The amount of underlying/aToken to withdraw. If > 0, `staticAmount` needs to be 0
   * @param toUnderlying bool
   * - `true` for the recipient to get underlying tokens (e.g. USDC)
   * - `false` for the recipient to get aTokens (e.g. aUSDC)
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param sigParams Signature params: v,r,s
   * @return amountToBurn: StaticATokens burnt, static balance
   * @return amountToWithdraw: underlying/aToken send to `recipient`, dynamic balance
   */
  function metaWithdraw(
    address owner,
    address recipient,
    uint256 staticAmount,
    uint256 dynamicAmount,
    bool toUnderlying,
    uint256 deadline,
    SignatureParams calldata sigParams
  ) external returns (uint256, uint256);

  /**
   * @notice Returns the Aave liquidity index of the underlying aToken, denominated rate here
   * as it can be considered as an ever-increasing exchange rate
   * @return The liquidity index
   **/
  function rate() external view returns (uint256);

  /**
   * @notice Claims rewards from `INCENTIVES_CONTROLLER` and updates internal accounting of rewards.
   * @return uint256 Amount collected
   */
  function collectAndUpdateRewards() external returns (uint256);

  /**
   * @notice Claim rewards on behalf of a user and send them to a receiver
   * @dev Only callable by if sender is onBehalfOf or sender is approved claimer
   * @param onBehalfOf The address to claim on behalf of
   * @param receiver The address to receive the rewards
   */
  function claimRewardsOnBehalf(address onBehalfOf, address receiver) external;

  /**
   * @notice Claim rewards and send them to a receiver
   * @param receiver The address to receive the rewards
   */
  function claimRewards(address receiver) external;

  /**
   * @notice Claim rewards
   */
  function claimRewardsToSelf() external;

  /**
   * @notice Get the total claimable rewards of the contract.
   * @return uint256 The current balance + pending rewards from the `_incentivesController`
   */
  function getTotalClaimableRewards() external view returns (uint256);

  /**
   * @notice Get the total claimable rewards for a user in WAD
   * @param user The address of the user
   * @return uint256 The claimable amount of rewards in WAD
   */
  function getClaimableRewards(address user) external view returns (uint256);

  /**
   * @notice The unclaimed rewards for a user in WAD
   * @param user The address of the user
   * @return uint256 The unclaimed amount of rewards in WAD
   */
  function getUnclaimedRewards(address user) external view returns (uint256);

  /**
   * @notice The underlying asset reward index in RAY
   * @return uint256 The underlying asset reward index in RAY
   */
  function getCurrentRewardsIndex() external view returns (uint256);

  /**
   * @notice The Pool where the underlying aToken is supplied and withdrawn.
   * @return IPool The Pool address.
   */
  function pool() external view returns (IPool);

  /**
   * @notice The incentives controller required for claiming rewards on behalf of the users.
   * @return IAaveIncentivesController The incentives controller address.
   */
  function incentivesController() external view returns (address);

  /**
   * @notice The aToken used inside the 4626 vault.
   * @return IERC20 The aToken IERC20.
   */
  function aToken() external view returns (IERC20);

  /**
   * @notice The underlying of the aToken used inside the 4626 vault.
   * @return IERC20 The aToken underlying IERC20.
   */
  function aTokenUnderlying() external view returns (IERC20);

  /**
   * @notice The IERC20 that is currently rewarded to addresses of the vault via LM on incentivescontroller.
   * @return IERC20 The IERC20 of the reward.
   */
  function rewardToken() external view returns (IERC20);
}
