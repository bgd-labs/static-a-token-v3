# Static aToken with liquidity mining

## About

This repository contains a [eip #4263](https://eips.ethereum.org/EIPS/eip-4626) compatible token vault implementation for Aave aTokens.
The static token vault tokens are designed to increase in value instead of balance, which simplifies integration in certain applications.

## Limitations

The static aToken will keep track of LM rewards per user only for the incentives controller present on token initialization.
In token is using transparent proxy pattern, so the token is potentially upgradable to keep track of a new incentives controller.