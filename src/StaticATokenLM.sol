// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IScaledBalanceToken} from 'aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol';
import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
import {WadRayMath} from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import {SafeCast} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';

import {IStaticATokenLM} from './interfaces/IStaticATokenLM.sol';
import {IAToken} from './interfaces/IAToken.sol';
import {ERC20} from './ERC20.sol';
import {IInitializableStaticATokenLM} from './interfaces/IInitializableStaticATokenLM.sol';
import {StaticATokenErrors} from './StaticATokenErrors.sol';
import {RayMathExplicitRounding, Rounding} from './RayMathExplicitRounding.sol';
import {IERC4626} from './interfaces/IERC4626.sol';

/**
 * @title StaticATokenLM
 * @notice Wrapper token that allows to deposit tokens on the Aave protocol and receive
 * a token which balance doesn't increase automatically, but uses an ever-increasing exchange rate.
 * The token support claiming liquidity mining rewards from the Aave system.
 * @author Aave
 **/
contract StaticATokenLM is
  Initializable,
  ERC20('STATIC__aToken_IMPL', 'STATIC__aToken_IMPL', 18),
  IStaticATokenLM,
  IERC4626
{
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using RayMathExplicitRounding for uint256;

  bytes32 public constant METADEPOSIT_TYPEHASH =
    keccak256(
      'Deposit(address depositor,address recipient,uint256 value,uint16 referralCode,bool fromUnderlying,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant METAWITHDRAWAL_TYPEHASH =
    keccak256(
      'Withdraw(address owner,address recipient,uint256 staticAmount,uint256 dynamicAmount,bool toUnderlying,uint256 nonce,uint256 deadline)'
    );

  uint256 public constant STATIC__ATOKEN_LM_REVISION = 1;

  uint8 public constant REWARD_PRECISION = 18;

  struct UserRewardsData {
    uint128 rewardsIndexOnLastInteraction; // (in RAYs)
    uint128 unclaimedRewards; // (in RAYs)
  }

  IPool internal _pool;
  IAaveIncentivesController internal _incentivesController;
  IERC20 internal _aToken;
  IERC20 internal _aTokenUnderlying;
  IERC20 internal _rewardToken;

  mapping(address => UserRewardsData) internal _userRewardsData;

  ///@inheritdoc IInitializableStaticATokenLM
  function initialize(
    IPool pool,
    address aToken,
    string calldata staticATokenName,
    string calldata staticATokenSymbol
  ) external override initializer {
    _pool = pool;
    _aToken = IERC20(aToken);

    name = staticATokenName;
    symbol = staticATokenSymbol;
    decimals = IERC20Metadata(aToken).decimals();

    _aTokenUnderlying = IERC20(IAToken(aToken).UNDERLYING_ASSET_ADDRESS());
    _aTokenUnderlying.safeApprove(address(pool), type(uint256).max);

    try IAToken(aToken).getIncentivesController() returns (
      IAaveIncentivesController incentivesController
    ) {
      if (address(incentivesController) != address(0)) {
        _incentivesController = incentivesController;
        _rewardToken = IERC20(_incentivesController.REWARD_TOKEN());
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
    uint256 assets,
    address recipient,
    uint16 referralCode,
    bool fromUnderlying
  ) external override returns (uint256) {
    return
      _deposit(msg.sender, recipient, assets, referralCode, fromUnderlying);
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

  ///@inheritdoc IERC4626
  function previewRedeem(uint256 shares)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToAssets(shares, Rounding.DOWN);
  }

  ///@inheritdoc IERC4626
  function previewMint(uint256 shares)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToAssets(shares, Rounding.UP);
  }

  ///@inheritdoc IERC4626
  function previewWithdraw(uint256 assets)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToShares(assets, Rounding.UP);
  }

  ///@inheritdoc IERC4626
  function previewDeposit(uint256 assets)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToShares(assets, Rounding.DOWN);
  }

  ///@inheritdoc IStaticATokenLM
  function rate() public view override returns (uint256) {
    return _pool.getReserveNormalizedIncome(address(_aTokenUnderlying));
  }

  ///@inheritdoc IStaticATokenLM
  function collectAndUpdateRewards() public override returns (uint256) {
    if (address(_incentivesController) == address(0)) {
      return 0;
    }

    address[] memory assets = new address[](1);
    assets[0] = address(_aToken);

    return
      _incentivesController.claimRewards(
        assets,
        type(uint256).max,
        address(this)
      );
  }

  function claimRewardsOnBehalf(address onBehalfOf, address receiver)
    external
    override
  {
    if (address(_incentivesController) == address(0)) {
      return;
    }

    require(
      msg.sender == onBehalfOf ||
        msg.sender == _incentivesController.getClaimer(onBehalfOf),
      StaticATokenErrors.INVALID_CLAIMER
    );
    _claimRewardsOnBehalf(onBehalfOf, receiver);
  }

  function claimRewards(address receiver) external override {
    if (address(_incentivesController) == address(0)) {
      return;
    }
    _claimRewardsOnBehalf(msg.sender, receiver);
  }

  function claimRewardsToSelf() external override {
    if (address(_incentivesController) == address(0)) {
      return;
    }
    _claimRewardsOnBehalf(msg.sender, msg.sender);
  }

  ///@inheritdoc IStaticATokenLM
  // @dev This should be simplified once the _incentivesController is updated to expose index directly.
  function getCurrentRewardsIndex() public view override returns (uint256) {
    if (address(_incentivesController) == address(0)) {
      return 0;
    }
    (
      uint256 index,
      uint256 emissionPerSecond,
      uint256 lastUpdateTimestamp
    ) = _incentivesController.getAssetData(address(_aToken));
    uint256 distributionEnd = _incentivesController.DISTRIBUTION_END();
    uint256 totalSupply = IScaledBalanceToken(address(_aToken))
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
      ((emissionPerSecond * timeDelta * (10**uint256(REWARD_PRECISION))) /
        totalSupply) + index;
  }

  ///@inheritdoc IStaticATokenLM
  function getTotalClaimableRewards() external view override returns (uint256) {
    if (address(_incentivesController) == address(0)) {
      return 0;
    }

    address[] memory assets = new address[](1);
    assets[0] = address(_aToken);
    uint256 freshRewards = _incentivesController.getRewardsBalance(
      assets,
      address(this)
    );
    return _rewardToken.balanceOf(address(this)) + freshRewards;
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
    return uint256(_userRewardsData[user].unclaimedRewards).rayToWadRoundDown();
  }

  // 4626 compatibility
  ///@inheritdoc IERC4626
  function asset() external view override returns (address) {
    return address(_aToken);
  }

  ///@inheritdoc IStaticATokenLM
  function incentivesController()
    external
    view
    override
    returns (IAaveIncentivesController)
  {
    return _incentivesController;
  }

  ///@inheritdoc IStaticATokenLM
  function pool() external view override returns (IPool) {
    return _pool;
  }

  ///@inheritdoc IStaticATokenLM
  function aToken() external view override returns (IERC20) {
    return _aToken;
  }

  ///@inheritdoc IStaticATokenLM
  function aTokenUnderlying() external view override returns (IERC20) {
    return _aTokenUnderlying;
  }

  ///@inheritdoc IStaticATokenLM
  function rewardToken() external view override returns (IERC20) {
    return _rewardToken;
  }

  ///@inheritdoc IERC4626
  function totalAssets() external view override returns (uint256) {
    return _aToken.balanceOf(address(this));
  }

  ///@inheritdoc IERC4626
  function convertToShares(uint256 amount)
    external
    view
    override
    returns (uint256)
  {
    return _convertToShares(amount, Rounding.DOWN);
  }

  function _convertToShares(uint256 amount, Rounding rounding)
    internal
    view
    returns (uint256)
  {
    if (rounding == Rounding.UP) return amount.rayDivRoundUp(rate());
    return amount.rayDivRoundDown(rate());
  }

  ///@inheritdoc IERC4626
  function convertToAssets(uint256 shares)
    external
    view
    override
    returns (uint256)
  {
    return _convertToAssets(shares, Rounding.DOWN);
  }

  function _convertToAssets(uint256 shares, Rounding rounding)
    internal
    view
    returns (uint256)
  {
    if (rounding == Rounding.UP) return shares.rayMulRoundUp(rate());
    return shares.rayMulRoundDown(rate());
  }

  ///@inheritdoc IERC4626
  function maxDeposit(address) public view virtual override returns (uint256) {
    return type(uint256).max;
  }

  ///@inheritdoc IERC4626
  function maxMint(address) public view virtual override returns (uint256) {
    return type(uint256).max;
  }

  ///@inheritdoc IERC4626
  function maxWithdraw(address owner)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _convertToAssets(balanceOf[owner], Rounding.DOWN);
  }

  ///@inheritdoc IERC4626
  function maxRedeem(address owner)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return balanceOf[owner];
  }

  ///@inheritdoc IERC4626
  function deposit(uint256 assets, address receiver)
    public
    virtual
    override
    returns (uint256)
  {
    require(assets <= maxDeposit(receiver), 'ERC4626: deposit more than max');

    return _deposit(msg.sender, receiver, assets, 0, false);
  }

  ///@inheritdoc IERC4626
  function mint(uint256 shares, address receiver)
    public
    virtual
    override
    returns (uint256)
  {
    require(shares <= maxMint(receiver), 'ERC4626: mint more than max');

    uint256 assets = previewMint(shares);
    _deposit(msg.sender, receiver, assets, 0, false);

    return assets;
  }

  ///@inheritdoc IERC4626
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public virtual override returns (uint256) {
    require(assets <= maxWithdraw(owner), 'ERC4626: withdraw more than max');

    (uint256 shares, ) = _withdraw(owner, receiver, 0, assets, false);

    return shares;
  }

  ///@inheritdoc IERC4626
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public virtual override returns (uint256) {
    require(shares <= maxRedeem(owner), 'ERC4626: redeem more than max');

    (, uint256 assets) = _withdraw(owner, receiver, shares, 0, false);

    return assets;
  }

  ///@inheritdoc IStaticATokenLM
  function redeem(
    uint256 shares,
    address receiver,
    address owner,
    bool toUnderlying
  ) public virtual override returns (uint256, uint256) {
    require(shares <= maxRedeem(owner), 'ERC4626: redeem more than max');

    return _withdraw(owner, receiver, shares, 0, toUnderlying);
  }

  function _deposit(
    address depositor,
    address recipient,
    uint256 assets,
    uint16 referralCode,
    bool fromUnderlying
  ) internal returns (uint256) {
    require(recipient != address(0), StaticATokenErrors.INVALID_RECIPIENT);

    if (fromUnderlying) {
      _aTokenUnderlying.safeTransferFrom(depositor, address(this), assets);
      _pool.deposit(
        address(_aTokenUnderlying),
        assets,
        address(this),
        referralCode
      );
    } else {
      _aToken.safeTransferFrom(depositor, address(this), assets);
    }
    uint256 shares = previewDeposit(assets);

    _mint(recipient, shares);

    emit Deposit(msg.sender, recipient, assets, shares);

    return shares;
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

    uint256 amountToWithdraw = dynamicAmount;
    uint256 shares = staticAmount;

    if (staticAmount > 0) {
      amountToWithdraw = previewRedeem(staticAmount);
    } else {
      shares = previewWithdraw(dynamicAmount);
    }

    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max)
        allowance[owner][msg.sender] = allowed - shares;
    }

    _burn(owner, shares);

    emit Withdraw(msg.sender, recipient, owner, amountToWithdraw, shares);

    if (toUnderlying) {
      _pool.withdraw(address(_aTokenUnderlying), amountToWithdraw, recipient);
    } else {
      _aToken.safeTransfer(recipient, amountToWithdraw);
    }

    return (shares, amountToWithdraw);
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
    if (address(_incentivesController) == address(0)) {
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
    if (balance == 0) {
      return 0;
    }

    uint256 rayBalance = balance.wadToRay();
    return
      rayBalance.rayMulRoundDown(
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
    uint256 totalRewardTokenBalance = _rewardToken.balanceOf(address(this));
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
      _rewardToken.safeTransfer(receiver, userReward);
    }
  }
}
