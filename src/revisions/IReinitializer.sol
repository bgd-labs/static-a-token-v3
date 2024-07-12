// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IReinitializer
 * @notice Interface with the method definition to initialize the contract StaticATokenLM for revision 3
 * @author BGD labs
 */
contract IReinitializer {
  /**
   * @notice method called to initialize a new revision of the contract
   */
  function initializeRevision() external;
}
