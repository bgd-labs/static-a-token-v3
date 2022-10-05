// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library SigUtils {
  struct WithdrawPermit {
    address owner;
    address spender;
    uint256 staticAmount;
    uint256 dynamicAmount;
    bool toUnderlying;
    uint256 nonce;
    uint256 deadline;
  }

  struct DepositPermit {
    address owner;
    address spender;
    uint256 value;
    uint16 referralCode;
    bool fromUnderlying;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of a permit
  function getWithdrawHash(WithdrawPermit memory permit, bytes32 typehash)
    internal
    pure
    returns (bytes32)
  {
    return
      keccak256(
        abi.encode(
          typehash,
          permit.owner,
          permit.spender,
          permit.staticAmount,
          permit.dynamicAmount,
          permit.toUnderlying,
          permit.nonce,
          permit.deadline
        )
      );
  }

  function getDepositHash(DepositPermit memory permit, bytes32 typehash)
    internal
    pure
    returns (bytes32)
  {
    return
      keccak256(
        abi.encode(
          typehash,
          permit.owner,
          permit.spender,
          permit.value,
          permit.referralCode,
          permit.fromUnderlying,
          permit.nonce,
          permit.deadline
        )
      );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedWithdrawHash(
    WithdrawPermit memory permit,
    bytes32 typehash,
    bytes32 domainSeperator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeperator,
          getWithdrawHash(permit, typehash)
        )
      );
  }

  function getTypedDepositHash(
    DepositPermit memory permit,
    bytes32 typehash,
    bytes32 domainSeperator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeperator,
          getDepositHash(permit, typehash)
        )
      );
  }
}
