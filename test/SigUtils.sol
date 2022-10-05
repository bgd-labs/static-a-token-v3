// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library SigUtils {
  struct Permit {
    address owner;
    address spender;
    uint256 staticAmount;
    uint256 dynamicAmount;
    bool toUnderlying;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of a permit
  function getStructHash(Permit memory _permit, bytes32 typehash)
    internal
    pure
    returns (bytes32)
  {
    return
      keccak256(
        abi.encode(
          typehash,
          _permit.owner,
          _permit.spender,
          _permit.staticAmount,
          _permit.dynamicAmount,
          _permit.toUnderlying,
          _permit.nonce,
          _permit.deadline
        )
      );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(
    Permit memory _permit,
    bytes32 typehash,
    bytes32 domainSeperator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeperator,
          getStructHash(_permit, typehash)
        )
      );
  }
}
