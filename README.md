# WIP: Static aToken with liquidity mining

## About

This repository contains a [eip #4626](https://eips.ethereum.org/EIPS/eip-4626) compatible token vault implementation for Aave aTokens.
The static token vault tokens are designed to increase in value instead of balance, which simplifies integration in certain applications.

## Limitations

The static aToken will keep track of LM rewards per user only for the first token listed on the incentives controller present on token initialization. This is probably good enough for most use cases.

The static aToken is using transparent proxy pattern, so the token is potentially upgradable to keep track of a new incentives controller or token down the line.

## StaticATokenLM interface

The `StaticATokenLM` strictly follows the [eip #4626](https://eips.ethereum.org/EIPS/eip-4626) standard.
In addition to that there are some extensions to:

1. allow distributing "Aave Protocol Liquidity Mining Rewards" to addresses holding the static token
2. ux additions for [meta transactions](https://eips.ethereum.org/EIPS/eip-712)
3. ux additions utilizing the underlying aave protocol pools

### Additional methods

Please have a look at the [interface](./src/interfaces/IStaticATokenLM.sol) for a precise documentation of all methods and parameters. The documentation here will only give a quick summary of additional available methods and the reasoning for their existence.

#### Methods for interacting with LM

```
// read methods

// claimable rewards by the static token
getTotalClaimableRewards();
// the claimable by a single depositor on the static token
getClaimableRewards(address user);
// the unclaimed by a single depositor (only relevant when the incentives are temporary depleted)
getUnclaimedRewards(address user);
// current reward index used for calculating the accrued rewards since the user deposited into the static token
getCurrentRewardsIndex();
// the incentives controller on the aToken
incentivesController();
// the reward token tracked and which you can claim on the static token
rewardToken();

// write methods

// claim your own rewards
claimRewardsToSelf();
// claim your own rewards to a different address
claimRewards(address receiver);
// claim rewards on behalf of someone else
claimRewardsOnBehalf(address onBehalfOf, address receiver);
// pulls rewards to the static token to be distributed to respective static token holders
collectAndUpdateRewards();
```

#### Meta transactions

The meta transactions expose a separate api which allow pre-signing and relaying transactions.

`metaDeposit` requires an additional permit for the token you want to deposit. You can see a the full flow in the [tests](./test/StaticATokenMetaTransactions.sol).

```
metaDeposit(
    address depositor,
    address recipient,
    uint256 value,
    uint16 referralCode,
    bool fromUnderlying,
    uint256 deadline,
    PermitParams calldata permit,
    SignatureParams calldata sigParams
);
metaWithdraw(
    address owner,
    address recipient,
    uint256 staticAmount,
    uint256 dynamicAmount,
    bool toUnderlying,
    uint256 deadline,
    SignatureParams calldata sigParams
);
```

#### Ux additions

The ux additions consist of getters for underlying addresses of the aave protocol. In addition there are overloaded redeem/deposit methods more in line with the aave protocol interfaces and thus allow depositing from underlying and redeeming the underlying in a single transaction.

```
// read methods

// the current exchange rate from static tokes to a tokens
rate();
// the underlying pool of the aToken used as base in the static token
pool();
// the a Token used inside the static a token (e.g. aDAI)
aToken();
// the underlying of the aToken used in the static token (e.g. DAI)
aTokenUnderlying();

// write methods

// allows redeeming shares for the aToken or the underlying handling the unwrapping internally
redeem(uint256 shares, address recipient, address owner, bool toUnderlying);
// allows depositing assets from the aToken or the underlying handling the wrapping internally
deposit(uint256 assets, address recipient, uint16 referralCode, bool fromUnderlying);
```
