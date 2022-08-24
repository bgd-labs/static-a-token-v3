// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IScaledBalanceToken} from 'aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC20Detailed} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IStaticATokenLM} from './IStaticATokenLM.sol';
import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
import {VersionedInitializable} from 'aave-v3-core/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {WadRayMath} from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import {SafeCast} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';

import {IAToken} from './IAToken.sol';
import {ERC20} from './ERC20.sol';
import {SafeERC20} from './SafeERC20.sol'; //TODO: stop this mess with imports
import {IInitializableStaticATokenLM} from './IInitializableStaticATokenLM.sol';
import {StaticATokenErrors} from './StaticATokenErrors.sol';
import {RayMathNoRounding} from './RayMathNoRounding.sol';

/**
 * @title StaticATokenLM
 * @notice Wrapper token that allows to deposit tokens on the Aave protocol and receive
 * a token which balance doesn't increase automatically, but uses an ever-increasing exchange rate.
 * The token support claiming liquidity mining rewards from the Aave system.
 * @author Aave
 **/
contract StaticATokenLM is
  VersionedInitializable,
  ERC20('STATIC_ATOKEN_IMPL', 'STATIC_ATOKEN_IMPL', 18),
  IStaticATokenLM
{
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using RayMathNoRounding for uint256;

  bytes32 public constant METADEPOSIT_TYPEHASH =
    keccak256(
      'Deposit(address depositor,address recipient,uint256 value,uint16 referralCode,bool fromUnderlying,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant METAWITHDRAWAL_TYPEHASH =
    keccak256(
      'Withdraw(address owner,address recipient,uint256 staticAmount,uint256 dynamicAmount,bool toUnderlying,uint256 nonce,uint256 deadline)'
    );

  uint256 public constant STATIC_ATOKEN_LM_REVISION = 0x1;

  struct UserRewardsData {
    uint128 rewardsIndexOnLastInteraction; // (in RAYs)
    uint128 unclaimedRewards; // (in RAYs)
  }

  IPool public override LENDING_POOL;
  IAaveIncentivesController public override INCENTIVES_CONTROLLER;
  IERC20 public override ATOKEN;
  IERC20 public override ATOKEN_UNDERLYING;
  IERC20 public override REWARD_TOKEN;

  mapping(address => UserRewardsData) private _userRewardsData;

  ///@inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return STATIC_ATOKEN_LM_REVISION;
  }

  ///@inheritdoc IInitializableStaticATokenLM
  function initialize(
    IPool pool,
    address aToken,
    string calldata staticATokenName,
    string calldata staticATokenSymbol
  ) external override initializer {
    LENDING_POOL = pool;
    ATOKEN = IERC20(aToken);

    name = staticATokenName;
    symbol = staticATokenSymbol;
    decimals = IERC20Detailed(aToken).decimals(); // maybe make sense to add setter as was before

    ATOKEN_UNDERLYING = IERC20(IAToken(aToken).UNDERLYING_ASSET_ADDRESS());
    ATOKEN_UNDERLYING.safeApprove(address(pool), type(uint256).max);

    try IAToken(aToken).getIncentivesController() returns (
      IAaveIncentivesController incentivesController
    ) {
      if (address(incentivesController) != address(0)) {
        INCENTIVES_CONTROLLER = incentivesController;
        REWARD_TOKEN = IERC20(INCENTIVES_CONTROLLER.REWARD_TOKEN());
      }
    } catch {}

    emit Initialized(
      address(pool),
      aToken,
      staticATokenName,
      staticATokenSymbol
    );
  }

  ///@inheritdoc IStaticATokenLM
  function deposit(
    address recipient,
    uint256 amount,
    uint16 referralCode,
    bool fromUnderlying
  ) external override returns (uint256) {
    return
      _deposit(msg.sender, recipient, amount, referralCode, fromUnderlying);
  }

  ///@inheritdoc IStaticATokenLM
  function withdraw(
    address recipient,
    uint256 amount,
    bool toUnderlying
  ) external override returns (uint256, uint256) {
    return _withdraw(msg.sender, recipient, amount, 0, toUnderlying);
  }

  ///@inheritdoc IStaticATokenLM
  function withdrawDynamicAmount(
    address recipient,
    uint256 amount,
    bool toUnderlying
  ) external override returns (uint256, uint256) {
    return _withdraw(msg.sender, recipient, 0, amount, toUnderlying);
  }

  ///@inheritdoc IStaticATokenLM
  function metaDeposit(
    address depositor,
    address recipient,
    uint256 value,
    uint16 referralCode,
    bool fromUnderlying,
    uint256 deadline,
    SignatureParams calldata sigParams
  ) external override returns (uint256) {
    require(depositor != address(0), StaticATokenErrors.INVALID_DEPOSITOR);
    //solium-disable-next-line
    require(deadline >= block.timestamp, StaticATokenErrors.INVALID_EXPIRATION);
    uint256 nonce = nonces[depositor];

    // Unchecked because the only math done is incrementing
    // the owner's nonce which cannot realistically overflow.
    unchecked {
      bytes32 digest = keccak256(
        abi.encodePacked(
          '\x19\x01',
          DOMAIN_SEPARATOR(),
          keccak256(
            abi.encode(
              METADEPOSIT_TYPEHASH,
              depositor,
              recipient,
              value,
              referralCode,
              fromUnderlying,
              nonce,
              deadline
            )
          )
        )
      );
      nonces[depositor] = nonce + 1;
      require(
        depositor == ecrecover(digest, sigParams.v, sigParams.r, sigParams.s),
        StaticATokenErrors.INVALID_SIGNATURE
      );
    }
    return _deposit(depositor, recipient, value, referralCode, fromUnderlying);
  }

  ///@inheritdoc IStaticATokenLM
  function metaWithdraw(
    address owner,
    address recipient,
    uint256 staticAmount,
    uint256 dynamicAmount,
    bool toUnderlying,
    uint256 deadline,
    SignatureParams calldata sigParams
  ) external override returns (uint256, uint256) {
    require(owner != address(0), StaticATokenErrors.INVALID_OWNER);
    //solium-disable-next-line
    require(deadline >= block.timestamp, StaticATokenErrors.INVALID_EXPIRATION);
    uint256 nonce = nonces[owner];
    // Unchecked because the only math done is incrementing
    // the owner's nonce which cannot realistically overflow.
    unchecked {
      bytes32 digest = keccak256(
        abi.encodePacked(
          '\x19\x01',
          DOMAIN_SEPARATOR(),
          keccak256(
            abi.encode(
              METAWITHDRAWAL_TYPEHASH,
              owner,
              recipient,
              staticAmount,
              dynamicAmount,
              toUnderlying,
              nonce,
              deadline
            )
          )
        )
      );
      nonces[owner] = nonce + 1;
      require(
        owner == ecrecover(digest, sigParams.v, sigParams.r, sigParams.s),
        StaticATokenErrors.INVALID_SIGNATURE
      );
    }
    return
      _withdraw(owner, recipient, staticAmount, dynamicAmount, toUnderlying);
  }

  ///@inheritdoc IStaticATokenLM
  function previewRedeem(uint256 shares)
    external
    view
    override
    returns (uint256)
  {
    return _convertToAssets(shares, rate());
  }

  ///@inheritdoc IStaticATokenLM
  function previewWithdraw(uint256 assets)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToShares(assets, rate());
  }

  ///@inheritdoc IStaticATokenLM
  function previewDeposit(uint256 assets)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToShares(assets, rate());
  }

  ///@inheritdoc IStaticATokenLM
  function rate() public view override returns (uint256) {
    return LENDING_POOL.getReserveNormalizedIncome(address(ATOKEN_UNDERLYING));
  }

  function _convertToShares(uint256 amount, uint256 rate)
    internal
    pure
    returns (uint256)
  {
    return amount.rayDiv(rate);
  }

  function _convertToAssets(uint256 shares, uint256 rate)
    internal
    pure
    returns (uint256)
  {
    return shares.rayMul(rate);
  }

  function _deposit(
    address depositor,
    address recipient,
    uint256 amount,
    uint16 referralCode,
    bool fromUnderlying
  ) internal returns (uint256) {
    require(recipient != address(0), StaticATokenErrors.INVALID_RECIPIENT);

    if (fromUnderlying) {
      ATOKEN_UNDERLYING.safeTransferFrom(depositor, address(this), amount);
      LENDING_POOL.deposit(
        address(ATOKEN_UNDERLYING),
        amount,
        address(this),
        referralCode
      );
    } else {
      ATOKEN.safeTransferFrom(depositor, address(this), amount);
    }
    uint256 amountToMint = _convertToShares(amount, rate());
    _mint(recipient, amountToMint);

    return amountToMint;
  }

  function _withdraw(
    address owner,
    address recipient,
    uint256 staticAmount,
    uint256 dynamicAmount,
    bool toUnderlying
  ) internal returns (uint256, uint256) {
    require(recipient != address(0), StaticATokenErrors.INVALID_RECIPIENT);
    require(
      staticAmount == 0 || dynamicAmount == 0,
      StaticATokenErrors.ONLY_ONE_AMOUNT_FORMAT_ALLOWED
    );

    uint256 userBalance = balanceOf[owner];

    uint256 amountToWithdraw;
    uint256 amountToBurn;

    uint256 currentRate = rate();
    if (staticAmount > 0) {
      amountToBurn = (staticAmount > userBalance) ? userBalance : staticAmount;
      amountToWithdraw = _convertToAssets(amountToBurn, currentRate);
    } else {
      uint256 dynamicUserBalance = _convertToAssets(userBalance, currentRate);
      amountToWithdraw = (dynamicAmount > dynamicUserBalance)
        ? dynamicUserBalance
        : dynamicAmount;
      amountToBurn = _convertToShares(amountToWithdraw, currentRate);
    }

    _burn(owner, amountToBurn);

    if (toUnderlying) {
      LENDING_POOL.withdraw(
        address(ATOKEN_UNDERLYING),
        amountToWithdraw,
        recipient
      );
    } else {
      ATOKEN.safeTransfer(recipient, amountToWithdraw);
    }

    return (amountToBurn, amountToWithdraw);
  }

  /**
   * @notice Updates rewards for senders and receiver in a transfer (not updating rewards for address(0))
   * @param from The address of the sender of tokens
   * @param to The address of the receiver of tokens
   * @param amount The amount of tokens to transfer in WAD
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return;
    }
    uint256 rewardsIndex = getCurrentRewardsIndex();
    if (from != address(0)) {
      _updateUser(from, rewardsIndex);
    }
    if (to != address(0) && from != to) {
      _updateUser(to, rewardsIndex);
    }
  }

  ///@inheritdoc IStaticATokenLM
  function collectAndUpdateRewards() public override returns (uint256) {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return 0;
    }

    address[] memory assets = new address[](1);
    assets[0] = address(ATOKEN);

    return
      INCENTIVES_CONTROLLER.claimRewards(
        assets,
        type(uint256).max,
        address(this)
      );
  }

  /**
   * @notice Claim rewards on behalf of a user and send them to a receiver
   * @param onBehalfOf The address to claim on behalf of
   * @param receiver The address to receive the rewards
   */
  function _claimRewardsOnBehalf(address onBehalfOf, address receiver)
    internal
  {
    uint256 currentRewardsIndex = getCurrentRewardsIndex();
    uint256 balance = balanceOf[onBehalfOf];
    uint256 userReward = _getClaimableRewards(
      onBehalfOf,
      balance,
      currentRewardsIndex
    );
    uint256 totalRewardTokenBalance = REWARD_TOKEN.balanceOf(address(this));
    uint256 unclaimedReward = 0;

    if (userReward > totalRewardTokenBalance) {
      totalRewardTokenBalance += collectAndUpdateRewards();
    }

    if (userReward > totalRewardTokenBalance) {
      unclaimedReward = userReward - totalRewardTokenBalance;
      userReward = totalRewardTokenBalance;
    }
    if (userReward > 0) {
      _userRewardsData[onBehalfOf].unclaimedRewards = unclaimedReward
        .toUint128();
      _userRewardsData[onBehalfOf]
        .rewardsIndexOnLastInteraction = currentRewardsIndex.toUint128();
      REWARD_TOKEN.safeTransfer(receiver, userReward);
    }
  }

  function claimRewardsOnBehalf(address onBehalfOf, address receiver)
    external
    override
  {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return;
    }

    require(
      msg.sender == onBehalfOf ||
        msg.sender == INCENTIVES_CONTROLLER.getClaimer(onBehalfOf),
      StaticATokenErrors.INVALID_CLAIMER
    );
    _claimRewardsOnBehalf(onBehalfOf, receiver);
  }

  function claimRewards(address receiver) external override {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return;
    }
    _claimRewardsOnBehalf(msg.sender, receiver);
  }

  function claimRewardsToSelf() external override {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return;
    }
    _claimRewardsOnBehalf(msg.sender, msg.sender);
  }

  /**
   * @notice Adding the pending rewards to the unclaimed for specific user and updating user index
   * @param user The address of the user to update
   */
  function _updateUser(address user, uint256 currentRewardsIndex) internal {
    uint256 balance = balanceOf[user];
    if (balance > 0) {
      _userRewardsData[user].unclaimedRewards = _getClaimableRewards(
        user,
        balance,
        currentRewardsIndex
      ).toUint128();
    }
    _userRewardsData[user].rewardsIndexOnLastInteraction = currentRewardsIndex
      .toUint128();
  }

  /**
   * @notice Compute the pending in RAY (rounded down). Pending is the amount to add (not yet unclaimed) rewards in RAY (rounded down).
   * @param balance The balance of the user
   * @param rewardsIndexOnLastInteraction The index which was on the last interaction of the user
   * @param currentRewardsIndex The current rewards index in the system
   * @return The amound of pending rewards in RAY
   */
  function _getPendingRewards(
    uint256 balance,
    uint256 rewardsIndexOnLastInteraction,
    uint256 currentRewardsIndex
  ) internal view returns (uint256) {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      // TODO: let's see, looks useless
      return 0;
    }

    if (balance == 0) {
      return 0;
    }

    uint256 rayBalance = balance.wadToRay();
    return
      rayBalance.rayMulNoRounding(
        currentRewardsIndex - rewardsIndexOnLastInteraction
      );
  }

  /**
   * @notice Compute the claimable rewards for a user
   * @param user The address of the user
   * @param balance The balance of the user in WAD
   * @return The total rewards that can be claimed by the user (if `fresh` flag true, after updating rewards)
   */
  function _getClaimableRewards(
    address user,
    uint256 balance,
    uint256 currentRewardsIndex
  ) internal view returns (uint256) {
    UserRewardsData memory currentUserRewardsData = _userRewardsData[user];
    return
      currentUserRewardsData.unclaimedRewards +
      _getPendingRewards(
        balance,
        currentUserRewardsData.rewardsIndexOnLastInteraction,
        currentRewardsIndex
      );
  }

  ///@inheritdoc IStaticATokenLM
  function getCurrentRewardsIndex() public view override returns (uint256) {
    (
      uint256 index,
      uint256 emissionPerSecond,
      uint256 lastUpdateTimestamp
    ) = INCENTIVES_CONTROLLER.getAssetData(address(ATOKEN));
    uint256 distributionEnd = INCENTIVES_CONTROLLER.DISTRIBUTION_END();
    uint256 totalSupply = IScaledBalanceToken(address(ATOKEN))
      .scaledTotalSupply();

    if (
      emissionPerSecond == 0 ||
      totalSupply == 0 ||
      lastUpdateTimestamp == block.timestamp ||
      lastUpdateTimestamp >= distributionEnd
    ) {
      return index;
    }

    uint256 currentTimestamp = block.timestamp > distributionEnd
      ? distributionEnd
      : block.timestamp;
    uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
    return
      ((emissionPerSecond * timeDelta * (10**uint256(18))) / totalSupply) +
      index; // TODO: 18- precision, should be loaded
  }

  ///@inheritdoc IStaticATokenLM
  function getTotalClaimableRewards() external view override returns (uint256) {
    if (address(INCENTIVES_CONTROLLER) == address(0)) {
      return 0;
    }

    address[] memory assets = new address[](1);
    assets[0] = address(ATOKEN);
    uint256 freshRewards = INCENTIVES_CONTROLLER.getRewardsBalance(
      assets,
      address(this)
    );
    return REWARD_TOKEN.balanceOf(address(this)) + freshRewards;
  }

  ///@inheritdoc IStaticATokenLM
  function getClaimableRewards(address user)
    external
    view
    override
    returns (uint256)
  {
    return
      _getClaimableRewards(user, balanceOf[user], getCurrentRewardsIndex());
  }

  ///@inheritdoc IStaticATokenLM
  function getUnclaimedRewards(address user)
    external
    view
    override
    returns (uint256)
  {
    return
      uint256(_userRewardsData[user].unclaimedRewards).rayToWadNoRounding();
  }

  function getIncentivesController()
    external
    view
    override
    returns (IAaveIncentivesController)
  {
    return INCENTIVES_CONTROLLER;
  }

  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return address(ATOKEN_UNDERLYING);
  }

  // 4626 compatibility
  ///@inheritdoc IStaticATokenLM
  function asset() external view override returns (address) {
    return address(ATOKEN);
  }

  ///@inheritdoc IStaticATokenLM
  function totalAssets() external view override returns (uint256) {
    return ATOKEN.balanceOf(address(this));
  }

  ///@inheritdoc IStaticATokenLM
  function convertToShares(uint256 amount)
    external
    view
    override
    returns (uint256)
  {
    return _convertToShares(amount, rate());
  }

  ///@inheritdoc IStaticATokenLM
  function convertToAssets(uint256 amount)
    external
    view
    override
    returns (uint256)
  {
    return _convertToAssets(amount, rate());
  }

  ///@inheritdoc IStaticATokenLM
  function maxDeposit(address) public view virtual override returns (uint256) {
    return type(uint256).max;
  }

  ///@inheritdoc IStaticATokenLM
  function maxMint(address) public view virtual override returns (uint256) {
    return type(uint256).max;
  }

  ///@inheritdoc IStaticATokenLM
  function maxWithdraw(address owner)
    public
    view
    virtual
    override
    returns (uint256)
  {
    uint256 userBalance = balanceOf[owner];
    uint256 currentRate = rate();
    return _convertToAssets(userBalance, currentRate);
  }

  ///@inheritdoc IStaticATokenLM
  function maxRedeem(address owner)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return balanceOf[owner];
  }

  ///@inheritdoc IStaticATokenLM
  function deposit(uint256 assets, address receiver)
    public
    virtual
    override
    returns (uint256)
  {
    require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

    return _deposit(msg.sender, receiver, assets, 0, false);
  }

  ///@inheritdoc IStaticATokenLM
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public virtual override returns (uint256) {
    require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

    (uint256 shares, ) = _withdraw(msg.sender, receiver, 0, assets, false);

    return shares;
  }

  ///@inheritdoc IStaticATokenLM
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public virtual override returns (uint256) {
    require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

    (, uint256 assets) = _withdraw(msg.sender, receiver, shares, 0, false);

    return assets;
  }
}
