// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IPool } from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IAaveIncentivesController } from "aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol";
import { IInitializableStaticATokenLM } from "./IInitializableStaticATokenLM.sol";

interface IStaticATokenLM is IInitializableStaticATokenLM {
  struct SignatureParams {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  /**
   * @notice Deposits `ASSET` in the Aave protocol and mints static aTokens to msg.sender
   * @param recipient The address that will receive the static aTokens
   * @param amount The amount of underlying `ASSET` to deposit (e.g. deposit of 100 USDC)
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param fromUnderlying bool
   * - `true` if the msg.sender comes with underlying tokens (e.g. USDC)
   * - `false` if the msg.sender comes already with aTokens (e.g. aUSDC)
   * @return uint256 The amount of StaticAToken minted, static balance
   **/
  function deposit(
    address recipient,
    uint256 amount,
    uint16 referralCode,
    bool fromUnderlying
  ) external returns (uint256);

  /**
   * @notice Burns `amount` of static aToken, with recipient receiving the corresponding amount of `ASSET`
   * @param recipient The address that will receive the amount of `ASSET` withdrawn from the Aave protocol
   * @param amount The amount to withdraw, in static balance of StaticAToken
   * @param toUnderlying bool
   * - `true` for the recipient to get underlying tokens (e.g. USDC)
   * - `false` for the recipient to get aTokens (e.g. aUSDC)
   * @return amountToBurn: StaticATokens burnt, static balance
   * @return amountToWithdraw: underlying/aToken send to `recipient`, dynamic balance
   **/
  function withdraw(
    address recipient,
    uint256 amount,
    bool toUnderlying
  ) external returns (uint256, uint256);

  /**
   * @notice Burns `amount` of static aToken, with recipient receiving the corresponding amount of `ASSET`
   * @param recipient The address that will receive the amount of `ASSET` withdrawn from the Aave protocol
   * @param amount The amount to withdraw, in dynamic balance of aToken/underlying asset
   * @param toUnderlying bool
   * - `true` for the recipient to get underlying tokens (e.g. USDC)
   * - `false` for the recipient to get aTokens (e.g. aUSDC)
   * @return amountToBurn: StaticATokens burnt, static balance
   * @return amountToWithdraw: underlying/aToken send to `recipient`, dynamic balance
   **/
  function withdrawDynamicAmount(
    address recipient,
    uint256 amount,
    bool toUnderlying
  ) external returns (uint256, uint256);

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
   * @notice Utility method to get the current aToken balance of an user, from his staticAToken balance
   * @param account The address of the user
   * @return uint256 The aToken balance
   **/
  function previewRedeem(address account) external view returns (uint256);

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
   * @return The current balance + pending rewards from the `_incentivesController`
   */
  function getTotalClaimableRewards() external view returns (uint256);

  /**
   * @notice Get the total claimable rewards for a user in WAD
   * @param user The address of the user
   * @return The claimable amount of rewards in WAD
   */
  function getClaimableRewards(address user) external view returns (uint256);

  /**
   * @notice The unclaimed rewards for a user in WAD
   * @param user The address of the user
   * @return The unclaimed amount of rewards in WAD
   */
  function getUnclaimedRewards(address user) external view returns (uint256);

  /**
   * @notice The underlying asset reward index in RAY
   * @return The underlying asset reward index in RAY
   */
  function getCurrentRewardsIndex() external view returns (uint256);

  function LENDING_POOL() external view returns (IPool);

  function INCENTIVES_CONTROLLER()
    external
    view
    returns (IAaveIncentivesController);

  function ATOKEN() external view returns (IERC20);

  function ATOKEN_UNDERLYING() external view returns (IERC20);

  function REWARD_TOKEN() external view returns (IERC20);

  function UNDERLYING_ASSET_ADDRESS() external view returns (address);

  function getIncentivesController()
    external
    view
    returns (IAaveIncentivesController);

  // from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/interfaces/IERC4626.sol
  /**
   * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
   *
   * - MUST be an ERC-20 token contract.
   * - MUST NOT revert.
   */
  function asset() external view returns (address assetTokenAddress);

  /**
   * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
   *
   * - SHOULD include any compounding that occurs from yield.
   * - MUST be inclusive of any fees that are charged against assets in the Vault.
   * - MUST NOT revert.
   */
  function totalAssets() external view returns (uint256 totalManagedAssets);

  /**
   * @notice Converts an aToken or underlying amount to the what it is denominated on the aToken as
   * scaled balance, function of the principal and the liquidity index
   * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
   * scenario where all the conditions are met.
   *
   * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
   * - MUST NOT show any variations depending on the caller.
   * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
   * - MUST NOT revert.
   *
   * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
   * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
   * from.
   */
  function convertToShares(uint256 assets)
    external
    view
    returns (uint256 shares);

  /**
   * @notice Converts a static amount (scaled balance on aToken) to the aToken/underlying value,
   * using the current liquidity index on Aave
   * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
   * scenario where all the conditions are met.
   *
   * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
   * - MUST NOT show any variations depending on the caller.
   * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
   * - MUST NOT revert.
   *
   * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
   * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
   * from.
   */
  function convertToAssets(uint256 shares)
    external
    view
    returns (uint256 assets);

  /**
   * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
   * through a deposit call.
   *
   * - MUST return a limited value if receiver is subject to some deposit limit.
   * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
   * - MUST NOT revert.
   */
  function maxDeposit(address receiver)
    external
    view
    returns (uint256 maxAssets);

  /**
   * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
   * - MUST return a limited value if receiver is subject to some mint limit.
   * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
   * - MUST NOT revert.
   */
  function maxMint(address receiver) external view returns (uint256 maxShares);

  /**
   * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
   * Vault, through a withdraw call.
   *
   * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
   * - MUST NOT revert.
   */
  function maxWithdraw(address owner) external view returns (uint256 maxAssets);

  /**
   * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
   * through a redeem call.
   *
   * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
   * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
   * - MUST NOT revert.
   */
  function maxRedeem(address owner) external view returns (uint256 maxShares);

  /**
   * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
   *
   * - MUST emit the Withdraw event.
   * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
   *   redeem execution, and are accounted for during redeem.
   * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
   *   not having enough shares, etc).
   *
   * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
   * Those methods should be performed separately.
   */
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) external returns (uint256 assets);
}

// must check
// previewDeposit / previewMint
// does it make sense to provide deposit
